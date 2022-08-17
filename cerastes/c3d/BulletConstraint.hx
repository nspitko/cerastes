package cerastes.c3d;
import bullet.*;


class BulletConstraint {

	var cst : Native.TypedConstraint;
	public var world(default,null) : BulletWorld;
	public var disableCollisionsBetweenLinkedBodies(default, set) : Bool = false;

	function new( cst, ?world : BulletWorld ) {
		this.cst = cst;
		if( world != null ) addTo(world);
	}

	public function addTo( world : BulletWorld ) {
		if( this.world != null ) remove();
		@:privateAccess world.addConstraint(this);
	}

	public function remove() {
		if( world == null ) return;
		@:privateAccess world.removeConstraint(this);
	}

	public function delete() {
		cst.delete();
	}

	function set_disableCollisionsBetweenLinkedBodies(b) {
		if( disableCollisionsBetweenLinkedBodies == b ) return b;
		disableCollisionsBetweenLinkedBodies = b;
		var w = world;
		if( w != null ) {
			remove();
			addTo(w);
		}
		return b;
	}

}
