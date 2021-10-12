
package cerastes.fmt;


import haxe.Exception;
#if macro
import haxe.macro.Printer;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Context;
using haxe.macro.Tools;
#end

@:autoBuild( cerastes.fmt.SnakePak.build() )
interface Packable
{

}

class SnakePak
{
	public static var unpackString = ~/"([^"\\]*(\\.[^"\\]*)*)"/;
	public static var packString = ~/"/g;
	#if macro
	macro public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();
		var append: Array<Field> = [];
		var pos = Context.currentPos();

		var packersPlain: Array<Expr> = [];
		var unpackersPlain: Array<Expr> = [];

		var packersBinary: Array<Expr> = [];
		var unpackersBinary: Array<Expr> = [];

		var p = new Printer();

		var isRootClass = Context.getLocalClass().get().superClass == null;


		if( !isRootClass )
		{
			throw new Exception("Packable cannot be polymorphic.");
		}

		for( f in fields )
		{
			switch (f.kind)
			{
				case FVar(t, expr) | FProp(_, _, t, expr):
					addFieldPackers(f.name, t, packersPlain, unpackersPlain, packersBinary, unpackersBinary);

				default:
			}
		}

		// Add pack/unpack classes
		append.push({
			name: "packPlain",
			access: [Access.APublic],
			kind: FieldType.FFun({
				expr: macro {
					var out: String = "";

					$b{packersPlain}
					return out;
				},
				ret: macro: String,
				args:[]
			}),
			pos: pos,
		});

		append.push({
			name: "unpackPlain",
			access: [Access.APublic],
			kind: FieldType.FFun({
				expr: macro {
					$b{unpackersPlain}
				},
				ret: null,
				args:[{ name:'value', type: macro: String }]
			}),
			pos: pos,
		});

		return fields.concat(append);

	}

	static function addFieldPackers(identifier: String, t: ComplexType, packersPlain: Array<Expr>, unpackersPlain: Array<Expr>, packersBinary: Array<Expr>, unpackersBinary: Array<Expr> )
	{
		var strType = t.toString();
		switch(t.getParameters()[0].name)
		{
			// Basic types
			case "String":
				packersPlain.push(macro {
					out += '\n${identifier}:"' + cerastes.fmt.SnakePak.packString.replace( $i{identifier}, '\\"') + '"';
				});
			case "Int" | "Float":
				packersPlain.push(macro {
					out += '\n${identifier}:' + $i{identifier};
				});

			case other:


				//throw new Exception('Unhandled packer type ${other}');
				trace('Unhandled packer type ${other}');
		}

	}

	#end
}