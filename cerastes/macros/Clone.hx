package cerastes.macros;

import haxe.macro.Printer;
import haxe.macro.Type.ClassType;
import haxe.macro.Context;
import haxe.macro.Expr;
#if macro
using haxe.macro.Tools;
#end



@:autoBuild(cerastes.macros.Clone.build())
interface Cloneable {}

class Clone
{
	#if macro
	macro public static function build( ):Array<Field>
	{
		var fields = Context.getBuildFields();
		if( fields == null )
			fields = [];

		//var clsType = getClassTypeFromExpr( );
		var ftype = TPath( { pack: Context.getLocalClass().get().pack, name: Context.getLocalClass().get().name } );
		//var ftype =  Context.getLocalClass().get().pack;


		if( !hasField("clone", fields) )
		{
			var members: Array<Expr> = [];
			for( f in fields )
			{
				switch( f.kind )
				{
					case FVar(t, expr):
						var n = f.name;
						switch( t.toType() )
						{
							case TInst(rt, params):


								for( i in t.toType().getClass().interfaces )
								{
									if( i.t.get().name == "Cloneable" )
									{
										members.push( macro {
											other.$n = $i{n}.clone();
										});
									}
									else
									{
										// Never copy refs
										members.push( macro {
											other.$n = null;
										});
									}
								}


							default:

								members.push( macro {
									other.$n = $i{n};
								});

						}



					default:
				}
			}

			var clone:Function = {
				expr: macro {
					var other: $ftype = {};
					$b{members};
					return other;
				},
				ret: ftype,
				args:[]
			};

			fields.push({
				name: "clone",
				access: [APublic],
				kind: FieldType.FFun( clone ),
				pos: Context.currentPos(),
				meta: [],
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