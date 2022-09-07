package cerastes.c3d.entities;

import cerastes.macros.Metrics;
import bullet.Constants.CollisionFlags;
import cerastes.c3d.Entity.EntityData;
import cerastes.c3d.BulletWorld.BulletRayTestResult;
import h3d.Vector;
import h3d.col.Point;
import h3d.scene.Graphics;

enum MoveType
{
	DEAD;
	GROUND;
	FLY;
	NOCLIP;
	FREEZE;
}

/**
 * Actors are entities which handle their own collision.
 */
class Actor extends Entity
{
	public var hp(default, never): Int;

	public var velocity: Vector = new Vector(0,0,0);

	// Defaults
	var bodyRadius: Float = 8;
	var bodyHeight: Float = 32;

	var moveType: MoveType = GROUND;

	var groundEntity: Entity = null;
	var groundPlane: Bool = false;
	var walking: Bool = false;
	var groundTrace: BulletRayTestResult = null;

	var moveSpeed = 2;
	var moveSpeedAccel = 10;
	var moveSpeedAccelAir = 10;

	var minWalkNormal = 0.7;


	var moveDir = new Vector(0,0,0);
	var moveTime:Float = 1;

	var touchingEntities: Array<Entity> = [];

	var impactSpeed: Float = 0;

	// Constants
	static final stopSpeed = 100.0;
	static final maxClipPlanes = 5;
	static final overClip = 1.001;
	static final stepSize = 18;

	static final frictionGround = 6.0;
	static final frictionWater = 1.0;
	static final frictionFlight = 3.0;

	public override function tick( delta: Float )
	{
		touchingEntities = [];

		if( body != null )
			updateMovement( delta );
	}

	override function createBody( def: EntityData )
	{
		// @todo: Get body size from model
		var shape = new bullet.Native.BoxShape(new bullet.Native.Vector3( bodyRadius,bodyRadius,bodyHeight/2 ));
		bodyOffset.set(0, 0, bodyHeight / 2);
		body = new BulletBody( shape, 50, RigidBody );
		world.physics.addBody( body, NPC, MASK_NPC );
		body.slamRotation = false;
		body.slamPosition = false;

		var rb : bullet.Native.RigidBody = cast @:privateAccess body.inst;
		body.collisionFlags |= CollisionFlags.CF_KINEMATIC_OBJECT;
		body.object = this;
	}

	function updateMovement( delta: Float )
	{
		Metrics.begin("updateMovement");
		// zero out impact speed
		impactSpeed = 0;
		moveTime = 1;

		var origin = getBodyOrigin();

		var lastOrigin = origin.clone();
		var oldVelocity = velocity.clone();


		// @todo Update view angles
		// @todo check duck


		moveGroundTrace();

		switch( moveType )
		{
			case GROUND:
				if( walking )
					moveWalk( delta );
				else
					moveAir( delta );

			default:
				Utils.warning('Unsupported move type ${moveType}');
		}


		moveGroundTrace();

		DebugDraw.text('OnGround=${groundPlane ? "true" : "false"}');
		DebugDraw.text('Vel=${velocity.x}, ${velocity.y}, ${velocity.z}');

		Metrics.end();

	}

	function moveAir( delta: Float )
	{
		moveFriction( delta );

		var wishDir = moveDir.clone();


		var wishVel = moveDir.clone().normalized().multiply( moveSpeed );
		var wishSpeed = wishDir.normalized();
		wishSpeed = wishSpeed.multiply( delta );

		moveAccelerate( delta, wishDir, wishSpeed.length(), moveSpeedAccelAir );

		// we may have a ground plane that is very steep, even
		// though we don't have a groundentity
		// slide along the steep plane
		if( groundPlane )
		{
			velocity = moveClipVelocity( velocity, groundTrace.normal, overClip );
		}

		moveStepSlide( delta, true );
	}

	function moveWalk( delta: Float )
	{
		// @todo: checkJump

		moveFriction( delta );

		var wishVel = moveDir.clone().normalized().multiply( moveSpeed );


		moveAccelerate( delta, moveDir, moveSpeed, moveSpeedAccel );

		var vel = velocity.length();


		velocity = moveClipVelocity(velocity, groundTrace.normal, overClip);

		velocity.normalize();
		velocity = velocity.multiply(vel);



		if( velocity.x == 0 && velocity.y == 0 )
			return;

		moveStepSlide( delta, false );

	}

