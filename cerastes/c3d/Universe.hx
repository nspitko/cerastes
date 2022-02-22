
package cerastes.c3d;

import h3d.scene.World;
import h3d.scene.Object;

// The megaclass.
class Universe extends Object
{
	public var physics: bullet.World;
	public var world: World;

	public static var physicsMaxSubSteps = 1;

	var entities: Array<PhysicsEntity> = [];

	public function new( ?parent: Object )
	{
		super( parent );
		physics = new bullet.World(this);
		physics.setGravity(0,0,-9.8);
	}

	public function add( e: PhysicsEntity )
	{
		e.body.addTo( physics );
		entities.push( e );
	}

	public function tick(delta: Float)
	{
		physics.stepSimulation( delta,physicsMaxSubSteps);
		for( e in entities )
			e.tick(delta);
	}


}