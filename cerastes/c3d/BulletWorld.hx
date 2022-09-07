package cerastes.c3d;

import cerastes.macros.Metrics;
import h3d.Vector;
import h3d.col.Point;
import bullet.*;

@:enum
abstract BulletCollisionFilterGroup(Int) from Int to Int
{
	public var WORLD		= (1 << 0 );
	public var NPC			= (1 << 1 );
	public var PLAYER		= (1 << 2 );
	public var PROP			= (1 << 3 );
	public var TRIGGER		= (1 << 4 );
}

@:enum
abstract BulletCollisionFilterMask(Int) from Int to Int
{
	public var MASK_ALL						= 0xFFFF;
	public var MASK_WORLD					= NPC | PLAYER | PROP; // I'm the world, I collide with things that are not the world
	public var MASK_PLAYER					= WORLD | NPC | PROP | TRIGGER;
	public var MASK_NPC						= WORLD | PLAYER | TRIGGER; // NPCs ignore props for pathings reasons that may exist some day
	public var MASK_TRIGGER					= PLAYER | NPC | PROP; // triggers look for point entities only
}

@:structInit
class BulletContactManifold
{
	public var appliedImpulse: Float;
	public var distance: Float;
	public var localPointSelf: bullet.Native.Vector3;
	public var localPointOther: bullet.Native.Vector3;
	public var worldPointSelf: bullet.Native.Vector3;
	public var worldPointOther: bullet.Native.Vector3;
	public var normalOnWorld: bullet.Native.Vector3;

}

@:structInit
class BulletRayTestResult
{
	public var hit: Bool;
	public var body: BulletBody;
	public var position: Vector;
	public var normal: Vector;
	public var fraction: Float;
}


class BulletWorld {

	var config : Native.DefaultCollisionConfiguration;
	var dispatch : Native.Dispatcher;
	var broad : Native.BroadphaseInterface;
	var pcache : Native.OverlappingPairCache;
	var solver : Native.ConstraintSolver;
	var inst : Native.DiscreteDynamicsWorld;
	var bodies : Map<Int,BulletBody> = [];
	var constraints : Array<BulletConstraint> = [];
	public var parent : h3d.scene.Object;

	var bodyIdx = 0;

	public function new( ?parent ) {
		this.parent = parent;
		config = new Native.DefaultCollisionConfiguration();
		dispatch = new Native.CollisionDispatcher(config);
		broad = new Native.DbvtBroadphase();
		pcache = broad.getOverlappingPairCache();
		solver = new Native.SequentialImpulseConstraintSolver();
		inst = new Native.DiscreteDynamicsWorld(dispatch, broad, solver, config);
	}

