package cerastes.macros;

import haxe.macro.Printer;
import haxe.macro.ComplexTypeTools;
import haxe.macro.Type.ClassField;
import haxe.macro.TypeTools;
import haxe.macro.ExprTools;
import haxe.macro.Type.ModuleType;
import haxe.macro.Compiler;
import haxe.rtti.Meta;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Json;
#if macro
using haxe.macro.Tools;
#end

typedef SpriteDataExpr = {
	type: ComplexType,
	defaultValue: Expr,
	name: String,
	label: String,
	tooltip: String
}

typedef SpriteDataItem = {
	type: String,
	defaultValue: Dynamic,
	name: String,
	label: String,
	tooltip: String,
}

/**
 * Builds fields related to sprite runtime data defined in the sprite editor
 *
 * Mark relevant fields with @:data(defaultValue, field name to show in the editor, help tooltip)
 * tooltip is optional.
 */
class SpriteData
{
	#if macro

	static var built = false;
	static var once = false;

	macro public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();
		if( fields != null )
			fields = fields.concat( createSpriteDataClass(fields) );

		if( !once )
		{
			once = true;
			var pack = ["game","meta","sprites"];//Context.getLocalModule().split('.');
			var classFields: Array<haxe.macro.Expr.Field> = [];

			var definition:TypeDefinition = {
				fields: [],
				kind: TDClass(),
				name: "SpriteData",
				pack: pack,
				pos: Context.currentPos(),
				meta: [{name:":keep", pos: Context.currentPos()}, {name:":structInit", pos: Context.currentPos()}],
			};

			Context.defineType( definition );
		}

