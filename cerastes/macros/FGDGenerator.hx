package cerastes.macros;

import haxe.DynamicAccess;
import sys.io.File;
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
class FGDGenerator
{
	#if macro

	@:persistent static var lastFgd: String;
	static var fgd: String = "//
// Forge Game Data file for Cerastes/Trenchbroom integration
//
// !! DO NOT EDIT !!
// This file is automatically regenerated on compile.
//
";

	macro public static function build():Array<Field>
	{
		var fields = Context.getBuildFields();

		Context.onGenerate(function(types)
		{
			var parsedClasses = 0;
			for( type in types )
			{
				switch(type)
				{
					case TInst(t, params):

						var classType : haxe.macro.Type.ClassType = t.get();

						if( classType.meta.has("qClass") )
						{
							parsedClasses++;

							var defs: Array< Map<String, Dynamic> > = [];
							var qdata = classType.meta.extract("qClass");
							for( q in qdata )
							{

								for( param in q.params )
								{
									var d = ExprTools.getValue(param);

									var line = '@${d.type}';
									if( d.base != null )
										line += ' base(${d.base.join(", ")})';
									if( d.size != null )
										line += ' size(${d.size[0]} ${d.size[1]} ${d.size[2]}, ${d.size[3]} ${d.size[4]} ${d.size[5]})';
									if( d.color != null )
										line += ' color(${d.color[0]} ${d.color[1]} ${d.color[2]})';
									if( d.model != null )
										line += ' model({ "path": ":${d.model.path}" })';
									line += " =";
									if( d.name != null )
										line += ' ${d.name}';
									if( d.desc != null )
										line += ' : "${d.desc}"';

									// @todo props
									if( d.fields != null)
									{
										line += "\n[";
										var arr: Array<Dynamic> = cast d.fields;
										for( f in arr )
										{
											line += '\n\t${f.name}(${f.type})';
											if( f.desc != null )
												line += ' : "${f.desc}"';
										}
										line += "\n]";
									}
									else
										line += ' []';



									line += "\n\n";

									fgd += line;

								}

							}

							//var defs = meta.qData;


						}

					default:
				}

			}


			var fgdFile = "res/game.fgd";
			if( lastFgd == null )
			{
				if( sys.FileSystem.exists( fgdFile ) )
					lastFgd = File.getContent( fgdFile );
			}

			if( fgd != lastFgd )
			{
				File.saveContent(fgdFile, fgd);
				trace("Notice: Updated FGD");
				lastFgd = fgd;
			}


		});


		return fields;
	}



	static function getTypePathName(type: haxe.macro.Type.ClassType )
	{
		var p = type.pack.join(".");
		if( p != "" ) p += '.';

		return p + type.name;
	}
#end
}