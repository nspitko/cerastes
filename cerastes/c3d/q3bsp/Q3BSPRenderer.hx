
package cerastes.c3d.q3bsp;

class Q3BSPRenderer extends h3d.scene.fwd.Renderer
{
	override function getPassByName(name:String):h3d.pass.Base
	{
		if( name == "overlay" )
			return defaultPass;
		
		return super.getPassByName(name);
	}
}