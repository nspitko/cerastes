package cerastes.macros;

#if macro
import haxe.Exception;
import haxe.macro.Printer;
import haxe.macro.Expr;
import haxe.macro.Expr.Field;
import haxe.macro.Context;
using haxe.macro.Tools;

class CKeyValues
{

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

		var cls = Context.getLocalClass().get();
		var isRootClass = cls.superClass == null;


		if( !isRootClass )
		{
			throw new Exception("Packable cannot be polymorphic yet.");
		}

		for( f in fields )
		{
			switch (f.kind)
			{
				case FVar(t, expr):
					var ct: ComplexType;
					if( t != null )
						ct = t;
					else
					{
						// We need to infer the type from the expr. (this sucks)
						// @todo use Context.typeExpr(Expr)
						switch( expr.expr )
						{
							case EConst(const):
								switch( const )
								{
									case CFloat(f):
										ct = macro: Float;
									case CInt(int):
										ct = macro: Int;
									case CString(str):
										ct = macro: String;

									default:
										throw('Unknown const type ${const}');
								}

							case ENew(tp, params):
								ct = TPath(tp);

							default:
								throw('Unsupported constexpr ${expr}');
						}
					}
					addFieldpackers(f.name, ct, packersPlain, unpackersPlain, packersBinary, unpackersBinary);

				default:
			}
		}

		// Add unpack method

		append.push({
			name: "unpack",
			access: [Access.APublic],
			kind: FieldType.FFun({
				expr: macro {


					$b{unpackersPlain}
				},
				ret: null,
				args:[{ name:'kv', type: macro: cerastes.file.CKeyValues }]
			}),
			pos: pos,
		});

		return fields.concat(append);

	}

	static function addFieldpackers(ident: String, t: ComplexType, packersPlain: Array<Expr>, unpackersPlain: Array<Expr>, packersBinary: Array<Expr>, unpackersBinary: Array<Expr> )
	{
		var strType = t.toString();
		switch(t.getParameters()[0].name)
		{
			// Basic types
			case "String":
				unpackersPlain.push(macro {
					$i{ident} = kv.get( $v{ident} );
				});
			case "Int":
				unpackersPlain.push(macro {
					$i{ident} = Std.parseInt( kv.get( $v{ident} ) );
				});

			case "Float":
				unpackersPlain.push(macro {
					$i{ident} = Std.parseFloat( kv.get( $v{ident} ) );
				});



			case other:


				//throw new Exception('Unhandled packer type ${other}');
				trace('Unhandled packer type ${other}');
		}

	}


}

#end