package cerastes.c3d.entities;

import h3d.Vector;
import cerastes.c3d.Vec3;
import cerastes.macros.Metrics;
import cerastes.c3d.Entity.EntityData;
import h3d.col.Point;
import h3d.Quat;
import h3d.Vector4;
import h3d.Matrix;
import hxd.Window;
import hxd.Key;

@:access( cerastes.c3d.entities.Player )
class ThirdPersonPlayerController extends PlayerController
{
	var heightOffset: Vec3 = new Vec3(0,0,60);
	var distanceOffset: Float = 128;

	public override function onCreated( def:  EntityData )
	{
		super.onCreated( def );
		world.getScene().camera.setFovX(90,16/9);

		#if (hlsdl && !hlimgui)
		// @todo: ImGuiToolManager should manage this.
		sdl.Sdl.setRelativeMouseMode(true);
		#end
		#if hldx
		@:privateAccess hxd.Window.getInstance().window.clipCursor(true);
		#end
	}

	public override function initialize( p: Player)
	{
		super.initialize(p);
	}

	public override function tick( d: Float )
	{
		super.tick(d);

		rotationY =  CMath.fclamp(rotationY, -85 * CMath.DEG_RAD, 85 * CMath.DEG_RAD) ;

		var cam = world.getScene().camera;

		var quat: Quat;
		player.qRot.initRotation(0,rotationY, -rotationX);
		@:privateAccess player.posChanged = true;

		// update camera from new player position
		var m = player.getTransform().clone();
		m.setPosition( m.getPosition().add( heightOffset + ( m.front() * -distanceOffset ) ) );



		cam.setTransform(m);

		return;
/*

		var q = new Quat();
		q.initRotation(rotationY,0, -rotationX);

		// update camera from new player position
		var m: cerastes.c3d.Matrix = q.toMatrix();
		var pos = player.getTransform().getPosition();
		m.setPosition( new Vector4( pos.x, pos.y, pos.z, 1 ) );

		// Trace back to our target pos, find the closest point we can get before hitting a wall
		var cameraOffset = cameraPos.clone();

		var playerPos = new Vector(player.x, player.y, player.z + cameraPos.z);

		cameraOffset *= m;

		//DebugDraw.lineV(cameraOffset, playerPos);

		var ray = world.physics.rayTestV(playerPos, cameraOffset, PLAYER, MASK_ALL);
		if( ray.hit )
		{
			cameraOffset = ray.position;
		}

		//DebugDraw.box( cameraOffset.toPoint() );

		cam.pos.set( cameraOffset.x, cameraOffset.y, cameraOffset.z );
		cam.target.set( player.x, player.y, player.z + player.eyePos.z );
*/
	}

}