	function moveStepSlide( delta: Float, gravity: Bool )
	{
		var startOrigin = getBodyOrigin();
		var startVelocity = velocity.clone();

		var ss; // Step Size

		if( moveSlide( delta, gravity) )
			return; // We got to where we wanted to go first try

		var down = startOrigin.clone();
		down.z -= stepSize;

		var rc = world.physics.shapeTestV( cast body.shape, startOrigin, down, body.group, body.mask );
		var up = new Vector(0,0,1);

		// Never step up when you have velocity
		if( velocity.z >0 && ( rc.fraction == 1 || rc.normal.dot( up ) < 0.7 ) )
		{
			return;
		}

		// Snap down to the floor. after our first slide.
		var downOrigin = CMath.vectorFrac( startOrigin, down, rc.fraction );
		startOrigin = getBodyOrigin();
		var downVelocity = velocity.clone();

		up.load( startOrigin );
		up.z += stepSize;

		// test player position if they were a stepheight height
		var rc = world.physics.shapeTestV( cast body.shape, startOrigin, up, body.group, body.mask );
		if( rc.fraction == 0 ) // @todo: TEST
		{
			trace("bend can't step");
			return;
		}

		var newPos = CMath.vectorFrac( startOrigin, up, rc.fraction );
		ss = newPos.z - startOrigin.z;
		setBodyOrigin(newPos.x, newPos.y, newPos.z);
		//trace("SetAbs: stepslide stepheight");
		velocity.load(startVelocity);

		moveSlide( delta, gravity);

		// Push down the final amount
		down.load(getBodyOrigin());
		down.z -= ss;

		var rc = world.physics.shapeTestV( cast body.shape, getBodyOrigin(), down, body.group, body.mask );
		if( rc.fraction > 0 )
		{
			var newPos = CMath.vectorFrac( getBodyOrigin(), down, rc.fraction );
			setBodyOrigin( newPos.x, newPos.y, newPos.z );
			//trace("SetAbs: stepslide frac>0");
		}
		if( rc.fraction < 1 )
		{
			velocity = moveClipVelocity( velocity, rc.normal, overClip );
		}




	}

	function moveSlide( delta: Float, gravity: Bool )
	{
		var primalVelocity = velocity.clone();
		var planes = new haxe.ds.Vector<Vector>(5);

		var endVelocity = new Vector();

		if( gravity )
		{
			endVelocity = velocity.clone();
			endVelocity.z -= world.gravity * delta;
			velocity.z = ( velocity.z + endVelocity.z ) * 0.5;
			primalVelocity.z = endVelocity.z;

			if( groundPlane )
			{
				velocity = moveClipVelocity( velocity, groundTrace.normal, overClip );
			}
		}

		var numPlanes = 0;
		if( groundPlane )
		{
			numPlanes = 1;
			planes[0] = groundTrace.normal;
		}
		else
		{
			numPlanes = 0;
		}

		planes[numPlanes] = velocity.normalized();
		numPlanes++;

		var numBumps = 4;
		var bumpCount = 0;
		while( bumpCount < numBumps )
		{
			if( velocity.x == 0 && velocity.y == 0 && velocity.z == 0.0 )
				return true;

			var end = CMath.vectorMA( getBodyOrigin(), moveTime, velocity );
			var rc = world.physics.shapeTestV( cast body.shape, getBodyOrigin(), end, body.group, body.mask );
			//if( rc.fraction > 0 && rc.fraction < 1)
			//	trace('z change=${z - end.z}; frac=${rc.fraction}');

			// @todo: Does this work??
			// IT DOES NOT
			/*
			if( rc.fraction < 0 )
			{
				velocity.z = 0;
				return true;
			}*/

			if( rc.fraction > 0 )
			{
				//trace('SetAbs: moveSlide frac>0 ${z} -> ${rc.position.z }');
				var newPos = CMath.vectorFrac( getBodyOrigin(), end, rc.fraction );
				setBodyOrigin( newPos.x, newPos.y, newPos.z  );
				if( z < -45 )
					trace("???");

			}

			if( rc.fraction == 1 )
				break;

			addTouchingEnt( cast rc.body.object );

			moveTime -= moveTime * rc.fraction;

			if( numPlanes >= maxClipPlanes )
			{
				velocity.set(0,0,0);
				return true;
			}

			//
			// if this is the same plane we hit before, nudge velocity
			// out along it, which fixes some epsilon issues with
			// non-axial planes
			//
			var i = 0;
			while( i < numPlanes )
			{
				if( rc.normal.dot( planes[i] ) > 0.99 )
				{
					velocity = rc.normal.add( velocity );
					break;
				}
				i++;
			}

			if( i < numPlanes )
				continue;

			planes[numPlanes] = rc.normal;
			numPlanes++;

			//
			// modify velocity so it parallels all of the clip planes
			//


			// find a plane that it enters
			for( i in 0 ... numPlanes )
			{
				var into = velocity.dot( planes[i] );

				if( into >= 0.1 )
					continue; // Move doesn't interact with this plane

				// See how hard we are hitting things
				if( -into > impactSpeed )
					impactSpeed = -into;

				// slide along the plane
				var clipVelocity = moveClipVelocity( velocity, planes[i], overClip );
				var endClipVelocity = moveClipVelocity( endVelocity, planes[i], overClip );

				for( j in 0 ... numPlanes )
				{
					if( j == i )
						continue;

					if( clipVelocity.dot( planes[j] ) > 0.1 )
						continue; // no interact

					// try clipping the move to the plane
					clipVelocity = moveClipVelocity( clipVelocity, planes[j], overClip );
					endClipVelocity = moveClipVelocity( endClipVelocity, planes[j], overClip );

					// see if it goes back into the first clip plane
					if( clipVelocity.dot( planes[i] ) >= 0 )
						continue;

					// slide the original velocity along the crease
					var dir = planes[i].cross( planes[j] );
					dir.normalize();
					var d = dir.dot(velocity);
					clipVelocity = dir.multiply( d );

					// See if there si a third plane the new move enters
					for( k in 0 ... numPlanes )
					{
						if( k == i || k == j )
							continue;

						if( clipVelocity.dot( planes[k] ) >= 0.1 )
							continue;

						// stop dead at trisection
						velocity.set(0,0,0);
						return true;
					}
				}

				// if we have fixed all interactions, try another move
				velocity.load( clipVelocity );
				endVelocity.load( endClipVelocity );
				break;
			}

			bumpCount++;

		}

		if( gravity )
			velocity.load( endVelocity );



		return bumpCount == 0;
	}

