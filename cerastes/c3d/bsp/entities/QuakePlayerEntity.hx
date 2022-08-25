package cerastes.q3bsp.entities;

import cerastes.q3bsp.BSPMap.BSPTraceResult;
import format.pex.Data.ValueWithVariance;
import hxd.poly2tri.VisiblePolygon;
import h3d.Vector;
import cerastes.camera.FPSCamera;
import h3d.scene.Object;
import hxd.Math;

/**
 * Simple player class. FPS controls. Owns the camera.
 */


 typedef UserCmd = {
	var ?forwardMove: Int;
	var ?rightMove: Int;
	var ?upMove: Int;
};



class QuakePlayerEntity extends BSPEntity
{
	// Camera
	var cameraFront:Vector;
	var cameraDirection:Vector;

	var cameraUp:Vector;
	var cameraRight:Vector;

	var yaw:Float;
	var pitch:Float;

	var lastX:Float;
	var lastY:Float;

	var sensitivity = 0.5;


	var scene: Scene;
	//
	var firstMouse = true;

	// Movement
	var userCmd : UserCmd = {};
	var isWalking: Bool;
	var hasGroundPlane: Bool;

	var impactSpeed: Float = 0;


	var groundTrace: BSPTraceResult;



	public function new( map: BSPMap, ?parent: Object )
	{
		super(map, parent);

		scene = Main.currentScene;

		// Init

		speed = 220.;


		this.cameraFront = new Vector(0.0, -1.0, 0.0);
		this.cameraDirection = position.sub(this.cameraFront);

		this.cameraDirection.normalize();

		this.cameraUp = new Vector(0.0, 0.0, 1.0);

		this.cameraRight = this.cameraUp.cross(this.cameraDirection);
		this.cameraRight.normalize();

		scene.s3d.camera.pos = position;
		scene.s3d.camera.up = this.cameraUp;
		scene.s3d.camera.target = position.add(this.cameraFront);


		//cam.cameraPos.set(120, 120, 40);
		setPosition(120, 120, 40);
	}

	public function tick(delta:Float)
	{
		tickInput( delta );
		tickCamera( delta );
		pmGroundTrace();

		pmWalkMove( delta );
	}

	function tickInput(delta: Float)
	{
		userCmd.forwardMove = 0;
		userCmd.rightMove = 0;
		userCmd.upMove = 0;

		if (hxd.Key.isDown(hxd.Key.W))
		{
			userCmd.forwardMove = 127;
		}
		if (hxd.Key.isDown(hxd.Key.S)) {
			userCmd.forwardMove = -127;
		}
		if (hxd.Key.isDown(hxd.Key.A)) {
			userCmd.rightMove = -127;
		}
		if (hxd.Key.isDown(hxd.Key.D)) {
			userCmd.rightMove = 127;
		}

	}


	function cmdScale( )
	{
		var max: Int;
		var total: Float;
		var scale: Float;

		max = cast Math.abs( userCmd.forwardMove );

		if( Math.abs( userCmd.rightMove ) > max )
			max = cast Math.abs( userCmd.rightMove );

		if( Math.abs( userCmd.upMove ) > max )
			max = cast Math.abs( userCmd.upMove );

		if( max == 0 )
			return 0.;

		total = Math.sqrt(	userCmd.forwardMove * userCmd.forwardMove +
							userCmd.rightMove * userCmd.rightMove +
							userCmd.upMove * userCmd.upMove );

		scale = speed * max / (127 * total );

		return scale;

	}

	function pmClipVelocity( vecIn: Vector, normal: Vector, vecOut: Vector, ?overBounce: Float = 1.001 )
	{
		var backOff: Float;

		backOff = vecIn.dot3( normal );
		if( backOff < 0 )
			backOff *= overBounce;
		else
			backOff /= overBounce;

		vecOut.x = vecIn.x - ( normal.x * backOff );
		vecOut.y = vecIn.y - ( normal.y * backOff );
		vecOut.z = vecIn.z - ( normal.z * backOff );
	}

