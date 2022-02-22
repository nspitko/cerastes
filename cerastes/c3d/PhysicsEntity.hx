
package cerastes.c3d;

import bullet.Body;
import h3d.scene.Object;
import cerastes.Entity;

class PhysicsEntity extends Object implements Entity
{
	public var lookupId: String;
	public var body: Body;

	public function new( ?parent: Object )
	{
		super( parent );
	}

	public function isAlive() { return true; }

	public function destroy() {
		if( body != null )
			body.remove();
	}

	public function tick( delta: Float )
	{
		body.sync();
	}

}