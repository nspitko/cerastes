package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import h3d.col.Point;
import h3d.Quat;
import h3d.Vector4;
import h3d.Matrix;
import hxd.Window;
import hxd.Key;

@:access( cerastes.c3d.entities.Player)
class FPSPlayerController extends PlayerController
{

	public override function onCreated( def:  EntityData )
	{
		super.onCreated( def );
		world.getScene().camera.setFovX(90,16/9);
	}


	public override function initialize( p: Player)
	{
		super.initialize(p);
	}

	public override function tick( d: Float )
	{
		super.tick(d);

		var cam = world.getScene().camera;

		player.qRot.initRotation(0,rotationY, -rotationX);

		// update camera from new player position
		var m = player.getTransform() ;
		m.setPosition( m.getPosition().add(player.eyePos) );
		cam.setTransform(m);

	}
}