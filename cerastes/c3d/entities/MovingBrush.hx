package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import h3d.Vector;
import h3d.col.Point;
import cerastes.c3d.QEntity.QTarget;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;


class MovingBrush extends Brush
{
	function moveTo( target: h3d.col.Point, speed: Float ): Bool
	{

		var pos = new h3d.col.Point(x,y,z);
		var dir = target.sub(pos);
		dir.normalize();
		var move = dir.multiply(speed);

		setAbsOrigin( x + move.x, y+move.y, z+move.z );

		pos.set(x,y,z);
		var dist = pos.sub(target);

		if( dist.length() < move.length() )
		{
			setAbsOrigin( target.x, target.y, target.z );
			rebakeLights();
			return true;
		}

		rebakeLights();

		return false;
	}

	function rebakeLights()
	{
		return;

		for( e in world.entityManager.entities )
		{
			if( Std.isOfType( e, Light ) )
			{
				var l: Light = cast e;
				var pl: h3d.scene.pbr.PointLight = @:privateAccess cast l.light;
				var dist = new h3d.col.Point(l.x,l.y,l.z).distance( new Point(x,y,z) );

				// @todo

			}
		}
	}
}

enum QDoorState
{
	CLOSED;
	OPENING;
	OPEN;
	CLOSING;
}

@qClass(
	// Define base types we're going to need later.
	{
		name: "func_mover_test",
		type: "SolidClass",
		base: ["Angle", "Target", "KillTarget"],
		fields: [
			{
				name: "height",
				desc: "How long the door stays open",
				type: "float",
				def: "64"
			}
		]
	}
)
class FuncMoverTest extends MovingBrush
{
	var startingHeight:Float = 0;
	var maxHeight:Float = 0;
	var dir: Float = 1;

	override function onCreated( def: EntityData )
	{
		maxHeight = Std.parseFloat( def.getProperty("height") );
		startingHeight = z;
	}

	public override function tick( delta: Float )
	{
		var body = bodies[0];
		z = body.position.z;
		if( dir > 0 && z >= startingHeight + maxHeight )
			dir = -1;
		else if( dir < 0 && z <= startingHeight )
			dir = 1;

		// @todo unfuck this
		z += dir * delta * 100;

		body.setTransform(new h3d.col.Point( body.position.x, body.position.y, z ) );

	}
}


@qClass(
	// Define base types we're going to need later.
	{
		name: "func_door",
		type: "SolidClass",
		base: ["Angle", "Target", "KillTarget"],
		fields: [
			{
				name: "wait",
				desc: "How long the door stays open",
				type: "float",
				def: "3"
			},
			{
				name: "speed",
				desc: "Brush movement speed",
				type: "float",
				def: "100"
			},
			{
				name: "lip",
				desc: "offset added to default movement distance",
				type: "float",
				def: "8"
			},
			{
				name: "health",
				desc: "How much damage to take before activating (0 for never activate)",
				type: "float",
				def: "0"
			},
			{
				name: "message",
				desc: "Message to show when the player touches this door in its closed state",
				type: "string"
			},
			{
				name: "spawnflags",
				type: "flags",
				opts: [
					{ f: 1, d: "Starts open", v: 0 },
					{ f: 4, d: "Don't link", v: 0 },
					{ f: 32, d: "Toggle", v: 0 },
				]
			}
		]
	}
)
class FuncDoor extends MovingBrush
{
	var target: String;
	var killTarget: String;

	var speed: Float;
	var wait: Float;

	var state: QDoorState = CLOSED;
	var closedPos: h3d.col.Point;
	var openPos: h3d.col.Point;
	var dir: h3d.col.Point;

	var openTime: Float;

	var sensor: BulletBody;

	/**
	 *  https://cdn.discordapp.com/attachments/891006540943867924/1010272786721288302/unknown.png
	 * 	let V0 be a unit vector along the direction you are checking the height of. Generate this in the usual way (cos(theta),sin(theta)) where theta is the angle you care about (probably in radians)
		let V be a vector whose components Vx and Vy are equal to the absolute value of V0x and V0y
		let X be a vector (Xx, 0) where Xx is the width of your object
		let Y be a vector (0, Yy) where Yy is the height of your object

		the height H of your object along V0 is defined by the following equation
		H = V•X + V•Y

	 */

