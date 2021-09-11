
package cerastes.tools;

import haxe.rtti.Meta;
import haxe.macro.Expr;

class ImguiTool
{
	public function update( delta: Float ) {}
	public function render( e: h3d.Engine)	{}

	public function destroy() {}
}

class ImguiToolManager
{
	static var tools = new Array<ImguiTool>();

	public static function showTool( cls: String )
	{
		var type = Type.resolveClass( "cerastes.tools." + cls);
		Utils.assert( type != null, 'Trying to create unknown tool cerastes.tools.${cls}');


		if(Meta.getType(type).multiInstance == null )
		{
			for( t in tools )
			{
				if( Std.isOfType( t, type ) )
					return t;
			}
		}


		var t = Type.createInstance(type, []);
		tools.push(t);

		return t;
	}

	public static function closeTool( t: ImguiTool )
	{
		t.destroy();
		tools.remove(t);
	}

	public static function update( delta: Float )
	{
		for( t in tools )
			t.update( delta );
	}

	public static function render( e: h3d.Engine )
	{
		for( t in tools )
			t.render( e );
	}

}