
package cerastes.c3d;

import h3d.scene.Object;
import cerastes.Entity;

class Entity extends Object implements cerastes.Entity
{
	public var lookupId: String;

	public function new( ?parent: Object )
	{
		super( parent );
	}

	public function isAlive() { return true; }

	public function destroy() {
	}

	public function tick( delta: Float )
	{
	}

	// Called automatically when our world changes.
	public function setWorld( newWorld: World )
	{
	}

}