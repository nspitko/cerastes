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
	var moveSpeed = 20;
	var lookSpeed = 0.006;

	var lastX = 0;
	var lastY = 0;
	var cameraPos: Vec3 = new Vec3(-128,0,60);

	var rotationX: Float = 0;
	var rotationY: Float = 0;

	var controller: bullet.Native.KinematicCharacterController;

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
		// @todo non-shit version
		var pos = player.body.position;
		var cam = world.getScene().camera;

		var relX = lookSpeed * ( lastX - Window.getInstance().mouseX );
		var relY = lookSpeed * ( lastY - Window.getInstance().mouseY );

		rotationX += relX;
		rotationY += relY;

		//player.rotate(0,relY,0);

		var q = new Quat();

		//player.qRot.initRotation(rotationY,0, -rotationX);
		player.qRot.initRotation(0,0, -rotationX);
		q.initRotation(rotationY,0, -rotationX);


		var dir = q.getDirection().toPoint();
		dir.z = 0;
		dir.normalize();

		//DebugDraw.drawAxisM(player.getTransform());

		//DebugDraw.text('Player = ${player.getTransform().toString()}');

		// Movement directly controls the player body
		var isMoving = false;
		if( Key.isDown( Key.W ) )
		{
			isMoving = true;
			//dir = dir.multiply(1);
		}
		else if( Key.isDown( Key.S ) )
		{
			isMoving = true;
			dir *= -1;
		}

		if( Key.isDown( Key.D ) )
		{
			isMoving = true;
			var side = dir.toVector4().cross(new Vector4(0,0,1)).toVector();
			dir = side * -1;
		}
		else if( Key.isDown( Key.A ) )
		{
			isMoving = true;
			var side = dir.toVector4().cross(new Vector4(0,0,1)).toVector();
			dir = side;
		}

		if( Key.isPressed( Key.SPACE ) )
		{
			player.jump();
		}

		if( isMoving )
		{
			dir *= moveSpeed;

			//var pos = player.getAbsPos();
			//dir = dir.add( pos.getPosition().toPoint() );
			//player.setAbsOrigin( dir.x, dir.y, dir.z );
			@privateAccess player.moveDir.load(dir);
			//trace(dir);
		}
		else
			@privateAccess player.moveDir.set(0,0,0);

		//player.body.setTransform( pos );





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


		lastX = Window.getInstance().mouseX;
		lastY = Window.getInstance().mouseY;
	}

}