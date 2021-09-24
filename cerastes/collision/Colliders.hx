package cerastes.collision;

import cerastes.collision.Collision.CCapsule;
import cerastes.collision.Collision.CAABB;
import cerastes.collision.Collision.CCircle;
import cerastes.collision.Collision.ColliderType;
import cerastes.collision.Collision.CollisionMask;
import cerastes.collision.Collision.CVector;
import game.GameState.CollisionGroup;


interface CollisionObject
{
	public var x(default, set) : Float;
	public var y(default, set) : Float;

	// Collision is just mask | type, so a bullet
	public var collisionMask: CollisionMask;	// Things that can interact with me
	public var collisionType: CollisionGroup;	// My interaction type
	public var colliders(default, null): haxe.ds.Vector<Collider>;


	public function handleCollision( other: CollisionObject ) : Void;
	public var collisionBounds(get, null) : CAABB;
}

interface Collider
{
	public var colliderType(default, null): ColliderType;		// What am I?

	/**
	 * What is "bugfix" argument you ask?
	 * Oh boy are you in for a treat
	 * so I added the global x/y floats, and suddenly the hashlink jit fucking EXPLODES. No idea why
	 * Spent hours tracking it down, turns out that fourth float just fucks everything up in hl somehow
	 * hlc works fine, just the VM is fucked.
	 *
	 * so why the bugfix float?
	 * WELL
	 * WOULD YOU BELIEVE
	 * ADDING A 5TH FLOAT UN-FUCKS THE VM?
	 **/
	public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float, bugfix: Float ): Bool;
}

@:structInit
class Circle implements Collider
{
	// CCircle
	public var p_x: Float;
	public var p_y: Float;
	public var r: Float;

	public final colliderType: ColliderType = Circle;

	public function new( c: CCircle )
	{
		// Until haxe supports inlining class fields we're stuck with this fuckery.
		this.p_x = c.p.x;
		this.p_y = c.p.y;
		this.r = c.r;
	}

	//public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float ): Bool
	public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float, bugfix: Float ): Bool
	{

		switch( other.colliderType )
		{
			case Circle:
				var c: Circle = cast other;
				return Collision.circleToCircle( {p: {x:p_x + x, y: p_y + y}, r: r}, {p: {x:c.p_x + otherX, y: c.p_y + otherY}, r: c.r} );
			case AABB:
				var a: AABB = cast other;
				return Collision.circleToAABB( {p: {x:p_x + x, y: p_y + x}, r: r}, { min:{ x: a.min_x + otherX, y: a.min_y + otherY }, max: {x: a.max_x + otherX, y: a.min_y + otherY} } );
			case Point:
				var p: Point = cast other;
				return Collision.circleToPoint( {p: {x:p_x + x, y: p_y + y}, r: r}, { x: p.x + otherX, y: p.y + otherY } );
			case Capsule:
				var c: Capsule = cast other;
				return Collision.circleToCapsule( {p: {x:p_x + x, y: p_y + y}, r: r}, { a: {x: c.a_x + otherX, y: c.a_y + otherY}, b:{ x: c.a_x + otherX, y: c.a_y + otherY }, r: c.r } );

			case Invalid:
				Utils.error('Unhandled collision between ${colliderType.toString()} and ${other.colliderType.toString()}');
				return false;
		}
	}

}

@:structInit
class AABB implements Collider
{
	// CAABB
	public var min_x: Float;
	public var min_y: Float;
	public var max_x: Float;
	public var max_y: Float;

	public final colliderType: ColliderType = AABB;

	public function new( a: CAABB )
	{
		// Until haxe supports inlining class fields we're stuck with this fuckery.
		min_x = a.min.x;
		min_y = a.min.y;
		max_x = a.max.x;
		max_y = a.max.y;
	}

	//public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float ): Bool
	public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float, bugfix: Float ): Bool
	{

		switch( other.colliderType )
		{
			case Circle:
				var o: Circle = cast other;
				return Collision.circleToAABB( {p: {x:o.p_x + otherX, y: o.p_y + otherY}, r: o.r}, { min:{ x:min_x + x, y:min_y + y }, max:{ x:max_x + x, y:max_y + y } } );

			case AABB:
				var a: AABB = cast other;
				return Collision.AABBtoAABB({ min:{ x:min_x + x, y:min_y + y }, max:{ x:max_x + x, y:max_y + y } }, { min:{ x:a.min_x + otherX, y:a.min_y + otherY }, max:{ x:a.max_x + otherX, y:a.max_y + otherY } } );

			case Point:
				var p: Point = cast other;
				return Collision.AABBToPoint({ min:{ x:min_x + x, y:min_y + y }, max:{ x:max_x + x, y:max_y + y } }, { x: p.x + otherX, y: p.y + otherY } );

			case Capsule:
				Utils.error("Need GJK to resolve AABB to Capsule!");
				return false;

			case Invalid:
				Utils.error('Unhandled collision between ${colliderType.toString()} and ${other.colliderType.toString()}');
				return false;

		}
	}
}

@:structInit
class Point implements Collider
{
	// CAABB
	public var x: Float;
	public var y: Float;

	public final colliderType: ColliderType = Point;

	public function new( p: CVector )
	{
		// Until haxe supports inlining class fields we're stuck with this fuckery.
		x = p.x;
		y = p.y;
	}

	//public function intersects( other: Collider, lx: Float, ly: Float, otherX: Float, otherY: Float ): Bool
	public function intersects( other: Collider, lx: Float, ly: Float, otherX: Float, otherY: Float, bugfix: Float): Bool
	{
		switch( other.colliderType )
		{
			case Circle:
				var o: Circle = cast other;
				return Collision.circleToPoint( {p: {x:o.p_x + otherX, y: o.p_y + otherY}, r: o.r}, {x:x + lx, y:y + ly} );

			case AABB:
				var a: AABB = cast other;
				return Collision.AABBToPoint({ min:{ x:a.min_x + otherX, y:a.min_y + otherY }, max:{ x:a.max_x + otherX, y:a.max_y + otherY } }, { x: x + lx, y: y + ly } );

			case Point:
				return false; // Points cannot collide with eachother, they're infinitely small.

			case Capsule:
				Utils.error("Not implemented.");
				return false;

			case Invalid:
				Utils.error('Unhandled collision between ${colliderType.toString()} and ${other.colliderType.toString()}');

		}

		Utils.error("Unhandled collision");

		return false;
	}

}

@:structInit
class Capsule implements Collider
{
	// CCapsule
	public var a_x: Float;
	public var a_y: Float;
	public var b_x: Float;
	public var b_y: Float;
	public var r: Float;

	public final colliderType: ColliderType = Capsule;

	public function new( c: CCapsule )
	{
		a_x = c.a.x;
		a_y = c.a.y;
		b_x = c.b.x;
		b_y = c.b.y;
		r = c.r;
	}

	//public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float ): Bool
	public function intersects( other: Collider, x: Float, y: Float, otherX: Float, otherY: Float , bugfix: Float): Bool
	{
		switch( other.colliderType )
		{
			case Circle:
				var o: Circle = cast other;
				return Collision.circleToCapsule( {p: {x:o.p_x + otherX, y: o.p_y + otherY}, r: r}, { a: {x: a_x + x, y: a_y + y}, b:{ x: a_x + x, y: a_y + y}, r: r } );

			default:
				Utils.error("Unhandled collision");

		}



		return false;
	}

}