		Context.onAfterTyping(function(moduleTypes)
		{
			if( built ) return;

			var replicatedClasses = [];
			var dataMap: Map<String, Array<SpriteDataItem>> = [];
			var caseMap = new Map<String, Expr>();

			for( moduleType in moduleTypes )
			{
				switch( moduleType )
				{
					case ModuleType.TClassDecl( clType ) :
					{
						var classType : haxe.macro.Type.ClassType = clType.get();

						if( '${classType.pack.join(".")}.${classType.name}' == "cerastes.SpriteMeta" )
							classType.exclude();


						// All replicated classes must have replication IDs, which are mapped
						// into a generated switch which handles client replication instantiation
						if( classType.meta.has(":sd.tag") )
						{
							replicatedClasses.push(classType);
							var clsMeta: Array<SpriteDataItem> = [];

							var cls = classType;
							do
							{
								addDataFieldsForClass(cls.fields.get(), clsMeta );

								cls = cls.superClass != null ? cls.superClass.t.get() : null;
							}
							while( cls != null );

							var str = '${ classType.pack}.${classType.name}';
							// Build a new case for this replicated class


							var clsTypePath : TypePath = {
								pack: classType.pack,
								name: classType.name
							};
							var clsString = '${classType.pack.join(".")}.${classType.name}';
							// :AyameDespair:
							var module = classType.module.split('.');
							if( module[module.length-1] != classType.name )
							{
								clsTypePath.sub = classType.name;
								clsTypePath.name = module[module.length-1];
								clsString = '${classType.module}.${classType.name}';
							}

							var dataTypePath : TypePath = {
								pack: ["game","meta","sprites"],
								name: classType.name + "Data"
							}
							//var complex = TypeTools.toComplexType( classType.kind. );
							var dataTypeComplex = '${dataTypePath.pack.join('.')}.${dataTypePath.name}'.toComplex();
							caseMap.set(clsString ,macro {
								c = new $clsTypePath( cache, parent );
							} );


							dataMap.set(clsString, clsMeta );


						}
					}
					default:
						// It's OK if a class lacks one as long as we never try to serialize this
						// else we waste a ton of IDs on intermediate classes as well as create
						// more intermediate steps during serialization
				}
			}


			//var classFields: Map<String,Array<haxe.macro.Expr.Field>> = [];
			var pos = Context.currentPos();

			var map: Array<Expr> = [];

			for( className => fieldList in dataMap )
			{
				var items:Array<SpriteDataItem> = [for (value in fieldList) {
					type: value.type.toString(),
					defaultValue: $v{value.defaultValue},
					label: value.label,
					tooltip: value.tooltip,
					name: value.name
				}];

				map.push( macro $v{className} => $v{items} );


			}

			if( map.length == 0 )
				return;

			built = true;

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
						expr: EParenthesis( macro $i{"clsType"} ),
						pos: pos
					},
					caseExprs, // cases
					null // edef
				),
				pos: pos
			};

			var classFields: Array<haxe.macro.Expr.Field> = [];

			classFields.push((macro class {

					public static function create( cache: cerastes.Sprite.SpriteCache, ?parent: h2d.Object ) : Sprite {
						var c: Sprite = null;
						var clsType = cache.spriteDef.type;

						${switchExpr};

						// If no other handler, just make it a generic sprite
						if( c == null )
							c = new Sprite(cache, parent);

						return c;
					}

				}).fields[0]
			);

			//var p = new Printer();
			//trace( p.printField(classFields[0]) );



			classFields.push({
				name : "classList",
				pos : pos,
				kind : FVar( macro: Map<String, Array<cerastes.macros.SpriteData.SpriteDataItem>>, macro $a{map} ),
				access : [AStatic],
			});

			classFields.push({
				name : "getClassList",
				pos : pos,
				kind : FFun({
					expr: macro {
						return classList;
					},
					ret: macro: Map<String, Array<cerastes.macros.SpriteData.SpriteDataItem>>,
					args: []
				}),
				access : [APublic, AStatic],
			});

			var definition:TypeDefinition = {
				fields: classFields,
				kind: TDClass(),
				name: "SpriteMetaProxy",
				pack: ["cerastes","SpriteMetaProxy"],
				pos: pos,
				meta: [{name:":keep", pos: pos}],
			};


			Context.defineType(definition);



		});


		return fields;
	}

	static function addDataFieldsForClass( fields: Array<ClassField>, clsMeta: Array<SpriteDataItem> )
	{
		for( f in fields )
		{
			if( f.meta.has(":sd.f") )
			{
				var m = f.meta.extract(":sd.f");
				clsMeta.push({
					name: f.name,
					label: m[0].params.length >= 2 ? ExprTools.getValue( m[0].params[1] ) : f.name,
					tooltip: m[0].params.length >= 3 ? ExprTools.getValue( m[0].params[2] ) : null,
					defaultValue: m[0].params.length >= 0 ? ExprTools.getValue( m[0].params[0] ) : null,
					type: f.type.toString()
				});
			}
		}
	}

	/**
	 * Type builder for sprite data object
	 * @param fields
	 * @return Array<Field>
	 */
	static function createSpriteDataClass( fields: Array<Field> ) : Array<Field>
	{
		var append: Array<Field> = [];
		var pos = Context.currentPos();

		var cls = Context.getLocalClass();
		cls.get().meta.add(":sd.tag",[macro 1], pos);

		var dataFields: Array<SpriteDataExpr> = [];

		addFieldsForClass(fields, dataFields );

		var parent = cls;

		while(parent.get().superClass != null )
		{
			parent = parent.get().superClass.t;
			addFieldsForParentClass(parent.get().fields.get(), dataFields);
		}

		// Step 1: Define a custom type

		var spriteDataName = Context.getLocalClass().get().name + "Data";
		var pack = ["game","meta","sprites"];//Context.getLocalModule().split('.');
		var fqDataName = pack.join(".") + "." + spriteDataName;

		//var parentClass =
		var parentDataClass = cls.get().superClass.t.get();
		var parentDataTypePath : TypePath = {
			pack: pack,
			name: parentDataClass.name + "Data"
		};

		var classFields: Array<haxe.macro.Expr.Field> = [];
		var kvReaders = [];
		var kvWriters = [];


		for( f in dataFields )
		{
			classFields.push({
				name : f.name,
				pos : pos,
				kind : FVar( f.type, f.defaultValue ),
				access : [APublic],
			});

			var n = f.name;

			// Deal with packers
			switch( f.type.toString() )
			{
				case "Int":
					kvReaders.push( macro {
						if( kv.key == $v{n})
							this.$n = cast kv.value;
					});
					kvWriters.push( macro {
						kv.push({key: $v{n}, value: this.$n });
					});
			}

		}

		classFields.push({
			name:"loadKV",
			pos: pos,
			kind: FFun({
				expr: macro {
					if( keyValues == null ) return;
					for( kv in keyValues )
					{
						$b{kvReaders}
					}
				},
				ret: null,
				args: [{name: "keyValues", type:macro: Array<cerastes.fmt.SpriteResource.CSDKV> }]
			}),
			access: [APublic],
		});

		classFields.push({
			name:"toKV",
			pos: pos,
			kind: FFun({
				expr: macro {
					var kv: Array<cerastes.fmt.SpriteResource.CSDKV> = [];
					$b{kvWriters}
					return kv;
				},
				ret: macro: Array<cerastes.fmt.SpriteResource.CSDKV>,
				args: []
			}),
			access: [APublic],
		});

		var definition:TypeDefinition = {
            fields: classFields,
            kind: TDClass(/*parentDataTypePath*/),
            name: spriteDataName,
            pack: pack,
            pos: pos,
			meta: [{name:":keep", pos: pos}, {name:":structInit", pos: pos}],
        };

		var spriteDataTypePath : TypePath = {
			name: definition.name,
			pack: definition.pack
		}

		Context.defineType( definition );

		// Step 2: Create an init function for it

		var dataType = fqDataName.toComplex();
		var spriteDataVarName = 'spriteData${Context.getLocalClass().get().name}';


		var setters = [];
		//hasParent = true; // Hack?

		for( f in dataFields )
		{
			var n = f.name;
			setters.push( macro {
				this.$n = $i{spriteDataVarName}.$n;
			});
		}

		var initFunc: Function = {
			expr: macro {
				if( $i{spriteDataVarName} == null )
				{
					$i{spriteDataVarName} = {};
					$i{spriteDataVarName}.loadKV(cache.spriteDef.typeData);
				}

				$b{setters}

			},
			ret: null, // ret = return type
			args: []
		};


		var getKVFunc: Function = {
			expr: macro {
				return  $i{spriteDataVarName}.toKV();
			},
			ret: null, // ret = return type
			args: []
		};

		append.push({
			name: "loadSpriteData",
			access: [Access.AOverride],
			kind: FieldType.FFun(initFunc),
			pos: Context.currentPos(),
			meta: [{ name:":noCompletion", pos: Context.currentPos() }],
		});

		append.push({
			name: "getKV",
			access: [Access.APublic, Access.AOverride],
			kind: FieldType.FFun(getKVFunc),
			pos: Context.currentPos(),
			//meta: [{ name:":noCompletion", pos: Context.currentPos() }],
		});

		append.push({
			name: spriteDataVarName,
			access: [Access.AStatic, Access.APrivate],
			kind: FieldType.FVar(dataType),
			pos: pos,
			meta: [{ name:":noCompletion", pos: Context.currentPos() }],
		});

		// finally, populate our compile time list
		//classList.set( Context.getLocalModule(), dataFields);

		//Context.registerModuleDependency( Context.getLocalModule(), "asdf" );

		return append;
	}


	static function addFieldsForClass( fields: Array<Field>, dataFields: Array<SpriteDataExpr>  )
	{
		var i = fields.length;


		while (i > 0)
		{
			var field = fields[--i];

			for( m in field.meta )
			{
				if( m.name == ":sd.f" )
				{
					switch (field.kind)
					{
						case FVar(t, expr) | FProp(_, _, t, expr):
							var isProp = field.kind.getName() == "FProp";

							dataFields.push( {type: t, defaultValue: m.params[0]  , name: field.name, label:field.name, tooltip:"FFF" } );

						default:
							throw "Only variables and props can be marked for spritedata!";
					}
				}
			}
		}
	}

	static function addFieldsForParentClass( fields: Array<ClassField>, dataFields: Array<SpriteDataExpr>  )
	{
		var i = fields.length;

		while (i > 0)
		{
			var field = fields[--i];

			if( field.meta.has(":sd.f"))
			{
				var m = field.meta.extract(":sd.f")[0];
				switch (field.kind)
				{
					case FVar(_,_):

						dataFields.push( {type: field.type.toComplexType(), defaultValue: m.params[0]  , name: field.name, label:field.name, tooltip:"FFF" } );

					default:
						throw "Only variables and props can be marked for spritedata!";
				}
			}
		}
	}


	#end

	/*
	public static macro function getClassList()
	{
		// make multidimensional array with points
		var classFields: Map<String,Array<haxe.macro.Expr.Field>> = [];
		var pos = Context.currentPos();

		var map: Array<Expr> = [];

		for( cls => fields in classList )
		{
			var items:Array<SpriteDataItem> = [for (value in fields) {
				type: value.type.toString(),
				defaultValue: 0, //$v{value.defaultValue},
				label: value.label,
				tooltip: value.tooltip,
				name: value.name
			}];

			map.push( macro $v{cls} => $v{items} );
		}

		return macro $a{map};
	}*/
}