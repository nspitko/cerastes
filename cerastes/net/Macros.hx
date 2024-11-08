package cerastes.net;

import haxe.macro.Compiler;
import haxe.macro.Type.TConstant;
import haxe.macro.Type.ClassField;
import hscript.Async.AsyncInterp;
import haxe.macro.TypeTools;
import haxe.macro.Printer;
import haxe.macro.Type.ModuleType;
import haxe.ds.Map;
import haxe.Int32;
import haxe.Exception;
import haxe.macro.Context;
import haxe.macro.Expr;
#if macro
using haxe.macro.Tools;
#end

class ProxyGenerator
{
	#if macro
	macro public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();
		var append: Array<Field> = [];
		var idx = 0;

		var rpcIdx = 0;

		var packers: Array<Expr> = [];
		var unpackers: Array<Expr> = [];
		var resetExprs = [];
		var dirtyExprs = [];

		var isRootClass = Context.getLocalClass().get().superClass == null;

		if( Context.getLocalClass().get().isInterface )
			return fields;

		append = handleRPC( fields );

		var p = new Printer();

		var parent = Context.getLocalClass().get().superClass;

		if( parent != null && parent.t.get().meta.has(":replCount") )
		{
			var m = parent.t.get().meta.extract(":replCount");
			switch m[0].params[0].expr
			{
				case EConst(CInt(n)): idx = Std.parseInt( n );
				default:
					throw new Exception("replCount incorrectly specificed (Don't manually set)");
			}
		}

		var startingFields = idx;


		var i = fields.length;
		while (i > 0)
		{
			var field = fields[--i];

			// Only modify replicated fields.
			var found = false;
			for( m in field.meta )
			{
				if( m.name == ":replicated" )
					found = true;
			}
			if( !found )
				continue;

			// Create a client side var

			#if client
			append.push({
				name: '_${field.name}',
				access: field.access,
				kind: field.kind,
				pos: field.pos,
				meta: field.meta,
			});
			#end

			var dirtyVar = '_repl_dirty${Math.floor( idx / 8 )}';

			var dirtyIdx = idx % 8;
			if( dirtyIdx == 0 )
			{
				append.push({
					name: dirtyVar,
					access: [Access.APublic],
					kind: FieldType.FVar(macro: hl.UI8),
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});

			}

			switch (field.kind)
			{
				case FVar(t, expr) | FProp(_, _, t, expr):
					var isProp = field.kind.getName() == "FProp";

					if( isProp )
					{
						var target = "set_" + field.name;

						// It's already a prop, so hijack its setter
						var oldSetter = null;
						for( f in fields )
						{
							if( f.name == target )
							{
								fields.remove(f);
								oldSetter = f;
							}
						}

						// Replace it with a wrapped one (non-overriding)
						var oldFunc = null;
						var setter : Function;
						if( oldSetter != null )
						{

							switch oldSetter.kind {
								case FFun(func): oldFunc = func;
								default:
									throw "Unsupported";
							}
							setter = {
								expr: macro {
									$i{dirtyVar} |= 1 << $v{dirtyIdx};
									${oldFunc.expr};
								},
								ret: t, // ret = return type
								args: oldFunc.args
							}
						}
						else
						{
							// No existing setter, make one
						setter = {
							expr: macro {
								$i{dirtyVar} |= 1 << $v{dirtyIdx};
								return $i{field.name} = v;
							},
							ret: t, // ret = return type
							args: [{ name:'v', type: t }]
						}
						}

						append.push({
							name: target,
							access: oldSetter != null ? oldSetter.access : [Access.APrivate],
							kind: FieldType.FFun(setter),
							pos: Context.currentPos(),
						});

						//trace("replaced setter for ",field.name," with type ",t);
					}
					else
					{
						// We need to remove the field and replace it with a prop, because props are like WAY cooler.
						fields.remove(field);

						append.push({
							name: field.name,
							access: field.access,
							kind: FieldType.FProp("default","set",t, expr),
							pos: field.pos,
							meta: field.meta
						});

						// Setter always flags the dirty bit for that field.
						var setter:Function = {
							expr: macro {
								$i{dirtyVar} |= 1 << $v{dirtyIdx};
								return $i{field.name} = value;
							},
							ret: t, // ret = return type
							args:[{ name:'value', type:t }]
						}

						append.push({
							name: "set_" + field.name,
							access: [Access.APrivate],
							kind: FieldType.FFun(setter),
							pos: field.pos,
						});

					}


					var packExprs = createPacker(field.name,t );
					packers.push( macro {
						if( full || $i{dirtyVar} & ( 1 << $v{idx} ) != 0 )
						{
							$b{packExprs}
						}
					});

					var unpackExprs = createUnpacker(field.name,t);
					unpackers.push( macro {
						if( full || ( $i{dirtyVar} & ( 1 << $v{idx} ) ) != 0 )
						{
							//trace("unpacking " + $v{name} + " from pos " + pos );
							$b{unpackExprs}
						}
					});

					// "Packable" here means we implement the Replicated interface and can thus pack
					// the clas using those interfaces.
					if( isPackableClass(t) )
					{
						resetExprs.push(macro $i{field.name}._repl_reset() );
						// Rather than just checking for dirtyness here, we'll forward the var's dirty state
						// to the owner's dirty flag, which unifies a bunch of downstream logic with minimal
						// additional overhead.
						dirtyExprs.push(macro {
							if( $i{field.name}._repl_isDirty() )
								$i{dirtyVar} |= 1 << $v{dirtyIdx};
						});
					}

					idx++;


				default:
					throw new Exception("Unsupported " + field.kind);
			}
		}