	/**
	 * onCreated
	 * @param def
	 */
	override function onCreated( def: EntityData )
	{
		super.onCreated( def );

		target = def.getProperty("target");
		killTarget = def.getProperty("target");

		speed = def.getPropertyFloat("speed", 100);
		wait = def.getPropertyFloat("wait", 3);
		var lip = def.getPropertyFloat("lip", 0);

		closedPos = new Point(x,y,z);

		// Calculate open position
		var dir = new Point( Math.cos( angle * ( Math.PI / 180 ) ), Math.sin( angle * ( Math.PI / 180 ) ), 0 );
		dir.normalize();
		var bounds = brush.getBounds();
		var dist = Math.abs( bounds.getSize().dot( dir ) ) + lip;

		var offset = dir.multiply(dist);

		openPos = new Point( closedPos.x + offset.x, closedPos.y + offset.y, closedPos.z );

		if( name == null )
		{
			createSensor();
		}

	}

	function createSensor()
	{
		var bounds = getBounds();
		// @todo proper sensor
		var box = new bullet.Native.BoxShape(new bullet.Native.Vector3( 64,64,64) );

		sensor = new BulletBody(box, 1, GhostObject );
		sensor.addTo(world.physics, TRIGGER, MASK_TRIGGER );

		sensor.setTransform( new h3d.col.Point( x,y,z ) );
		sensor.object = this;

		//debugDrawBody( sensor, -1, 0xFF0000 );
	}

	override function onCollide( manifold: bullet.Native.PersistentManifold, body: BulletBody, other: Entity, otherBody: BulletBody )
	{
		if( body != sensor )
			return;

		fireInput( other, "trigger" );
	}

	public override function onInput( source: Entity, port: String )
	{
		if( port == "trigger")
			open();

		if( state == OPEN && target != null )
			fireOutput( targetName, "trigger" );

	}

	function open()
	{
		if( state == OPENING )
			return;
		if( state == OPEN )
		{
			openTime = hxd.Timer.lastTimeStamp;
			return;
		}

		state = OPENING;
	}

	function close()
	{
		state = CLOSING;
	}


	public override function tick( delta: Float )
	{
		var body = bodies[0];
		z = body.position.z;

		switch( state )
		{
			case OPENING:
				if( moveTo( openPos, speed * delta ) )
				{
					state = OPEN;
					openTime = hxd.Timer.lastTimeStamp;
				}

			case OPEN:
				if(wait >= 0 && openTime + wait < hxd.Timer.lastTimeStamp )
					close();

			case CLOSING:
				if( moveTo( closedPos, speed * delta ) )
				{
					state = CLOSED;
				}
			case CLOSED:
		}

		//body.setTransform(new h3d.col.Point( body.position.x, body.position.y, z ) );

	}
}



@qClass(
	// Define base types we're going to need later.
	{
		name: "func_button",
		type: "SolidClass",
		base: ["Angle", "Target", "KillTarget"],
		fields: [
			{
				name: "wait",
				desc: "How long before reset",
				type: "float",
				def: "1"
			},
			{
				name: "delay",
				desc: "How long before we trigger",
				type: "float",
				def: "0"
			},
			{
				name: "speed",
				desc: "Brush movement speed",
				type: "float",
				def: "40"
			},
			{
				name: "lip",
				desc: "offset added to default movement distance",
				type: "float",
				def: "8"
			},
			{
				name: "health",
				desc: "How much damage to take before activating (0 for never activate)",
				type: "float",
				def: "0"
			},
			{
				name: "message",
				desc: "Message to show when the player touches this door in its closed state",
				type: "string"
			},
			{
				name: "spawnflags",
				type: "flags",
				opts: [
					{ f: 1, d: "Starts open", v: 0 },
					{ f: 4, d: "Don't link", v: 0 },
					{ f: 32, d: "Toggle", v: 0 },
				]
			}
		]
	}
)
class FuncButton extends FuncDoor
{
	var triggerDelay: Float;
	override function onCreated( def: EntityData )
	{
		super.onCreated( def );

		triggerDelay = def.getPropertyFloat("delay", 0);

	}

	public override function onInput( source: Entity, port: String )
	{
		if( state != CLOSED )
			return;


		if( target != null )
			fireOutput( target, "trigger" );

	}
}
