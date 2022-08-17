package cerastes.c3d;

import bullet.*;

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

	public function sync() {
		for( b in bodies )
			if( b.object != null )
				b.sync();
	}

	function clearBodyMovement( b : BulletBody ) {
		pcache.cleanProxyFromPairs(@:privateAccess b.inst.getBroadphaseHandle(),dispatch);
	}

	function addBody( b : BulletBody ) {
		if( b.world != null ) throw "Body already in world";
		bodies.push(b);
		@:privateAccess b.world = this;
		switch( b.type )
		{
			case RigidBody:
				inst.addRigidBody(@:privateAccess cast b.inst,1,1);
			case CollisionObject:
				inst.addCollisionObject( @:privateAccess cast b.inst, 1, 1);

		}

		if( b.object != null && parent != null && b.object.parent == null ) parent.addChild(b.object);
	}

	function removeBody( b : BulletBody ) {
		if( !bodies.remove(b) ) return;
		@:privateAccess b.world = null;

		inst.removeRigidBody(@:privateAccess cast b.inst);
		switch( b.type )
		{
			case RigidBody:
				inst.removeRigidBody(@:privateAccess cast b.inst);
			case CollisionObject:
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
