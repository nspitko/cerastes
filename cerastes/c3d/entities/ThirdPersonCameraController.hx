package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import h3d.col.Point;
import h3d.Quat;
import h3d.Vector;
import h3d.Matrix;
import hxd.Window;
import hxd.Key;

@:access( cerastes.c3d.entities.Player )
class ThirdPersonPlayerController extends PlayerController
{
	var moveSpeed = 6;
	var lookSpeed = 0.006;

	var lastX = 0;
	var lastY = 0;
	var cameraPos: Vector = new Vector(0,-128,60);

	var rotationX: Float = 0;
	var rotationY: Float = 0;

	var controller: bullet.Native.KinematicCharacterController;

	public override function onCreated( def:  EntityData )
	{
		super.onCreated( def );
		world.getScene().camera.setFovX(90,16/9);

		#if hlsdl
		sdl.Sdl.setRelativeMouseMode(true);
		#end
		#if hldx
		@:privateAccess hxd.Window.getInstance().window.clipCursor(true);
		#end
	}

	public override function initialize( p: Player)
	{
		super.initialize(p);

		controller = new bullet.Native.KinematicCharacterController(cast @:privateAccess p.body.inst, cast @:privateAccess p.body.shape, 32, new bullet.Native.Vector3(0,0,1) );

		// @todo
		//controller.setFallSpeed(9.8 * QWorld.METERS_TO_QU );
		//controller.setGravity( new bullet.Native.Vector3(0,0, -9.8 * QWorld.METERS_TO_QU) );
		controller.warp( new bullet.Native.Vector3( p.x, p.y, p.z ) );
		controller.setUseGhostSweepTest(false);

		controller.setJumpSpeed( 225 );
		@:privateAccess world.physics.inst.addAction( controller );
	}

	public override function tick( d: Float )
	{
		//controller.playerStep( @:privateAccess world.physics.inst, d );
		// @todo non-shit version
		var pos = player.body.position;
		var cam = world.getScene().camera;

		var relX = lookSpeed * ( lastX - Window.getInstance().mouseX );
		var relY = lookSpeed * ( lastY - Window.getInstance().mouseY );

		rotationX += relX;
		rotationY += relY;

		//player.rotate(0,relY,0);

		var q = new Quat();

		player.qRot.initRotation(0,rotationY, -rotationX);


		var dir = player.getRotationQuat().getDirection().toPoint();
		dir.z = 0;
		dir.normalize();

		//DebugDraw.text('Player = ${player.getTransform().toString()}');

		// Movement directly controls the player body
		var isMoving = false;
		if( Key.isDown( Key.W ) )
		{
			isMoving = true;
			dir = dir.multiply(1);
		}
		else if( Key.isDown( Key.S ) )
		{
			isMoving = true;
			dir = dir.multiply(-1);
		}

		if( Key.isDown( Key.D ) )
		{
			isMoving = true;
			var side = dir.toVector().cross(new Vector(0,0,1)).toPoint();
			dir = side.multiply(-1);
		}
		else if( Key.isDown( Key.A ) )
		{
			isMoving = true;
			var side = dir.toVector().cross(new Vector(0,0,1)).toPoint();
			dir = side.multiply(1);
		}

		if( Key.isPressed( Key.SPACE ) )
		{
			controller.jump();
		}

		if( isMoving )
		{
			dir = dir.multiply(moveSpeed);
			controller.setWalkDirection( new bullet.Native.Vector3(dir.x, dir.y, dir.z) );
		}

		else
			controller.setWalkDirection( new bullet.Native.Vector3(0,0,0) );

		//player.body.setTransform( pos );





		// update camera from new player position
		var m = player.getTransform() ;
		// Trace back to our target pos, find the closest point we can get before hitting a wall

		var cameraOffset = cameraPos.clone();
		var playerPos = new Vector(player.x, player.y, player.z + cameraPos.z);

		cameraOffset.transform(m);

		DebugDraw.lineV(cameraOffset, playerPos);

		var ray = world.physics.rayTestV(playerPos, cameraOffset, PLAYER, MASK_ALL);
		if( ray != null )
		{
			cameraOffset = ray.position;
		}

		DebugDraw.box( cameraOffset.toPoint() );

		cam.pos.set( cameraOffset.x, cameraOffset.y, cameraOffset.z );
		cam.target.set( player.x, player.y, player.z + player.eyePos.z );


		lastX = Window.getInstance().mouseX;
		lastY = Window.getInstance().mouseY;
	}

}