	public inline function rayTestP( from: Point, to: Point, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{
		var f = new bullet.Native.Vector3( from.x, from.y, from.z );
		var t = new bullet.Native.Vector3( to.x, to.y, to.z );
		var r = rayTest( f, t, group, mask );
		f.delete();
		t.delete();
		return r;
	}

	public inline function rayTestV( from: Vector, to: Vector, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{
		var f = new bullet.Native.Vector3( from.x, from.y, from.z );
		var t = new bullet.Native.Vector3( to.x, to.y, to.z );
		var r = rayTest( f, t, group, mask );
		f.delete();
		t.delete();
		return r;
	}

	public inline function rayTestMinV( from: Vector, to: Vector, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{
		var f = new bullet.Native.Vector3( from.x, from.y, from.z );
		var t = new bullet.Native.Vector3( to.x, to.y, to.z );
		var r = rayTest( f, t, group, mask );
		f.delete();
		t.delete();
		return r;
	}

	public function rayTest( from: bullet.Native.Vector3, to: bullet.Native.Vector3, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{
		Metrics.begin("rayTest");
		var result = new bullet.Native.ClosestRayResultCallback(from, to);

		result.m_collisionFilterGroup = group;
		result.m_collisionFilterMask = mask;

		inst.rayTest(from, to, result );

		var body = null;

		if( result.hasHit() )
		{
			body = getBodyOwner( result.m_collisionObject );
		}

		var ret: BulletRayTestResult = {
			hit: result.hasHit(),
			body: body,
			normal: result.hasHit() ? new Vector( result.m_hitNormalWorld.x(), result.m_hitNormalWorld.y(), result.m_hitNormalWorld.z() )  : new Vector( 0, 0, 1 ),
			position: result.hasHit() ? new Vector( result.m_hitPointWorld.x(), result.m_hitPointWorld.y(), result.m_hitPointWorld.z() )  : new Vector( to.x(), to.y(), to.z() ),
			fraction: result.m_closestHitFraction
		};

		if( true )
		{
			var col = result.hasHit() ? 0x00FF00 : 0xFF0000;
			DebugDraw.lineV( new Vector( from.x(), from.y(), from.z() ), ret.position, col );
		}

		result.delete();

		Metrics.end();
		return ret;
	}

	public inline function shapeTestV( shape: bullet.Native.ConvexShape, from: Vector, to: Vector, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{

		var f = new bullet.Native.Vector3( from.x, from.y, from.z );
		var t = new bullet.Native.Vector3( to.x, to.y, to.z );

		var ft = new bullet.Native.Transform();
		var tt = new bullet.Native.Transform();
		ft.setIdentity();
		tt.setIdentity();
		ft.setOrigin( f );
		tt.setOrigin( t );

		var r = shapeTest( shape, ft, tt, group, mask );
		f.delete();
		t.delete();
		ft.delete();
		tt.delete();

		if( true )
		{
			var amin = new bullet.Native.Vector3(0,0,0);
			var amax = new bullet.Native.Vector3(0,0,0);
			var t = new bullet.Native.Transform();
			t.setIdentity();

			shape.getAabb(t,amin,amax);

			var col = r.hit ? 0x00FF00 : 0xFF0000;
			var pos = CMath.vectorFrac( from, to, r.fraction );
			DebugDraw.box( pos.toPoint(), new Point( amax.x() - amin.x(), amax.y() - amin.y(), amax.z() - amin.z()), col );
		}

		return r;
	}

	public function shapeTest( shape: bullet.Native.ConvexShape, from: bullet.Native.Transform, to: bullet.Native.Transform, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{
		Metrics.begin("shapeTest");
		var s = Math.cos( 45 * (Math.PI / 180 ) );
		var result = new bullet.Native.ClosestConvexResultCallback(
			new bullet.Native.Vector3(0,0,-1),
			new bullet.Native.Vector3(s,s,s)
		);

		result.m_collisionFilterGroup = group;
		result.m_collisionFilterMask = mask;

		inst.convexSweepTest(shape, from, to, result, 0.5 );

		var body = null;

		if( result.hasHit() )
		{
			body = getBodyOwner( result.m_hitCollisionObject );
		}


		var ret: BulletRayTestResult = {
			hit: result.hasHit(),
			body: body,
			normal: result.hasHit() ? new Vector( result.m_hitNormalWorld.x(), result.m_hitNormalWorld.y(), result.m_hitNormalWorld.z() )  : new Vector( 0, 0, 1 ),
			position: result.hasHit() ? new Vector( result.m_hitPointWorld.x(), result.m_hitPointWorld.y(), result.m_hitPointWorld.z() )  : new Vector( to.getOrigin().x(), to.getOrigin().y(), to.getOrigin().z() ),
			fraction: result.m_closestHitFraction
		};

		result.delete();
		Metrics.end();

		return ret;
	}

	public function setGravity( x : Float, y : Float, z : Float ) {
		inst.setGravity(new Native.Vector3(x, y, z));
	}

	public function stepSimulation( time : Float, iterations : Int ) {
		Metrics.begin("stepSimulation");
		inst.stepSimulation(time, iterations);
		Metrics.end();
	}

	inline function getBodyOwner( body: bullet.Native.CollisionObject )
	{
		return bodies.get( body.getUserIndex() );
	}

	public function checkCollisions()
	{
		var numManifolds = dispatch.getNumManifolds();
		for( i in 0 ... numManifolds )
		{
			var manifold = dispatch.getManifoldByIndexInternal( i );
			var bodyA = getBodyOwner( manifold.getBody0() );
			var bodyB = getBodyOwner( manifold.getBody1() );

			//DebugDraw.line( bodyA.position, bodyB.position, 0xFF0000 );
			var entA = Std.downcast( bodyA.object, Entity );
			var entB = Std.downcast( bodyB.object, Entity );

			if( entA != null )
				@:privateAccess entA.collide(manifold, bodyA, entB, bodyB);

			if( entB != null )
				@:privateAccess entB.collide(manifold, bodyB, entA, bodyA );

		}


	}

	public function sync() {
		for( b in bodies )
			if( b.object != null )
				b.sync();
	}

	function clearBodyMovement( b : BulletBody ) {
		pcache.cleanProxyFromPairs(@:privateAccess b.inst.getBroadphaseHandle(),dispatch);
	}

	public function addBody( b : BulletBody, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask )
	{
		if( b.world != null ) throw "Body already in world";

		@:privateAccess b.group = group;
		@:privateAccess b.mask = mask;

		var found = false;
		for(idx in 0 ... bodyIdx )
		{
			if( bodies[idx] == null )
			{
				bodies[idx] = b;
				@:privateAccess b.inst.setUserIndex( idx );
				found = true;
				break;
			}
		}

		if( !found )
		{
			bodyIdx++;
			@:privateAccess b.inst.setUserIndex( bodyIdx );
			bodies[bodyIdx] = b;
		}

		@:privateAccess b.world = this;
		switch( b.type )
		{
			case RigidBody:
				inst.addRigidBody(@:privateAccess cast b.inst,group,mask);
			case CollisionObject | GhostObject | PairCachingGhostObject:
				inst.addCollisionObject( @:privateAccess cast b.inst,group,mask);

		}

		if( b.object != null && parent != null && b.object.parent == null )
			parent.addChild(b.object);

	}

	function removeBody( b : BulletBody )
	{
		// Never remove items from the array, just null them out so we can retain indices
		bodies.remove(@:privateAccess b.inst.getUserIndex() );

		@:privateAccess b.world = null;

		inst.removeRigidBody(@:privateAccess cast b.inst);
		switch( b.type )
		{
			case RigidBody:
				inst.removeRigidBody(@:privateAccess cast b.inst);
			case CollisionObject | GhostObject | PairCachingGhostObject:
				inst.removeCollisionObject( @:privateAccess cast b.inst);
		}

		if( b.object != null && b.object.parent == parent ) b.object.remove();
	}

	function addConstraint( c : BulletConstraint ) {
		if( c.world != null ) throw "Constraint already in world";
		constraints.push(c);
		@:privateAccess c.world = this;
		inst.addConstraint(@:privateAccess c.cst, c.disableCollisionsBetweenLinkedBodies);
	}

	function removeConstraint( c : BulletConstraint ) {
		if( !constraints.remove(c) ) return;
		@:privateAccess c.world = null;
		inst.removeConstraint(@:privateAccess c.cst);
	}

}
