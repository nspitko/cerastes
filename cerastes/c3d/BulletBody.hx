package cerastes.c3d;
import h3d.col.ObjectCollider;
import bullet.*;

enum BulletBodyType {
	RigidBody;
	CollisionObject;
}

class BulletBody {

	static inline var ACTIVE_TAG = 1;
	static inline var DISABLE_DEACTIVATION = 4;
	static inline var DISABLE_SIMULATION = 5;

	var state : Native.MotionState;
	var inst : Native.CollisionObject;
	var _pos = new Point();
	var _vel = new Point();
	var _avel = new Point();
	var _q = new h3d.Quat();
	var _tmp = new Array<Float>();

	public var world(default,null) : BulletWorld;

	public var shape(default,null) : Native.CollisionShape;
	public var mass(default,null) : Float;
	public var position(get,never) : Point;
	public var velocity(get,set) : Point;
	public var angularVelocity(get,set) : Point;
	public var rotation(get,never) : h3d.Quat;
	public var object(default,set) : h3d.scene.Object;
	public var alwaysActive(default,set) = false;

	public var type(default,null): BulletBodyType;

	// HACK: Hold on to a handle to any used mesh so we GC it properly
	public var mesh: Native.StridingMeshInterface;

	public function new( shape : Native.CollisionShape, mass : Float, ?world : BulletWorld, ?type: BulletBodyType = RigidBody ) {

		this.type = type;
		state = new Native.DefaultMotionState();
		switch( type )
		{
			case RigidBody:
				var shapeInertia = new Native.Vector3();
				shape.calculateLocalInertia(1.,shapeInertia);
				var inertia = new Native.Vector3(shapeInertia.x() * mass, shapeInertia.y() * mass, shapeInertia.x() * mass);
				shapeInertia.delete();
				var inf = new Native.RigidBodyConstructionInfo(mass, state, shape, inertia);
				inst = new Native.RigidBody(inf);
				inf.delete();
				inertia.delete();

				this.mass = mass;

			case CollisionObject:
				inst = new Native.CollisionObject();
				inst.setCollisionShape( shape );
		}



		this.shape = shape;

		_tmp[6] = 0.;
		if( world != null ) addTo(world);
	}

	function set_alwaysActive(b) {
		inst.setActivationState(b ? DISABLE_DEACTIVATION : ACTIVE_TAG);
		return alwaysActive = b;
	}

	function set_object(o) {
		if( object != null ) object.remove();
		object = o;
		if( object != null && object.parent == null && world != null && world.parent != null ) world.parent.addChild(object);
		return o;
	}

	public function addTo( world : BulletWorld ) {
		if( this.world != null ) remove();
		@:privateAccess world.addBody(this);
	}

	public function remove() {
		if( world == null ) return;
		@:privateAccess world.removeBody(this);
	}

	public function setFriction( f ) {
		inst.setFriction(f);
	}

	public function setRollingFriction( f ) {
		inst.setRollingFriction(f);
	}

	public function addAxis( length = 1. ) {
		if( object == null ) throw "Missing object";
		var g = new h3d.scene.Graphics(object);
		g.lineStyle(1,0xFF0000);
		g.lineTo(length,0,0);
		g.lineStyle(1,0x00FF00);
		g.moveTo(0,0,0);
		g.lineTo(0,length,0);
		g.lineStyle(1,0x0000FF);
		g.moveTo(0,0,0);
		g.lineTo(0,0,length);
		g.material.setDefaultProps("ui");
	}

	public function setTransform( p : Point, ?q : h3d.Quat ) {

		var t: Native.Transform;
		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				t = inst.getCenterOfMassTransform();

			case CollisionObject:
				t = inst.getWorldTransform();
		}

		var v = new Native.Vector3(p.x, p.y, p.z);
		t.setOrigin(v);
		v.delete();
		if( q != null ) {
			var qv = new Native.Quaternion(q.x, q.y, q.z, q.w);
			t.setRotation(qv);
			qv.delete();
		}

		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				inst.setCenterOfMassTransform(t);

			case CollisionObject:
				inst.setWorldTransform(t);
		}

		inst.setWorldTransform(t);
		inst.activate();

	}

	public function resetVelocity() {
		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				inst.setAngularVelocity(zero);
				inst.setLinearVelocity(zero);
			case CollisionObject:
		}
		_vel.set(0,0,0);
		_avel.set(0,0,0);
		if( world != null ) @:privateAccess world.clearBodyMovement(this);
	}

	public function initObject() {

		throw "STUB?";
/*
		if( object != null ) return object.toMesh();
		var o = new h3d.scene.Mesh(shape.getPrimitive());
		object = o;
		return o;
		*/
	}

	public function delete() {
		inst.delete();
		state.delete();
	}

	public function loadPosFromObject() {
		setTransform(new Point(object.x, object.y, object.z), object.getRotationQuat());
	}

	function get_position() {

		var t: Native.Transform;

		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				t = inst.getCenterOfMassTransform();

			case CollisionObject:
				t = inst.getWorldTransform();
		}

		var p = t.getOrigin();
		_pos.assign(p);
		p.delete();
		return _pos;

	}

	function get_rotation() {

		var t: Native.Transform;

		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				t = inst.getCenterOfMassTransform();

			case CollisionObject:
				t = inst.getWorldTransform();
		}

		var q = t.getRotation();
		var qw : Native.QuadWord = q;
		_q.set(qw.x(), qw.y(), qw.z(), qw.w());
		q.delete();
		return _q;
	}

	function get_velocity() {
		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				var v = inst.getLinearVelocity();
				_vel.assign(v);
				return _vel;

			case CollisionObject:
				return new Point();
		}

	}

	public function applyImpulse(x: Float, y: Float, z: Float, relx: Float = 0, rely: Float = 0, relz: Float = 0)
	{
		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				var p = new Native.Vector3(x, y, z);
				var rp = new Native.Vector3(relx, rely, relz);
				inst.applyImpulse( p, rp );
				p.delete();
			case CollisionObject:
		}
	}

	function set_velocity(v) {

		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				if( v != _vel ) _vel.load(v);
				var p = new Native.Vector3(v.x, v.y, v.z);
				inst.setLinearVelocity(p);
				p.delete();
				return v;

			case CollisionObject:
				return v;
		}

	}

	function get_angularVelocity() {
		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				var v = inst.getAngularVelocity();
				_avel.assign(v);
				return _avel;

			case CollisionObject:
				return new Point();
		}
	}

	function set_angularVelocity(v) {


		switch(type )
		{
			case RigidBody:
				var inst: Native.RigidBody = cast inst;
				if( v != _avel ) _avel.load(v);
				var p = new Native.Vector3(v.x, v.y, v.z);
				inst.setAngularVelocity(p);
				p.delete();
				return v;

			case CollisionObject:
				return v;
		}
	}

	@:allow(bullet) static var zero = new Native.Vector3(0,0,0);

	/**
		Updated the linked object position and rotation based on physical simulation
	**/
	public function sync() {
		if( object == null ) return;
		var pos = position;
		object.x = pos.x;
		object.y = pos.y;
		object.z = pos.z;
		var q = rotation;
		object.getRotationQuat().load(q); // don't share reference
	}

}