	function addTouchingEnt( e: Entity )
	{
		if( touchingEntities.indexOf( e ) == -1 )
			touchingEntities.push(e);
	}

	function moveFriction( delta: Float )
	{
		var vel = velocity;
		var vec = vel.clone();

		if( walking )
		{
			vec.z = 0;
		}

		var speed = vec.length();
		if( speed < 1 )
		{
			vel.x = 0;
			vel.y = 0;
			return;
		}

		var drop: Float = 0;

		if( walking )
		{
			var control: Float = speed < stopSpeed ? stopSpeed : speed;
			drop += control * frictionGround * delta;
		}

		// @todo flying friction

		var newSpeed = speed - drop;
		if( newSpeed < 0 )
			newSpeed = 0;

		newSpeed /= speed;

		vel.x *= newSpeed;
		vel.y *= newSpeed;
		vel.z *= newSpeed;
	}

	function moveClipVelocity( vin: Vector, normal: Vector, overBounce: Float )
	{
		var backoff = vin.dot(normal);

		if( backoff < 0 )
			backoff *= overBounce;
		else
			backoff /= overBounce;

		var out = new Vector(
			vin.x - ( normal.x * backoff ),
			vin.y - ( normal.y * backoff ),
			vin.z - ( normal.z * backoff )
		);

		return out;


	}

	function moveAccelerate( delta: Float, wishDir: Vector, wishSpeed: Float, accel: Float )
	{
		var currentSpeed = velocity.dot( wishDir );
		var addSpeed = wishSpeed - currentSpeed;

		DebugDraw.text('addSpeed=${addSpeed}');
		DebugDraw.text('wishSpeed=${addSpeed}');
		DebugDraw.text('accel=${addSpeed}');

		if( addSpeed <= 0 )
			return;

		var accelSpeed = accel * delta * wishSpeed;

		if( accelSpeed > addSpeed )
			accelSpeed = addSpeed;

		DebugDraw.text('accelSpeed=${accelSpeed}');

		velocity.x += accelSpeed * wishDir.x;
		velocity.y += accelSpeed * wishDir.y;
		velocity.z += accelSpeed * wishDir.z;

		DebugDraw.text('outVel=${velocity.x}, ${velocity.y}, ${velocity.z}');

	}

	function moveGroundTrace()
	{
		var origin = getBodyOrigin();
		var point = origin.clone();
		point.z -= 1;
		//origin.z +=

		// Trace from our current pos to our target pos
		// @todo: Consider aabb
		DebugDraw.colorAdd = 0x0000FF;
		var rc = world.physics.shapeTestV( cast body.shape, origin, point, body.group, body.mask );
		groundTrace = rc;

		DebugDraw.colorAdd = 0;


		// @todo: Consider trace may start inside solid

		// Trace didn't hit anything
		if( !rc.hit )
		{
			moveGroundMissed();
			groundPlane = false;
			walking = false;
			return;
		}



		// Check if being thrown off the ground
		if( velocity.z > 0 && velocity.dot( rc.normal ) > 10 )
		{
			trace("kickoff");

			animJump();

			groundEntity = null;
			groundPlane = false;
			walking = false;
			return;
		}

		// Slopes too steep are not ground
		if( rc.normal.z < minWalkNormal )
		{
			trace("Steep");

			groundEntity = null;
			groundPlane = false;
			walking = false;
			return;
		}

		groundPlane = true;
		walking = true;
		velocity.z = 0;

		if( groundEntity == null )
		{
			trace("Landed");
			moveCrashLand();
		}

		groundEntity = cast rc.body.object;

	}

	function moveGroundMissed()
	{
		// Did we just start falling?
		if( groundEntity != null )
		{
			trace("startFall");

			animFall();
		}

		groundEntity = null;
		walking = false;
		groundPlane = false;
	}

	function moveCrashLand()
	{
		animLanded();

		// If we want to take fall damage, do it here.
	}

	// Anim events
	function animJump() {}
	function animLanded() {}
	function animFall() {}
}
