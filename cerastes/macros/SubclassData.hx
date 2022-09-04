package cerastes.macros;

import haxe.macro.Context;
import haxe.macro.Expr;
using Lambda;

class SubclassData
{
	macro static public function getSubclassData():Expr
	{
		var cls = Context.getLocalClass().get();
		do
		{
			var m = cls.module;
			var p = cls.module.split(".");
			p.pop();
			var tpath: TypePath = {pack: p , name: '${cls.name}SubclassData'  };
			try
			{
				var ct = TPath(tpath);
				var t = Context.resolveType(TPath(tpath), Context.currentPos() );

				return macro (cast subclassData : $ct);
			}
			catch(e)
			{
				// Don't care
			}

			cls = cls.superClass != null ? cls.superClass.t.get() : null;

		}
		while( cls != null );

		throw "Trying to load subclass data on non-entity class!";
		return macro null;
	}
}