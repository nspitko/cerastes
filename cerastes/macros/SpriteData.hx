package cerastes.macros;

import haxe.rtti.Meta;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Json;
#if macro
using haxe.macro.Tools;
#end


/**
 * Builds fields related to sprite runtime data defined in the sprite editor
 *
 * Mark relevant fields with @:data(defaultValue, field name to show in the editor, help tooltip)
 * tooltip is optional.
 */
class SpriteData
{
	#if macro
	macro public static function build():Array<Field>
	{
		trace("Running!");
		var fields = Context.getBuildFields();
		if( fields == null )
			return fields;

		fields = fields.concat( addDataField(fields) );

		return fields;
	}

	static function addDataField( fields: Array<Field> ) : Array<Field>
	{
		var append: Array<Field> = [];
		var pos = Context.currentPos();

		var dataFields: Array<{type: ComplexType, defaultValue: Expr, name: String, label: String, tooltip: String, isProp: Bool}> = [];

		var i = fields.length;
		while (i > 0)
		{
			var field = fields[--i];
			// Only modify replicated fields.
			var found = false;
			for( m in field.meta )
			{
				if( m.name == ":data" )
				{
					switch (field.kind)
					{
						case FVar(t, expr) | FProp(_, _, t, expr):
							var isProp = field.kind.getName() == "FProp";

							dataFields.push( {type: t, defaultValue: m.params[0]  , name: field.name, label:field.name, tooltip:"FFF", isProp: isProp } );

						default:
							throw "Only variables and props can be marked as callbacks!";
					}
				}
			}
		}


		// Step 1: Define a custom type

		var spriteDataName = "SpriteData" + Context.getLocalClass().get().name;
		var pack = ["game"];//Context.getLocalModule().split('.');
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
			meta: [{name:":keep", pos: pos}, {name:":noCompletion", pos: pos}, {name:":structInit", pos: pos}],
        };

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

		var initFunc: Function = {
			expr: macro {
				$b{setters}
			},
			ret: null, // ret = return type
			args: [{name:"obj", type: fqDataName.toComplex() }]
		};

		append.push({
			name: "setSpriteData",
			access: [Access.APublic],
			kind: FieldType.FFun(initFunc),
			pos: Context.currentPos(),
			meta: [{ name:":noCompletion", pos: Context.currentPos() }],
		});


		return append;
	}

	#end
}