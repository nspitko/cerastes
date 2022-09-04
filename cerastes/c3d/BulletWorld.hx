package cerastes.c3d;

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
	public var body: BulletBody;
	public var position: Vector;
	public var normal: Vector;
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

	public function rayTest( from: bullet.Native.Vector3, to: bullet.Native.Vector3, group: BulletCollisionFilterGroup, mask: BulletCollisionFilterMask ): BulletRayTestResult
	{
		var result = new bullet.Native.ClosestRayResultCallback(from, to);

		result.m_collisionFilterGroup = group;
		result.m_collisionFilterMask = mask;

		inst.rayTest(from, to, result );


		if( result.hasHit() )
		{
			var body = getBodyOwner( result.m_collisionObject );

			var ret: BulletRayTestResult = {
				body: body,
				normal: new Vector( result.m_hitNormalWorld.x(), result.m_hitNormalWorld.y(), result.m_hitNormalWorld.z() ),
				position: new Vector( result.m_hitPointWorld.x(), result.m_hitPointWorld.y(), result.m_hitPointWorld.z() )
			};

			result.delete();

			return ret;
		}
		result.delete();

		return null;
	}

	public function setGravity( x : Float, y : Float, z : Float ) {
		inst.setGravity(new Native.Vector3(x, y, z));
	}

	public function stepSimulation( time : Float, iterations : Int ) {
		inst.stepSimulation(time, iterations);
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
