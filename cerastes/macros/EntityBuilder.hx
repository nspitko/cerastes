package cerastes.macros;

import haxe.display.Display.ClassFieldOrigin;
import haxe.macro.Printer;
import haxe.macro.Type.ClassType;
import haxe.macro.Context;
import haxe.macro.Expr;
#if macro
using haxe.macro.Tools;

@:structInit class EntityTypeInfo
{
	public var name: String;
	public var defName: String;
	public var dataTypeName: String;
	public var typePath: TypePath;
	public var builder: Expr;
}

#end



class EntityBuilder
{
	public static macro function getDefaultDataTypes():haxe.macro.Expr.ExprOf<Map<String, {clsName: String, defName: String }>> {
		var d: Map<String, {clsName: String, defName: String }> = [ ];
		for( e in classEntries )
		{
			d.set(e.dataTypeName, {clsName: e.name, defName: e.defName } );
		}

		return macro $v{d};
	}

	#if macro

	@:persistent static var classEntries: Array<EntityTypeInfo> = [];
	static var hasRun = false;

	macro public static function generate() : Array<Field>
	{
		Context.onAfterTyping(function(moduleTypes)
		{
			if( hasRun )
				return;

			hasRun = true;

			var caseMap = new Map<String, Expr>();
			var map: Array<Expr> = [];

			for( clsEntry in classEntries )
			{

				var clsTypePath = clsEntry.typePath;


				caseMap.set(clsEntry.name ,macro {
					c = new $clsTypePath( cast def );
				} );
			}


			//var classFields: Map<String,Array<haxe.macro.Expr.Field>> = [];
			var pos = Context.currentPos();



			// Switch cases -> exprs
			var caseExprs: Array<Case> = [];
			for( id => c in caseMap )
			{
				var val = macro $v{id};
				caseExprs.push({
					values: [ val ],
					expr: c
				});
			}

			// Switch exprs -> expr
			var switchExpr = {
				expr: ESwitch(
					{
						expr: EParenthesis( macro $i{"type"} ),
						pos: pos
					},
					caseExprs, // cases
					null // edef
				),
				pos: pos
			};

			var classFields: Array<haxe.macro.Expr.Field> = [];

			classFields.push((macro class {

					public static function create( def: cerastes.Entity.EntityDef ) : cerastes.Entity {
						var c: cerastes.Entity = null;
						if( !cerastes.Utils.verify( def != null, '${def} is not a valid entity data object' ) )
							return null;

						var type = def.type;

						${switchExpr};

						if( c != null )
							return c;

						// If no other handler, just make it a generic sprite
						//if( c == null )
						///	c = new Entity(cache, parent);

						cerastes.Utils.error('Unknown/invalid entity class requested: ${def.type}');


						return null;
					}

				}).fields[0]
			);

			classFields.push((macro class {

				public static function list( filter: Class<cerastes.Entity.EntityDef> ) : Array<String> {

					var out: Array<String> = [];
					for( defName => defObj in defMap )
					{
						if( Std.downcast( defObj, filter ) != null )
							out.push(defName);
					}


					return out;
				}

			}).fields[0]
		);


			// Include the other internal classes and types. We can only substitute the ENTIRE type, so yeah...

			classFields.push({
				name : "defMap",
				pos : pos,
				kind : FVar( macro: Map<String, cerastes.Entity.EntityDef>, macro [] ),
				access : [APublic, AStatic],
			});

			classFields.push({
				name : "loadedEntities",
				pos : pos,
				kind : FVar( macro: Int, macro 0 ),
				access : [AStatic],
			});


			classFields.push({
				name : "parsedFiles",
				pos : pos,
				kind : FVar( macro: Array<String>, macro [] ),
				access : [APublic, AStatic],
			});

			classFields.push({
				name:"init",
				pos: pos,
				kind: FFun({
					expr: macro {

						var base: Map<String,{clsName: String, defName: String }> = cerastes.macros.EntityBuilder.getDefaultDataTypes();

						for( k => v in base )
						{
							var def = Type.createInstance( Type.resolveClass(v.defName), [] );
							defMap.set( k, def );
							def.type = v.clsName;
							loadedEntities++;
						}

						for( f in files )
						{
							parseFile( f );
						}
						cerastes.Utils.info('Loaded ${loadedEntities} data entities');
					},
					ret: null,
					args: [{name: "files", type:macro: Array<String> }]
				}),
				access: [APublic, AStatic],
			});

			classFields.push({
				name:"parseFile",
				pos: pos,
				kind: FFun({
					expr: macro {
						if( !cerastes.Utils.verify( parsedFiles.indexOf( file ) == -1, 'Duplicate entity include: ${file} was already included!') )
							return;

						if( !cerastes.Utils.verify( hxd.Res.loader.exists( file ), 'Tried to load missing entity file ${file}' ) )
							return;

						var data: cerastes.Entity.EntityFile = cerastes.file.CDParser.parse( hxd.Res.loader.load(file).entry.getText(), cerastes.Entity.EntityFile );

						if( !cerastes.Utils.verify( data != null, 'Failed to parse entity file ${file}' ) )
							return;

						parsedFiles.push(file);

						if( data.includes != null )
							for( include in data.includes  )
								parseFile( include );

						if( data.entities != null )
						{
							for( k => v in data.entities )
							{
								if( defMap.exists( k ) )
									cerastes.Utils.warning('File $file overrides entity ${k}. This is generally not good practice as include order is now load bearing. Consider making a new entity instead.');

								defMap.set( k, v );
								loadedEntities++;
							}
						}
					},
					ret: null,
					args: [{name: "file", type:macro: String }]
				}),
				access: [AStatic],
			});

			//var p = new Printer();
			//trace( p.printField(classFields[0]) );


			var definition:TypeDefinition = {
				fields: classFields,
				kind: TDClass(),
				name: "EntityBuilderProxy",
				pack: [],
				pos: pos,
				meta: [{name:":keep", pos: pos}],
			};

			//var p = new Printer();
			//for( f in classFields )
			//	trace( p.printField( f ) );

			Context.defineType(definition);
		});
		return null;
	}

	macro public static function build( defClass: ExprOf<Class<T>>, dataTypeName: String ):Array<Field>
	{
		var fields = Context.getBuildFields();
		if( fields == null )
			fields = [];

		var clsType = getClassTypeFromExpr( defClass );
		var ftype = TPath( { pack: clsType.pack, name: clsType.name } );

		var classType = Context.getLocalClass().get();

		var clsTypePath : TypePath = {
			pack: classType.pack,
			name: classType.name
		};


		// :AyameDespair:
		var module = classType.module.split('.');
		if( module[module.length-1] != classType.name )
		{
			clsTypePath.sub = classType.name;
			clsTypePath.name = module[module.length-1];
		}

		classEntries.push({
			name: Context.getLocalClass().toString(),
			defName:  Context.resolveType(ftype, Context.currentPos()).toString(),
			typePath: clsTypePath,
			dataTypeName: dataTypeName,
			builder: macro {
				if( cls == $v{Context.getLocalClass().toString()} )
				{
					return new $clsTypePath( def );
				}
			}
		});

		var getDef:Function = {
			expr: macro {
				return cast def;
			},
			ret: ftype,
			args:[]
		};

		fields.push({
			name: "getDef",
			access: [APublic, AOverride],
			kind: FieldType.FFun( getDef ),
			pos: Context.currentPos(),
			meta: [{ name:":keep", pos: Context.currentPos() }],
		});




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