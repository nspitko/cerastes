
package cerastes.c3d.q3bsp;

class Q3BSPRenderer extends h3d.scene.fwd.Renderer
{
	override function getPassByName(name:String)
	{
		if( name == "overlay" )
			return defaultPass;

		return super.getPassByName(name);
	}

	override function render() {
		if( has("shadow") )
			renderPass(shadow,get("shadow"));

		if( has("depth") )
			renderPass(depth,get("depth"));

		if( has("normal") )
			renderPass(normal,get("normal"));

		renderPass(defaultPass, get("default") );
		renderPass(defaultPass, get("alpha"), backToFront );
		renderPass(defaultPass, get("additive") );
		renderPass(defaultPass, get("overlay") );
	}
}