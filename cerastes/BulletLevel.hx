package cerastes;

import cerastes.fmt.BulletLevel.CBLObject;

class BulletLevel extends h2d.Object
{
	var objects: Array<CBLObject>;
	var objectIndex: Int = 0;
	var timer: Float;

	public function tick( delta: Float )
	{
		timer += delta;
	}

	function spawnObject(o: CBLObject)
	{
		
	}
}