		// Nothing to do.
		//if( idx == 0)
		//	return fields.concat( append );

		// Write repl id
		// All replicated classes must have replication IDs, which are mapped
		// into a generated switch which handles client replication instantiation
		var clsid: Int = -1;
		if( Context.getLocalClass().get().meta.has("clsid") )
		{
			var replExpr = Context.getLocalClass().get().meta.extract("clsid");

			switch replExpr[0].params[0].expr
			{
				case EConst(CInt(n)): clsid = Std.parseInt( n );
				default: throw new Exception("Invalid replication ID (Should be int)");
			}
		}

		// Create state tracking vars
		var fieldType = macro: hl.UI8;

		var setExprs = [];
		var readExprs = [];
		var n = 0;
		for( i in 0... Math.ceil(idx / 8) )
		{
			n++;
			setExprs.push(macro { buffer.set(pos++, $i{"_repl_dirty"+i} ); });
			readExprs.push(macro { $i{"_repl_dirty"+i} = buffer.get(pos); pos++; });
			resetExprs.push(macro { $i{"_repl_dirty"+i} = 0; });
			dirtyExprs.push(macro { if( $i{"_repl_dirty"+i} != 0 ) return true; });
		}

		// Add builders if needed
		// @todo: This needs to be smarter.
		if( isRootClass || startingFields < idx || clsid != -1 )
		{
			var access = [ Access.APublic ];
			if( !isRootClass )
				access.push( Access.AOverride );

			if( isRootClass )
			{
				// Add netid
				append.push({
					name: "_repl_netid",
					access: [Access.APublic],
					kind: FieldType.FVar(macro: hl.UI16, macro -1),
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});
			}


			// Add dirty function

			var dirtyBuilder:Function = {
				expr: macro {

					$b{dirtyExprs}

					return false;

				},
				ret: macro: Bool,
				args:[]
			}

			//trace(p.printExpr( builder.expr ));

			append.push({
				name: "_repl_isDirty",
				access: access,
				kind: FieldType.FFun(dirtyBuilder),
				pos: Context.currentPos(),
				meta: [{ name:":noCompletion", pos: Context.currentPos() }]
			});

			// Add clsid getter
			if( clsid != -1 || isRootClass )
			{
				var clsidBuilder:Function = {
					expr: macro {
						return $v{clsid};
					},
					ret: macro: Int,
					args:[]
				}

				//trace(p.printExpr( builder.expr ));

				append.push({
					name: "_repl_clsid",
					access: access,
					kind: FieldType.FFun(clsidBuilder),
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }]
				});
			}

			var builder:Function = {
				expr: macro {

					var startPos = pos;

					#if debug
					if( _repl_clsid() == -1 ) throw $v{Context.getLocalClass().toString()} + " must have a valid clsid!!";

					#end

					// If not doing a full update, set dirty flags
					if( !full )
					{
						$b{setExprs};
					}


					pos = _repl_serializeFields(buffer, pos, full );
					return pos;

				},
				ret: macro: Int,
				args:[
					{ name:'buffer', type:macro: haxe.io.Bytes },
					{ name:'pos', type:macro: Int },
					{ name:'full', type:macro: Bool, opt: true },
			]}

			//trace(p.printExpr( builder.expr ));

			append.push({
				name: "_repl_serialize",
				access: access,
				kind: FieldType.FFun(builder),
				pos: Context.currentPos(),
				meta: [{ name:":noCompletion", pos: Context.currentPos() }],
			});

			var ret = isRootClass ? macro pos : macro super._repl_serializeFields(buffer, pos, full);

			var builderField:Function = {
				expr: macro {

					$b{packers}

					return ${ret};

				},
				ret: macro: Int,
				args:[
					{ name:'buffer', type:macro: haxe.io.Bytes },
					{ name:'pos', type:macro: Int },
					{ name:'full', type:macro: Bool, opt: true }
			]}

			//trace( Context.getLocalClass().toString() );
			//trace( p.printExpr( builderField.expr ));

			append.push({
				name: "_repl_serializeFields",
				access: access,
				kind: FieldType.FFun(builderField),
				pos: Context.currentPos(),
				meta: [{ name:":noCompletion", pos: Context.currentPos() }],
			});

			var decoder:Function = {
				expr: macro {

					if( !full )
					{
						$b{readExprs}
					}

					pos = _repl_unserializeFields(buffer, pos, full);

					//trace("Final unpacked pos is " + pos);
					return pos;
				},
				ret: macro: Int,
				args:[
					{ name:'buffer', type:macro: haxe.io.Bytes },
					{ name:'pos', type:macro: Int },
					{ name:'full', type:macro: Bool, opt: true },
			]}

			append.push({
				name: "_repl_unserialize",
				access: access,
				kind: FieldType.FFun(decoder),
				pos: Context.currentPos(),
				meta: [{ name:":noCompletion", pos: Context.currentPos() }],
			});

			ret = isRootClass ? macro pos : macro super._repl_unserializeFields(buffer, pos, full);

			var decoderFields:Function = {
				expr: macro {

					$b{unpackers}

					return ${ret};
				},
				ret: macro: Int,
				args:[
					{ name:'buffer', type:macro: haxe.io.Bytes },
					{ name:'pos', type:macro: Int },
					{ name:'full', type:macro: Bool, opt: true },
			]}

			append.push({
				name: "_repl_unserializeFields",
				access: access,
				kind: FieldType.FFun(decoderFields),
				pos: Context.currentPos(),
				meta: [{ name:":noCompletion", pos: Context.currentPos() }],
			});

			var resetFunc:Function = {
				expr: macro {

					$b{resetExprs}

				},
				ret: macro: Void,
				args:[]}

			//trace( Context.getLocalClass().toString() );
			//trace( p.printExpr( builderField.expr ));

			append.push({
				name: "_repl_reset",
				access: access,
				kind: FieldType.FFun(resetFunc),
				pos: Context.currentPos(),
				meta: [{ name:":noCompletion", pos: Context.currentPos() }],
			});
		}



		// Store off how many methods the class has; so child classes can add methods without stomping
		if( Context.getLocalClass().get().meta.has(":replCount") )
			throw("Do not manually specify replCount.");

		Context.getLocalClass().get().meta.add(":replCount", [ macro $v{idx}], Context.currentPos() );

		return fields.concat(append);
	}

	static function handleRPC( fields: Array<Field> ) : Array<Field>
	{
		var i = fields.length;
		var idx = 0;
		var append : Array<Field> = [];

		var p = new Printer();


		var caseMap = new Map<Int, Expr>();
		var fieldMap = new Map<Int, Field>();

		// Our parent class may already have RPC methods; if so start
		// count from there.
		if( Context.getLocalClass().get().meta.has(":rpcCount") )
		{
			var m = Context.getLocalClass().get().meta.extract(":rpcCount");
			switch m[0].params[0].expr
			{
				case EConst(CInt(n)): idx = Std.parseInt( n );
				default:
					throw new Exception("rpcCount incorrectly specificed (Don't manually set)");
			}
		}


		while (i > 0)
		{
			var field = fields[--i];
			var type = "none";

			for( m in field.meta )
			{

				if( m.name == ":rpc" )
				{
					switch m.params[0].expr
					{
						case EConst(CIdent(n)): type = n;
						default:
							throw new Exception("Invalid RPC argument (Should be string)");
					}
				}
			}

			if( type == "none" )
				continue;

			if( idx > 255 )
				throw "Too many RPC calls";

			// Setup args
			var func;

			switch field.kind {
				case FFun(f): func = f;
				default:
					throw "RPC meta can only be applied to functions";
			}

			var nArgs = func.args.length;

			var argSetters: Array<Expr> = [];
			var argSerializers: Array<Expr> = [];
			var argUnserializers: Array<Expr> = [];
			var argRPCArgs: Array<Expr> = [];
			var n = 0;
			while(n < func.args.length )
			{
				var arg = func.args[n];
				argSetters.push(macro args[$v{n}] = $i{arg.name} );
				var argName = arg.name;

				switch arg.type
				{
					case TPath(type):
					switch( type.name )
					{
						case "Int":
							argSerializers.push(macro { buffer.setInt32( pos, rpc.args[$v{n}]); pos+=4; } );
							argUnserializers.push(macro @:mergeBlock { var $argName = buffer.getInt32(pos); pos+=4; } ); // var $i{arg.name} = buffer.getInt32(pos); pos+=4;
							argRPCArgs.push( macro $i{arg.name} );
						default:
							throw "Unhandled type " + type;
					}
					default:
						throw "Unhandled type " + type;
				}
				n++;
			}


			// Path for redirecting calls to the other side.
			#if client
			if( type == "server" )
			#elseif server
			if( type == "client" )
			#end
			{
				fields.remove(field);

				// Replace original function with a simple RPC queue func
				var queueFunc:Function = {
					expr: macro {

						var args = new haxe.ds.Vector( $v{nArgs} );
						$b{argSetters};

						var rpc: cerastes.net.Types.RPCCall = {
							methodId: $v{idx},
							target: this,
							args: args,
							callback:$i{"_rpcUnserialize_"+field.name}.bind(callback),
							serialize:$i{"_rpcSerialize_"+field.name}
						};

						cerastes.net.RPC.registerRPC( rpc );

					},
					ret: macro: Void,
					args: func.args.concat([{ // Add a callback param to the end
						type: TFunction([#if server macro: server.ClientBehavior, #end func.ret], macro: Void ),
						opt: true,
						name: "callback"
					}])
				}

				//trace( p.printExpr( queueFunc.expr ));
				append.push({
					name: field.name,
					access: field.access,
					kind: FieldType.FFun(queueFunc),
					pos: Context.currentPos(),
				});

				// Add a serialization function
				var serializeFunc:Function = {
					expr: macro {
						buffer.set(pos++, rpc.callId );
						buffer.set(pos++, rpc.methodId );
						buffer.setUInt16(pos, rpc.target._repl_netid ); pos+=2;


						$b{argSerializers};

						return pos;

					},
					ret: macro: Int,
					args: [
						{ name:'buffer', type:macro: haxe.io.Bytes },
						{ name:'pos', type:macro: Int },
						{ name:'rpc', type:macro: cerastes.net.Types.RPCCall },
					]
				}

				//trace( p.printExpr( serializeFunc.expr ));

				append.push({
					name: "_rpcSerialize_"+field.name,
					access: [Access.APublic],
					kind: FieldType.FFun(serializeFunc),
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});

				// ...and the response handler
				var responseDeserializer = macro {};
				switch func.ret
				{
					case TPath(t):
						switch( t.name )
						{
							case "Int":
								responseDeserializer = macro { ret = buffer.getInt32(pos); pos+=4; };
							case "Float":
								responseDeserializer = macro { ret = buffer.getFloat(pos); pos+=4; };
							default:
								throw "Unhandled type " + t.name;
						}
					default:
						throw "Unhandled type " + func.ret;
				}

				var unserializeFunc:Function = {
					expr: macro {

						var ret;

						${responseDeserializer}

						if( callback != null )
							#if server
							callback(client, ret );
							#else
							callback( ret );
							#end

						return pos;

					},
					ret: macro: Int,
					args: [
						{ name:'callback', type: TFunction([
								#if server macro: server.ClientBehavior, #end
								func.ret],
							 macro: Void ) }, // Always gets bound
						#if server
						{ name:'client', type: macro: server.ClientBehavior }, // Always gets bound
						#end
						{ name:'buffer', type:macro: haxe.io.Bytes },
						{ name:'pos', type:macro: Int },
					]
				}

				//trace( p.printExpr( unserializeFunc.expr ));

				append.push({
					name: "_rpcUnserialize_"+field.name,
					access: [Access.APublic],
					kind: FieldType.FFun(unserializeFunc),
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});

			} // END RPC Send path

			#if server
			if( type == "server" )
			#elseif client
			if( type == "client")
			#end
			{

				// Add cases
				if( caseMap.exists(idx) )
					throw new Exception('Duplicate rpc method ID ${idx}');

				#if server
				// Add client as an optional final param
				argRPCArgs.push(macro $i{"client"});
				func.args.push({ name:'client', type: macro: server.ClientBehavior, opt: true });
				#end

				caseMap.set(idx,macro {
					@:mergeBlock
					$b{argUnserializers}
					#if server
					retVal = $i{field.name}( $a{argRPCArgs} );
					cerastes.net.RPC.registerRPCResponse(client, {
						callId: callId,
						response: retVal,
						serializer: $i{"_rpcSerializeResponse_"+field.name}.bind(retVal)
					});
					#else
					retVal = $i{field.name}( $a{argRPCArgs} );
					cerastes.net.RPC.registerRPCResponse({
						callId: callId,
						response: retVal,
						serializer: $i{"_rpcSerializeResponse_"+field.name}.bind(retVal)
					});
					#end

				} );



				fieldMap.set(idx, field );

				// Build response serializer
				var responseRealizer: Expr = null;

				switch func.ret
				{
					case TPath(t):
						switch( t.name )
						{
							case "Int":
								responseRealizer = macro { buffer.setInt32(pos, val); pos+=4; };
							case "Float":
								responseRealizer = macro { buffer.setFloat(pos, val); pos+=4; };
							default:
								throw "Unhandled type " + t.name;
						}
					default:
						throw "Unhandled type " + func.ret;
				}

				var serializeResponseFunc:Function = {
					expr: macro {

						${responseRealizer}

						return pos;

					},
					ret: macro: Int,
					args: [
						{ name:'val', type: func.ret }, // Always gets bound
						{ name:'buffer', type:macro: haxe.io.Bytes },
						{ name:'pos', type:macro: Int },
					]
				}

				//trace( p.printExpr( unserializeFunc.expr ));

				append.push({
					name: "_rpcSerializeResponse_"+field.name,
					access: [Access.APublic],
					kind: FieldType.FFun(serializeResponseFunc),
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});


				//trace( p.printExpr( caseMap[idx] ));

			}

			idx++;
		} // END per field loop


		// Routing function for incoming RPC calls
		var types = new Array<haxe.macro.Expr.TypeDefinition>();
		var pos = Context.currentPos();
		var hasParent = Context.getLocalClass().get().superClass != null;

		var ret = macro pos;
		if( hasParent )
		{
			#if server
			ret = macro super._rpc_handleRequest( client, buffer, pos, methodId, callId );
			#else
			ret = macro super._rpc_handleRequest( buffer, pos, methodId, callId );
			#end
		}

		var caseExprs: Array<Case> = [];
		for( id => c in caseMap )
		{
			var val = macro $v{id};
			caseExprs.push({
				values: [ val ],
				expr: c
			});
		}

		var switchExpr = {
			expr: ESwitch(
				{
					expr: EParenthesis( macro $i{"methodId"} ),
					pos: pos
				},
				caseExprs, // cases
				null // edef
			),
			pos: pos
		};


		var switchFunc:Function = {
			expr: macro {

				var retVal: Dynamic = null;
				//trace("Attempting to handle request for id " + methodId);

				${switchExpr};


				return ${ret};

			},
			ret: macro: Int,
			args: [
				#if server
				{ name:'client', type:macro: server.ClientBehavior },
				#end
				{ name:'buffer', type:macro: haxe.io.Bytes },
				{ name:'pos', type:macro: Int },
				{ name:'methodId', type:macro: Int },
				{ name:'callId', type:macro: Int },
			]
		};

		//trace( p.printExpr( switchFunc.expr ) );

		var access = [ Access.APublic ];
		if( hasParent  )
			access.push( Access.AOverride );

		append.push({
			name: "_rpc_handleRequest",
			access: access,
			kind: FieldType.FFun(switchFunc),
			pos: Context.currentPos(),
			meta: [{ name:":noCompletion", pos: Context.currentPos() }],
		});


		// Store off how many methods the class has; so child classes can add methods without stomping
		if( Context.getLocalClass().get().meta.has(":rpcCount") )
			Context.getLocalClass().get().meta.remove(":rpcCount");

		Context.getLocalClass().get().meta.add(":rpcCount", [ macro $v{idx}], Context.currentPos() );



		return append;
	}

	public static function createPacker(name: String, t: ComplexType, subscript = false) : Array<Expr>
	{
		var ret;
		var pack = [];
		switch (t )
		{
			case TPath(type):

				switch( type.name )
				{
					case "Int":
						pack.push( macro {
							buffer.setInt32(pos, ${subscript ? macro $i{name}[e] : macro $i{name}});
							pos += 4;
						});

					case "Float":
						pack.push( macro {
							buffer.setFloat(pos, $i{name});
							pos += 4;
						});
					case "String":
						pack.push( macro {
							var bytes = haxe.io.Bytes.ofString($i{name});
							buffer.setUInt16(pos, bytes.length );
							pos += 4;
							buffer.blit( pos, bytes, 0, bytes.length );
							pos += bytes.length;
						});

					case "Vector":
						// Extract the inner type
						var innerPackers;
						switch( type.params[0] )
						{
							case TPType(ct):
								innerPackers = createPacker(name, ct, true );
							default:
								throw "unexpected " + type.params[0];
						}

						pack.push( macro {
							buffer.setUInt16(pos, $i{name}.length );
							for( e in 0 ... $i{name}.length )
							{
								$b{innerPackers}
							}
							pos += 4;
						});


					case other:
						// Check if we can just pack this class
						if( isPackableClass( t ) )
						{
							pack.push( macro {
								trace("sub pack at pos " + pos);
								pos = $i{name}._repl_serialize(buffer, pos, full );
							});
						}
						else
						{

							var t = Context.getType( getTypePathName( type ) ).follow();
							switch (t)
							{
								case TAnonymous(ref):
									throw "Can't pack typedefs, use @:structInit instead";
									/*
									var anon = ref.get();
									for (field in anon.fields)
									{
										var p = field.type.toString().split(".");
										var typeName = p.pop();
										var t:ComplexType = TPath({
											name: typeName,
											pack: p
										});

										pack = pack.concat( createUnpacker( '${name}.${field.name}', t, idx, dirtyVar ) );
									}*/

								case TAbstract(t, params):
									var at = t.get().type.follow();
									var p = at.toString().split(".");
									var typeName = p.pop();
									var cat:ComplexType = TPath({
										name: typeName,
										pack: p
									});
									pack = pack.concat( createPacker(name, cat ) );
								case _:
									trace(t);
									throw "Unhandled";
							}
						}
				}

			case other:
				throw "Unsupported " + other;
		}



		return pack;
	}

	public static function createUnpacker(name: String, t: ComplexType, subscript = false) : Array<Expr>
	{
		var ret;
		var pack: Array<Expr> = [];
		switch (t )
		{
			case TPath(type):
				switch( type.name )
				{
					case "Int":
						pack.push( macro {
							${subscript ? macro $i{name}[e] : macro $i{name}} = buffer.getInt32(pos);
							pos += 4;
						});

					case "Float":
						pack.push( macro {
							$i{name} = buffer.getFloat(pos);
							pos += 4;
						});
					case "String":
						pack.push( macro {
							var len = buffer.getUInt16( pos );
							pos += 4;
							var bytes = buffer.sub(pos, len );
							$i{name} = bytes.toString();
							pos += len;
						});

					case "Vector":
						throw "WIP";
						// Extract the inner type
						var innerPackers;
						switch( type.params[0] )
						{
							case TPType(ct):
								innerPackers = createUnpacker(name , ct, true);
							default:
								throw "unexpected " + type.params[0];
						}

						pack.push( macro {
							var len = buffer.getUInt16(pos );
							$i{name} = new haxe.ds.Vector4( len );
							for( e in 0 ... $i{name}.length )
							{
								$b{innerPackers}
							}
							pos += 4;
						});

					case other:
						// Check if we can just pack this class
						if( isPackableClass( t ) )
						{
							pack.push( macro {
								trace("sub unpack at pos " + pos);
								pos = $i{name}._repl_unserialize(buffer, pos, full );
							});
						}
						else
						{

							var t = Context.getType( getTypePathName( type ) ).follow();
							switch (t)
							{
								case TAnonymous(ref):
									throw "Can't pack typedefs, use @:structInit instead";

								case TAbstract(t, params):
									var at = t.get().type.follow();
									var p = at.toString().split(".");
									var typeName = p.pop();
									var cat:ComplexType = TPath({
										name: typeName,
										pack: p
									});
									pack = pack.concat( createUnpacker(name, cat ) );
								case _:
									trace(t);
									throw "Unhandled";
							}
						}
				}

			case other:
				throw "Unsupported " + other;
		}

		return pack;
	}

	static function isPackableClass( t: ComplexType )
	{
		switch (t )
		{
			case TPath(type):

				var ft = Context.getType( getTypePathName(type) ).follow();
				switch(ft)
				{
					case TInst(ct,args):
						var handled = false;
						for( i in ct.get().interfaces )
						{
							if( i.t.get().name == "Replicated" )
								return true;
						}
					default: return false;
				}
			default: return false;
		}

		return false;
	}


	static function formatName(name:String)
	{
		return name.charAt(0).toUpperCase() + name.substr(1);
	}

	static function getTypePathName(type: TypePath )
	{
		var p = type.pack.join(".");
		if( p != "" ) p += '.';

		return p + type.name;
	}
	#end
}



class ReplicatorBuilder
{
	#if macro
	public static function build()
	{
		#if client
		Context.onAfterTyping(function (moduleTypes)
		{
			Compiler.exclude("Replicator");
			var replicatedClasses = [];

			var caseMap = new Map<Int, Expr>();

			for( moduleType in moduleTypes )
			{

				switch( moduleType )
				{
					case ModuleType.TClassDecl( clType ) :
					{

						var classType : haxe.macro.Type.ClassType = clType.get();
						if( classType.isInterface )
							continue;

						// All replicated classes must have replication IDs, which are mapped
						// into a generated switch which handles client replication instantiation
						if( classType.meta.has("clsid") )
						{
							replicatedClasses.push(classType);
							var replExpr = classType.meta.extract("clsid");
							var clsid: Int = -1;

							switch replExpr[0].params[0].expr
							{
								case EConst(CInt(n)): clsid = Std.parseInt( n );
								default: throw new Exception("Invalid replication ID (Should be int)");
							}

							if( caseMap.exists(clsid) )
								throw new Exception('Duplicate replication ID ${clsid}');

							// Build a new case for this replicated class
							var path = classType.module.split(".");
							var cls = path.pop();
							var typePath : TypePath = {
								pack: path,
								name: cls
							};
							caseMap.set(clsid,macro { c = new $typePath(); } );

							//trace('Replicator: Adding ${clsid} -> ${path.join(".")}.$cls');

						}
					}
					default:
						// It's OK if a class lacks one as long as we never try to serialize this
						// else we waste a ton of IDs on intermediate classes as well as create
						// more intermediate steps during serialization
				}
			}

			// Saves work but mostly prevents us from re-creating the proxy below
			if( replicatedClasses.length == 0 )
				return;

			// Create as proxy class to replace Replicator, MUST BE SIGNATURE COMPATIBLE
			var types = new Array<haxe.macro.Expr.TypeDefinition>();
			var pos = Context.currentPos();

			var caseExprs: Array<Case> = [];
			for( id => c in caseMap )
			{
				var val = macro $v{id};
				caseExprs.push({
					values: [ val ],
					expr: c
				});
			}

			var switchExpr = {
				expr: ESwitch(
					{
						expr: EParenthesis( macro $i{"id"} ),
						pos: pos
					},
					caseExprs, // cases
					null // edef
				),
				pos: pos
			};

			var tdef: haxe.macro.Expr.TypeDefinition = {
				pos : pos,
				name : "ReplicatorProxy",
				pack : [],
				kind : TDClass(),
				fields : (macro class {
					@:keep
					public static function create( id: Int ) : cerastes.net.Replicated {
						var c: cerastes.net.Replicated = null;

						${switchExpr};

						return c;
					}

				}).fields//.concat(globalFields),
			};

			var p = new Printer();
			//trace( p.printTypeDefinition(tdef) );

			Context.defineType(tdef);

		});
		#end
	}
	#end

}