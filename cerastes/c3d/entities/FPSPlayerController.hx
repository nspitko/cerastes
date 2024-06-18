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
	var moveSpeed = 6;
	var lookSpeed = 0.006;

	var lastX = 0;
	var lastY = 0;

	var rotationX: Float = 0;
	var rotationY: Float = 0;


	var controller: bullet.Native.KinematicCharacterController;

	public override function onCreated( def:  EntityData )
	{
		super.onCreated( def );
		world.getScene().camera.setFovX(90,16/9);

		#if hlsdl
		//sdl.Sdl.setRelativeMouseMode(true);
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
			//dir *= 1;
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
			controller.jump();
		}

		if( isMoving )
		{
			dir *= moveSpeed;
			controller.setWalkDirection( new bullet.Native.Vector3(dir.x, dir.y, dir.z) );
		}

		else
			controller.setWalkDirection( new bullet.Native.Vector3(0,0,0) );

		//player.body.setTransform( pos );





		// update camera from new player position
		var m = player.getTransform() ;
		m.setPosition( m.getPosition().add(player.eyePos) );
		cam.setTransform(m);



		lastX = Window.getInstance().mouseX;
		lastY = Window.getInstance().mouseY;
	}

	/*

	public override function onCreated(  def: cerastes.c3d.map.Data.Entity )
	{
		super.onCreated(def);

		world.getScene().camera = new cerastes.c3d.Camera();
		world.getScene().camera.mcam = getTransform();

		world.getScene().camera.setFovX(70,16/9);
		world.getScene().camera.zoom = 5;

		var targetMat = world.getScene().camera.mcam;

		var basisRot = new Matrix();
		basisRot.initRotationAxis(new Vector4(0,0,1),90 * ( Math.PI / 180 ));

		world.getScene().camera.mcam.multiply3x4(basisRot, targetMat);
	}

	public override function tick( d: Float )
	{
		// @todo non-shit version
		var pos = player.body.position;
		var cam = world.getScene().camera;


		// Movement directly controls the player body
		if( Key.isDown( Key.W ) )
		{
			var pos = player.body.position;
			pos.x += d * moveSpeed;

		}

		player.body.setTransform( pos );

		// Camera control ONLY affects the camera proj matrix.

		var relX = lookSpeed * ( lastX - Window.getInstance().mouseX );
		var relY = lookSpeed * ( lastY - Window.getInstance().mouseY );

		cam.zoom = 1;

		DebugDraw.text('xRel = ${relX}');
		DebugDraw.text('viewX = ${cam.viewX}');
		DebugDraw.text('viewY = ${cam.viewY}');
		DebugDraw.text('Zoom = ${cam.zoom}');

		var xRot = new Quat();

		//xRot.initRotation(0,0,relX);
		var xRotMat = new Matrix();
		xRotMat.initRotationAxis(new Vector4(0,1,0), relX);

		DebugDraw.text( '${xRotMat.toString()}' );
		var targetMat = world.getScene().camera.mcam;

		world.getScene().camera.mcam.multiply3x4(xRotMat, targetMat);



		DebugDraw.text( '${world.getScene().camera.mcam.toString()}' );


		lastX = Window.getInstance().mouseX;
		lastY = Window.getInstance().mouseY;
	}*/
}