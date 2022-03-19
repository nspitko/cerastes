
package cerastes.c3d;

import bullet.Body;
import h3d.scene.Object;

class PhysicsEntity extends Entity
{
	public var body: Body;

	public override function destroy()
	{
		super.destroy();

		if( body != null )
			body.remove();
	}

	public override function tick( delta: Float )
	{
		super.destroy();
		body.sync();
	}

	public override function setWorld( world: World )
	{
		if( body != null )
		{
			body.addTo( world.physics );
		}
	}

}