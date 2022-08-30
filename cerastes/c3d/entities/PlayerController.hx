package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import h3d.col.Point;
import h3d.Quat;
import h3d.Vector;
import h3d.Matrix;
import hxd.Window;
import hxd.Key;

class PlayerController extends Controller
{
	public var player: Player;

	public function initialize( p: Player)
	{
		player = p;

	}

}