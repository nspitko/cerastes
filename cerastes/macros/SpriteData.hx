package cerastes.macros;

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

	macro public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();
		if( fields != null )
			fields = fields.concat( addDataField(fields) );

		Context.onAfterTyping(function(moduleTypes)
		{
			if( built ) return;

			var replicatedClasses = [];
			var dataMap: Map<String, Array<SpriteDataItem>> = [];
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


							dataMap.set( classType.name, clsMeta );


							// Build a new case for this replicated class
							var path = classType.module.split(".");
							var cls = path.pop();
							var typePath : TypePath = {
								pack: path,
								name: cls
							};
							//caseMap.set(clsid,macro { c = new $typePath(); } );

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



			var classFields: Array<haxe.macro.Expr.Field> = [];


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
							throw "Only variables and props can be marked as callbacks!";
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
						throw "Only variables and props can be marked as callbacks!";
				}
			}
		}
	}

	static function addDataField( fields: Array<Field> ) : Array<Field>
	{
		var append: Array<Field> = [];
		var pos = Context.currentPos();

		var cls = Context.getLocalClass();
		cls.get().meta.add(":sd.tag",[macro 1], pos);

		var dataFields: Array<SpriteDataExpr> = [];

		addFieldsForClass(fields, dataFields );
		//addFieldsForClass( cls.get().fields.get(), dataFields );

		var hasParent = false;

		if( cls.get().superClass != null  )
		{
			var sc = cls.get().superClass.t.get();
			if( sc.meta.has(":sd.tag") )
				hasParent = true;
		}

		while( cls.get().superClass != null )
		{
			cls = cls.get().superClass.t;
			addFieldsForParentClass( cls.get().fields.get(), dataFields );
		}




		// Step 1: Define a custom type

		var spriteDataName = Context.getLocalClass().get().name + "Data";
		var pack = ["game","meta","sprites"];//Context.getLocalModule().split('.');
		var fqDataName = pack.join(".") + "." + spriteDataName;

		var classFields: Array<haxe.macro.Expr.Field> = [];

		for( f in dataFields )
		{
			classFields.push({
				name : f.name,
				pos : pos,
				kind : FVar( f.type, f.defaultValue ),
				access : [APublic],
			});

		}


		var definition:TypeDefinition = {
            fields: classFields,
            kind: TDClass(),
            name: spriteDataName,
            pack: pack,
            pos: pos,
			meta: [{name:":keep", pos: pos}, {name:":structInit", pos: pos}],
        };
/*
		var definition:TypeDefinition = {
            fields: classFields,
            kind: TDStructure,
            name: spriteDataName,
            pack: pack,
            pos: pos,
			meta: [{name:":keep", pos: pos}, {name:":noCompletion", pos: pos}],
        };
*/
		Context.defineType( definition );


		// Step 2: Create an init function for it
		var setters = [];

		for( f in dataFields )
		{
			var n = f.name;
			setters.push( macro {
				this.$n = obj.$n;
			});
		}

		var type = fqDataName.toComplex();

		var initFunc: Function = {
			expr: macro {
				trace(dyn);
				var obj = cast(dyn, $type);
				$b{setters}
			},
			ret: null, // ret = return type
			args: [{name:"dyn", type: macro: Dynamic }]
		};

		append.push({
			name: "setSpriteData",
			access: hasParent ? [Access.APublic, Access.AOverride] : [Access.APublic],
			kind: FieldType.FFun(initFunc),
			pos: Context.currentPos(),
			meta: [{ name:":noCompletion", pos: Context.currentPos() }],
		});

		// finally, populate our compile time list
		//classList.set( Context.getLocalModule(), dataFields);

		//Context.registerModuleDependency( Context.getLocalModule(), "asdf" );

		return append;
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