package cerastes.macros;

import haxe.DynamicAccess;
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

/**
 * Generates an FGD for all qdata classes
 */
class UIPopulator
{
	macro static public function populateObjects():Expr
	{
		// Grab the variables accessible in the context the macro was called.
		var cls = Context.getLocalClass().get();
		var fields = cls.fields.get();

		var exprs:Array<Expr> = [];
		do
		{

			for ( field in fields )
			{
				var optional = field.meta.has(":optional");
				if( field.meta.has(":obj") )
				{
					var fname = field.name; // string
					var ftype = field.type.getClass().pack.concat([field.type.getClass().name]);
					var cname = Context.getLocalClass().get().name;

					exprs.push(macro this.$fname = Std.downcast( root.getObjectByName( cerastes.macros.UIPopulator.camelToSnake( $v{fname} ) ), $p{ftype} ) );
					if( !optional )
					{
						exprs.push(macro {
							if( this.$fname == null )
							{
								initError("missing expected sub-object " + cerastes.macros.UIPopulator.camelToSnake( $v{fname} ) + "(" + $v{field.type.toString()} + ")");
								return;
							}
						});
					}

				}

				if( field.meta.has(":objRef") )
				{
					var fname = field.name; // string
					var ftype = field.type.getClass().pack.concat([field.type.getClass().name]);
					var cname = Context.getLocalClass().get().name;

					exprs.push(macro var __ref = Std.downcast( root.getObjectByName( cerastes.macros.UIPopulator.camelToSnake( $v{fname} ) ), cerastes.ui.Reference ) );
					exprs.push(macro if( __ref != null ) this.$fname = Std.downcast( __ref.get(), $p{ftype} ) );
					if( !optional )
					{
						exprs.push(macro {
							if( this.$fname == null )
							{
								initError("missing expected sub-object " + cerastes.macros.UIPopulator.camelToSnake( $v{fname} ) + "(" + $v{field.type.toString()} + ")");
								return;
							}
						});
					}

				}



			}

			if( cls.superClass != null )
			{
				cls = cls.superClass.t.get();
				fields = cls.fields.get();
			}
			else
				fields = null;
		}
		while( fields != null );

		// Generates a block expression from the given expression array
		return macro $b{exprs};
	}

	public static dynamic function camelToSnake(id: String) {
		var r = ~/[A-Z]/g;
		return r.map(id,(f: EReg ) -> { return '_${f.matched(0).toLowerCase()}'; });
	}
}