
package cerastes.tools;

class ImguiTool
{
	public function update( delta: Float ) {}
	public function render( e: h3d.Engine)	{}

}

class ImguiToolManager
{
	static var tools = new Array<ImguiTool>();

	public static function showTool( cls: String )
	{
		var type = Type.resolveClass( "cerastes.tools." + cls);
		Utils.assert( type != null, 'Trying to create unknown tool cerastes.tools.${cls}');

		for( t in tools )
		{
			if( Std.isOfType( t, type ) )
				return;
		}

		var t = Type.createInstance(type, []);
		tools.push(t);
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