	function pmWalkMove(delta: Float )
	{
		var wishVel: Vector;
		var fMove: Float;
		var sMove: Float;
		var wishDir: Vector;
		var wishSpeed: Float;
		var scale: Float;
		var accelerate: Float;
		var vel: Float;

		// @todo: Check water

		// @todo check jump

		pmFriction(delta);

		fMove = userCmd.forwardMove;
		sMove = userCmd.rightMove;

		scale = cmdScale();

		cameraFront.z = 0;
		cameraRight.z = 0;

		var groundNormal = isWalking ? Vector.fromArray( groundTrace.plane.normal.toArray() ) : new Vector(0,0,0);

		pmClipVelocity(cameraFront, groundNormal, cameraFront );
		pmClipVelocity(cameraRight, groundNormal, cameraRight );

		cameraFront.normalize();
		cameraRight.normalize();

		wishVel = new Vector(
			cameraFront.x * fMove + cameraRight.x * sMove,
			cameraFront.y * fMove + cameraRight.y * sMove,
			cameraFront.z * fMove + cameraRight.z * sMove
		);

		wishDir = wishVel.clone();

		wishSpeed = wishDir.length();
		wishSpeed *= scale;

		// @todo clamp speed slower if ducking

		// @todo clamp speed slower if wasding or walking on the bottom

		// @todo when a player gets hit, they temporarily lose full control
		// which allowes them to be moved a bit

		pmAccelerate( delta, wishDir, wishSpeed, 10. ); // pm_accelerate = 10

		if( ( groundTrace.surfaceFlags & 0x2 ) != 0 /* SURF_SLICK OR TIME_KNOCKBACK*/ )
		{
			velocity.z -= 800 * delta; // 800 -> Gravity
		}

		vel = velocity.length();

		// Slide along the ground plane
		pmClipVelocity( velocity, groundNormal, velocity );

		// DOn't decrease velocity when going up/down  a slope
		velocity.normalize();
		velocity.x *= vel;
		velocity.y *= vel;
		velocity.z *= vel;

		// DOn't do anything if standing still

		if( velocity.x == 0 && velocity.y == 0 )
			return;

		pmStepSlideMove( delta, false );


	}

	inline function vectorMA(vec1: Vector, scale: Float, vec2: Vector)
	{
		return new Vector(
			vec1.x + scale * vec2.x,
			vec1.y + scale * vec2.y,
			vec1.z + scale * vec2.z

		);
	}

	function pmStepSlideMove( delta: Float, gravity: Bool )
	{
		var startO: Vector, startV: Vector;
		var downO: Vector, downV: Vector;
		var traceResult: BSPTraceResult;
		var up: Vector, down: Vector;
		var stepSize: Float;

		startO = position.clone();
		startV = velocity.clone();

		if( pmSlideMove( delta, gravity ) == false ) // ????????? returns bool?!?
		{
			return; // We got exactly where we wanted on the first try
		}

		down = startO.clone();
		down.z -= 18; // STEPSIZE

		var tTrace = map.traceBox(startO, down, collisionMins, collisionMaxs );
		up = new Vector(0,0,1);

		// never step up when you still have velocity
		var groundNormal = Vector.fromArray( tTrace.plane.normal.toArray() );
		if( velocity.z > 0 && ( tTrace.fraction == 1 || groundNormal.dot3(up) < 0.7 ) )
		{
			return;
		}

		downO = position.clone();
		downV = velocity.clone();
		up = startO.clone();

		up.z += 18; // STEPSIZE

		// test the player position if they were a stepheight higher

		tTrace = map.traceBox( startO, up, collisionMins, collisionMaxs );
		if( tTrace.allSolid )
		{
			return; // Can't step up
		}

		stepSize = tTrace.endPos.z - startO.z;
		// try to slidemove from this position
		position = tTrace.endPos.clone();
		velocity = startV.clone();

		pmSlideMove( delta, gravity );

		// push down the final amount
		down = position.clone();
		down.z -= 18; // STEPSIZE
		tTrace = map.traceBox(position, down, collisionMins, collisionMaxs);
		if( !tTrace.allSolid )
		{
			position = tTrace.endPos;
		}

		if( tTrace.fraction < 1 )
		{
			var groundNormal = Vector.fromArray( tTrace.plane.normal.toArray() );
			pmClipVelocity( velocity, groundNormal, velocity);
		}



	}



