package cerastes.macros;

import haxe.macro.Type.ClassType;
import haxe.macro.Context;
import haxe.macro.Expr;
#if macro
using haxe.macro.Tools;
#end

class TileEntityBuilder
{
	#if macro
	macro public static function build( defClass: ExprOf<Class<T>> ):Array<Field>
	{
		var fields = Context.getBuildFields();
		if( fields == null )
			fields = [];

		var clsType = getClassTypeFromExpr( defClass );
		var ftype = TPath( { pack: clsType.pack, name: clsType.name } );


		fields.push({
			name: "def",
			access: [APrivate],
			kind: FieldType.FVar( ftype, macro null),
			pos: Context.currentPos(),
			meta: [{ name:":keep", pos: Context.currentPos() }],
		});

		if( !hasField("new", fields) )
		{

			var constructor:Function = {
				expr: macro {
					this.def = def;
					super( parent );

				},
				//ret: t, // ret = return type
				args:[{ name:'def', type:ftype }, { name:'parent', type:macro:h2d.Object, opt: true }]
			};

			fields.push({
				name: "new",
				access: [APublic],
				kind: FieldType.FFun( constructor ),
				pos: Context.currentPos(),
				meta: [{ name:":keep", pos: Context.currentPos() }],
			});
		}

		if( !hasField("getDef", fields) )
		{
			var getDef:Function = {
				expr: macro {
					return {};
				},
				ret: ftype,
				args:[]
			};

			fields.push({
				name: "getDef",
				access: [APublic, AStatic],
				kind: FieldType.FFun( getDef ),
				pos: Context.currentPos(),
				meta: [{ name:":keep", pos: Context.currentPos() }],
			});
		}

		if( !hasField("getEditorIcon", fields) )
		{
			var getEditorIcon:Function = {
				expr: macro {
					return "\uf07c";
				},
				ret: macro: String,
				args:[]
			};

			fields.push({
				name: "getEditorIcon",
				access: [APublic, AStatic],
				kind: FieldType.FFun( getEditorIcon ),
				pos: Context.currentPos(),
				meta: [{ name:":keep", pos: Context.currentPos() }],
			});
		}

		if( !hasField("getInspector", fields) )
		{
			var getInspector:Function = {
				expr: macro {

				},
				//ret: macro String,
				args:[{ name:'def', type:ftype }]
			};

			fields.push({
				name: "getInspector",
				access: [APublic, AStatic],
				kind: FieldType.FFun( getInspector ),
				pos: Context.currentPos(),
				meta: [{ name:":keep", pos: Context.currentPos() }],
			});
		}

		return fields;

	}

	static function hasField( fname: String, fields: Array<Field> )
	{
		for( f in fields )
		{
			if( f.name == fname )
				return true;
		}

		return false;
	}

	static function addCallbackFields( field: Field, isStatic: Bool ) : Array<Field>
	{
		var append: Array<Field> = [];

		switch (field.kind)
		{
			case FFun( func ):
				// Add the listener field

				//trace('processing ${field.name}');
				var fieldNameUpper = field.name.substr(0,1).toUpperCase() + field.name.substr(1);

				var args = [for (arg in func.args) arg.type ] ;
				//args.push(TOptional(TPath({ pack: [], name: "Bool" }))); // Handled?
				args.push(TPath({ pack: [], name: "Bool" })); // Handled?
				var callbackType = TFunction(args, macro: Bool);
				var mapType: TypePath = {
					name: "Map",
					pack: ["haxe", "ds"],
					params: [
						TPType(
							TPath({
								pack: ["cerastes","macros"],
								name: "Callbacks",
								sub: "ClassKey"
							})
						),
						TPType( callbackType )

					]
				};

				var accessPrivate = isStatic ?  [Access.APrivate, Access.AStatic] :  [Access.APrivate];
				var accessPublic = isStatic ?  [Access.APublic, Access.AStatic] :  [Access.APublic];

				append.push({
					name: "_listeners_" + field.name,
					access: accessPrivate,
					kind: FieldType.FVar( TPath(mapType), macro []), // @todo specify this better
					pos: Context.currentPos(),
					meta: [{ name:":noCompletion", pos: Context.currentPos() }],
				});

				var fnAddListener: Function = {
					expr: macro {
						if( $i{"_listeners_" + field.name}.exists( owner ) )
							return false;

						$i{"_listeners_" + field.name}.set( owner, fn );
						return true;
					},
					args: [
						{ name:'owner', type: macro: cerastes.macros.Callbacks.ClassKey },
						{ name:'fn', type: callbackType }
					],
					ret: macro: Bool
				};

				append.push({
					name: 'register${fieldNameUpper}',
					access: accessPublic,
					kind: FieldType.FFun(fnAddListener),
					pos: Context.currentPos(),
				});

				var fnRemoveListener: Function = {
					expr: macro {
						return $i{"_listeners_" + field.name}.remove( owner );
					},
					args: [
						{ name:'owner', type: macro: cerastes.macros.Callbacks.ClassKey }
					],
					ret: macro: Bool
				};

				append.push({
					name: 'unregister${fieldNameUpper}',
					access: accessPublic,
					kind: FieldType.FFun(fnRemoveListener),
					pos: Context.currentPos(),
				});

				// Finally, fill out the function body

				var argNames = [for (arg in func.args) macro $i{arg.name}];
				argNames.push( macro $i{"handled"});


				func.expr = macro {
					var handled = false;
					for( l in $i{"_listeners_" + field.name})
					{
						handled = l($a{argNames}) || handled;
					}

					return handled;
				};


			default:
				throw "Only functions can be marked as callbacks!";
		}



		return append;
	}

	// https://github.com/jasononeil/compiletime/blob/master/src/CompileTime.hx
	static function getClassTypeFromExpr(e:Expr):ClassType
	{
		var ct:ClassType = null;
		var fullClassName = null;
		var parts = new Array<String>();
		var nextSection = e.expr;
		while (nextSection != null) {
			// Break the loop unless we explicitly encounter a next section...
			var s = nextSection;
			nextSection = null;

			switch (s) {
				// Might be a direct class name, no packages
				case EConst(c):
					switch (c) {
						case CIdent(s):
							if (s != "null") parts.unshift(s);
						default:
					}
				// Might be a fully qualified package name
				// { expr => EField({ expr => EField({ expr => EConst(CIdent(sys)), pos => #pos(src/server/Server.hx:35: characters 53-56) },db), pos => #pos(src/server/Server.hx:35: characters 53-59) },Object), pos => #pos(src/server/Server.hx:35: characters 53-66) }
				case EField(e, field):
					parts.unshift(field);
					nextSection = e.expr;
				default:
			}
		}
		fullClassName = parts.join(".");
		if (fullClassName != "") {
			switch (Context.follow(Context.getType(fullClassName))) {
				case TInst(classType, _):
					ct = classType.get();
				default:
					throw "Currently CompileTime.getAllClasses() can only search by package name or base class, not interface, typedef etc.";
			}
		}
		return ct;
	}

	#end
}