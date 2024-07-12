package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import h3d.col.Point;
import h3d.Quat;
import h3d.Vector4;
import h3d.Matrix;
import hxd.Window;
import hxd.Key;

class PlayerController extends Controller
{
	public var player: Player;

	var lookSpeed = 0.006;

	var currX: Float = 0;
	var currY: Float = 0;

	var rotationX: Float = 0;
	var rotationY: Float = 0;

	public function initialize( p: Player)
	{
		player = p;

	}

	public override function onCreated( def:  EntityData )
	{
		#if hlsdl
		// @todo: ImGuiToolManager should manage this.
		hxd.Window.getInstance().mouseMode = Relative(onMouse, true);
		#end
		#if hldx
		@:privateAccess hxd.Window.getInstance().window.clipCursor(true);
		#end
	}

	function onMouse(e: hxd.Event )
	{
		currX += e.relX;
		currY += e.relY;

		trace(currX);
	}

	public override function tick(delta: Float)
	{
		var relX = lookSpeed * -currX;
		var relY = lookSpeed * currY;

		rotationX += relX;
		rotationY += relY;

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

		if( Key.isPressed( Key.SPACE ) && player.onGround )
		{
			player.jump();
		}

		if( isMoving )
		{
			@:privateAccess player.moveDir.load(dir);
		}
		else
			@:privateAccess player.moveDir.set(0,0,0);

		currX = 0;
		currY = 0;
	}

}