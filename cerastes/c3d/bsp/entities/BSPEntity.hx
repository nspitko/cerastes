package cerastes.q3bsp.entities;

import h3d.Vector;
import h3d.scene.Object;

class BSPEntity extends Object
{
	public var position( get, set ): Vector;

	var velocity: Vector = new Vector(0,0,0);
	var speed = 20.;

	var map: BSPMap;

	var collisionMins: Vector;
	var collisionMaxs: Vector;

	public function new(map: BSPMap, ?parent: Object )
	{
		super(parent);

		collisionMins = new Vector(-10,-10,-30);
		collisionMaxs = new Vector(10,10,30);

		this.map = map;
	}

	public function tick(delta:Float)
	{
		//position = position.add(velocity);
	}

	function get_position()
	{
		return new Vector(x, y, z);
	}

	function set_position( v: Vector )
	{
		x = v.x;
		y = v.y;
		z = v.z;

		return v;
	}

}