	function pmSlideMove( delta: Float, gravity: Bool )
	{
		var numBumps: Int;
		var dir: Vector;
		var d: Float;
		var numPlanes: Int;
		var planes = new haxe.ds.Vector<Vector>(5); // MAX_CLIP_PLANES
		var primalVelocity: Vector;
		var clipVelocity: Vector = new Vector();
		var traceResult: BSPTraceResult;
		var end: Vector;
		var timeLeft: Float;
		var into: Float;
		var endVelocity: Vector = new Vector();
		var endClipVelocity: Vector = new Vector();

		numBumps = 4;

		var groundNormal = hasGroundPlane ? Vector.fromArray( groundTrace.plane.normal.toArray() ) : new Vector(0,0,0);

		primalVelocity = velocity.clone();
		if( gravity )
		{
			endVelocity = velocity.clone();
			endVelocity.z -= 800 * delta;

			velocity.z = ( velocity.z + endVelocity.z ) * 0.5;
			primalVelocity.z = endVelocity.z;


			if( hasGroundPlane )
			{
				// Slide along ground plane
				pmClipVelocity(velocity, groundNormal, velocity );
			}
		}

		timeLeft = delta;

		// never turn against the ground plane
		if( hasGroundPlane )
		{
			numPlanes = 1;
			planes[0] = groundNormal;
		}
		else
		{
			numPlanes = 0;
		}


		planes[numPlanes] = velocity.getNormalized();
		numPlanes++;

		var bumpCount = 0;

		while( bumpCount < numBumps )
		{
			end = vectorMA(position, timeLeft, velocity);

			var testTrace = map.traceBox( position, collisionMins, collisionMaxs, end );

			if( testTrace.allSolid )
			{
				// Entity is completely trapped in another solid
				velocity.z = 0; // Don't build up falling damage, but allow sideways accel
				return true;
			}

			if( testTrace.fraction > 0 )
			{
				// actually covered some distance
				position = testTrace.endPos;
			}

			if( testTrace.fraction == 1 )
			{
				// Moved the entire distance
				bumpCount++;
				break;
			}

			// save entity for contact
			// @TODO

			timeLeft -= timeLeft * testTrace.fraction;

			if( numPlanes >= 5 ) // MAC_CLIP_PLANES
			{
				// This shouldn't happen
				Utils.warning("This shouldn't happen");
				velocity.set(0,0,0);
				return true;
			}

			// If this is the same plane we hit before, nudge velocity out along it, which fixes
			// some epsilon issues with non-axial planes
			var i = 0;
			while( i < numPlanes )
			{
				var traceNormal = Vector.fromArray( testTrace.plane.normal.toArray() );
				if( traceNormal.dot3( planes[i] ) > 0.99 )
				{
					velocity.add( traceNormal );
					break;
				}
				i++;
			}
			if( i < numPlanes )
			{
				bumpCount++;
				continue;
			}

			planes[numPlanes] = groundNormal.clone();
			numPlanes++;

			//
			// Modify velocity so it parallels all of the clip planes
			//

			for( i in 0 ... numPlanes )
			{
				into = velocity.dot3( planes[i] );
				if( into >= 0.1 )
					continue; // move doesn't interact with the plane

				// See how hard we are hitting things
				if( -into > impactSpeed )
					impactSpeed = -into;

				// Slide along the plane
				pmClipVelocity( velocity, planes[i], clipVelocity );

				// Slide along the plane
				pmClipVelocity( endVelocity, planes[i], endClipVelocity );

				// See if there is a second plane that the new move enters

				var j = 0;
				while( j < numPlanes )
				{
					if( j == i )
					{
						j++;
						continue;
					}

					if( clipVelocity.dot3( planes[j] ) >= 0.1 )
					{
						j++;
						continue; // Move doesn't interact with the plane
					}

					// Try clipping the move to the plane
					pmClipVelocity( clipVelocity, planes[j], clipVelocity );
					pmClipVelocity( endClipVelocity, planes[j], endClipVelocity );

					// See if it goes back into the first clip plane
					if( clipVelocity.dot3( planes[i] ) >= 0 )
					{
						j++;
						continue;
					}

					// Slide the original velocity along the crease
					dir = planes[i].cross(planes[j]);
					dir.normalize();
					d = dir.dot3( velocity );

					clipVelocity = dir.clone();
					clipVelocity.scale3( d );

					d = dir.dot3( endVelocity ); // @bugbug possible here? Refactored some seemingly unncessary duplication??
					endClipVelocity = dir.clone();
					endClipVelocity.scale3( d );

					// See if there is a third plane the new move enters
					var k = 0;
					while( k < numPlanes )
					{
						if( k == i || k == j )
						{	k++;
							continue;
						}

						if( clipVelocity.dot3(planes[k]) >= 0.1 )
						{
							k++;
							continue; // Does not interact with the plane
						}

						// Stop deat at a triple plane interaction
						velocity.set(0,0,0);
						return true;

					}

					j++;
				}

				// If we have fixed all interactions, try another move

				velocity = clipVelocity.clone();
				endClipVelocity = endVelocity.clone();
				break;
			}


			bumpCount++;
		}

		if( gravity )
		{
			velocity = endVelocity.clone();
		}

		// @todo
		// Don't change velocity if on a timer (FIXME: is this correct?)



		return bumpCount != 0;
	}

