package cerastes.c3d;

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
	public var MASK_ALL						= WORLD | NPC | PLAYER | PROP | TRIGGER;
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


class BulletWorld {

	var config : Native.DefaultCollisionConfiguration;
	var dispatch : Native.Dispatcher;
	var broad : Native.BroadphaseInterface;
	var pcache : Native.OverlappingPairCache;
	var solver : Native.ConstraintSolver;
	var inst : Native.DiscreteDynamicsWorld;
	var bodies : Array<BulletBody> = [];
	var constraints : Array<BulletConstraint> = [];
	public var parent : h3d.scene.Object;

	public function new( ?parent ) {
		this.parent = parent;
		config = new Native.DefaultCollisionConfiguration();
		dispatch = new Native.CollisionDispatcher(config);
		broad = new Native.DbvtBroadphase();
		pcache = broad.getOverlappingPairCache();
		solver = new Native.SequentialImpulseConstraintSolver();
		inst = new Native.DiscreteDynamicsWorld(dispatch, broad, solver, config);
	}

	public function setGravity( x : Float, y : Float, z : Float ) {
		inst.setGravity(new Native.Vector3(x, y, z));
	}

	public function stepSimulation( time : Float, iterations : Int ) {
		inst.stepSimulation(time, iterations);
	}

	public function checkCollisions()
	{
		var numManifolds = dispatch.getNumManifolds();
		for( i in 0 ... numManifolds )
		{
			var manifold = dispatch.getManifoldByIndexInternal( i );
			var bodyA = bodies[ manifold.getBody0().getUserIndex() ];
			var bodyB = bodies[ manifold.getBody1().getUserIndex() ];

			//DebugDraw.line( bodyA.position, bodyB.position, 0xFF0000 );
			var entA = Std.downcast( bodyA.object, QEntity );
			var entB = Std.downcast( bodyB.object, QEntity );

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
		for(idx in 0 ... bodies.length )
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
			@:privateAccess b.inst.setUserIndex( bodies.length );
			bodies.push(b);
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
		var idx = bodies.indexOf(b);
		if( idx == -1 )
			return;
		bodies[idx] = null;

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