	function pmAccelerate( delta: Float, wishDir: Vector, wishSpeed: Float, accel: Float )
	{
		// Q2 style
		var addSpeed: Float, accelSpeed: Float, currentSpeed: Float;

		currentSpeed = velocity.dot3( wishDir );
		addSpeed = wishSpeed - currentSpeed;
		if( addSpeed <= 0 )
			return;

		accelSpeed = accel * delta * wishSpeed;

		if( accelSpeed > addSpeed )
			accelSpeed = addSpeed;

		velocity.x += accelSpeed * wishDir.x;
		velocity.y += accelSpeed * wishDir.y;
		velocity.z += accelSpeed * wishDir.z;
	}

	function pmGroundTrace()
	{
		var point: Vector;

		point = new Vector(
			x, y, z - 0.25
		);

		groundTrace = map.traceBox( position, point, collisionMins, collisionMaxs );

		// @todo correctAllSolid
		if( groundTrace.fraction == 1. )
		{
			pmGroundTraceMissed();
			isWalking = false; // @todo
			hasGroundPlane = false;
			return;
		}

		// Check if gettingthrown off the ground
		if( velocity.z > 0 && velocity.dot3( Vector.fromArray( groundTrace.plane.normal.toArray() ) ) > 10 )
		{
			Utils.info("Kickoff!");
			isWalking = false;
			hasGroundPlane = false;
			return;
		}

		// Slopes that are too steep will not be considered on ground
		if( groundTrace.plane.normal[2] < 0.7)
		{
			// FIXME: if they can't slide down the slope, let them
			isWalking = false;
			hasGroundPlane = false;

			return;
		}


		hasGroundPlane = true;
		isWalking = true;

		// @todo hitting solid ground will end a waterjump

		//@todo ground entity shenanigans

	}

	function pmGroundTraceMissed()
	{
		// @todo check entity
		{
			// @todo additional trace down 64 units to handle jump state anim; not important?
		}
		hasGroundPlane = false;
		isWalking = false;
	}



	function pmFriction(delta: Float)
	{
		var vec: Vector;
		var vel: Vector;
		var speed: Float, newSpeed: Float, control: Float;
		var drop: Float;

		vel = velocity;

		vec = vel.clone();

		// Ignore slope movement
		if( isWalking )
			vec.z = 0;

		speed = vec.length();
		if( speed < 1 )
		{
			vel.x = 0;
			vel.y = 0; // Allow sinking underwater
			// FIXME: Still have z friction underwater?
			return;
		}

		drop = 0;

		// apply ground friction
		if( true ) // pm->waterlevel <= 1
		{
			if( isWalking ) // && !(pml.groundTrace.surfaceFlags & SURF_SLICK )
			{
				// if ( ! (pm->ps->pm_flags & PMF_TIME_KNOCKBACK) ) { // If getting knocked back, no friction
				control = speed < 100 ? 100 : speed; // pm_stopspeed = 100;
				drop += control * 6 * delta; // pm_friction = 6
			}
		}

		// @todo apply water friction even if just wading
		// @todo apply flying friction
		// @todo spectator friction

		newSpeed = speed - drop;
		if( newSpeed < 0 )
			newSpeed = 0;

		newSpeed /= speed;

		vel.x = vel.x * newSpeed;
		vel.y = vel.y * newSpeed;
		vel.z = vel.z * newSpeed;


	}

	function tickCamera( dt: Float )
	{
			// Camera movement
			var cameraSpeed = speed * dt;



			// Look around

			var xpos = scene.s2d.mouseX;
			var ypos = scene.s2d.mouseY;
			if (firstMouse) {
				lastX = xpos;
				lastY = ypos;
				firstMouse = false;
			}
			var xoffset = xpos - lastX;
			var yoffset = lastY - ypos;
			lastX = xpos;
			lastY = ypos;

			xoffset *= sensitivity;
			yoffset *= sensitivity;

			yaw += xoffset;
			pitch += yoffset;

			if (pitch > 89.0) {
				pitch = 89.0;
			};
			if (pitch < -89.0) {
				pitch = -89.0;
			};

			var newDir = new Vector();
			newDir.x = Math.cos(Math.degToRad(yaw)) * Math.cos(Math.degToRad(pitch));
			newDir.y = Math.sin(Math.degToRad(yaw)) * Math.cos(Math.degToRad(pitch));
			newDir.z = Math.sin(Math.degToRad(pitch));
			newDir.normalize();
			this.cameraFront = newDir;

			scene.s3d.camera.pos = position;
			scene.s3d.camera.up = this.cameraUp;
			scene.s3d.camera.target = position.add(this.cameraFront);
	}
}