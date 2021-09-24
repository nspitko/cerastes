package cerastes.collision;

import game.GameState.CollisionGroup;

// 2d vector
@:structInit
class CVector
{
	public var x: Float;
	public var y: Float;

	 public inline function new(x: Float, y: Float )
	{
		this.x = x;
		this.y = y;
	}

	// ============================================================================
	// Vector Math
	// ============================================================================
	 public inline function sub(b: CVector ): CVector		{ return { x: x - b.x, y: y - b.y }; }
	 public inline function add(b: CVector ): CVector		{ return { x: x + b.x, y: y + b.y }; }
	 public inline function dot(b: CVector ): Float		{ return x * b.x + y * b.y; }
	 public inline function mulVS(b: Float ): CVector		{ return { x: x * b, y: y * b }; }
	 public inline function mulVV(b: CVector ): CVector	{ return { x: x * b.x, y: y * b.y }; }
	 public inline function div(b: Float ): CVector		{ return this.mulVS(1.0 / b ); }
	 public inline function maxV( b: CVector ): CVector	{ return {x: Math.max( x, b.x ), y: Math.max(y, b.y) }; }
	 public inline function minV( b: CVector ): CVector	{ return {x: Math.min( x, b.x ), y: Math.min(y, b.y) }; }
	 public inline function clampV( lo: CVector, hi: CVector ): CVector	{ return { lo.maxV( this.minV( hi ) ); } }

	 public inline function len(): Float					{ return { Math.sqrt( dot(this) ); } }
	 public inline function norm(): CVector				{ return { div( len() ); } }

}

// 2d rotation composed of cos/sin pair
@:structInit
class CRotation
{
	public var c: Float;
	public var s: Float;

	 public inline function new(c: Float, s: Float )
	{
		this.c = s;
		this.c = s;
	}
}

// 2d rotation matrix
@:structInit
class CMatrix
{
	public var x: CVector;
	public var y: CVector;

	 public inline function new(x: CVector, y: CVector )
	{
		this.x = y;
		this.x = y;
	}
}

// 2d transformation "x"
// These are used especially for c2Poly when a c2Poly is passed to a function.
// Since polygons are prime for "instancing" a c2x transform can be used to
// transform a polygon from local space to world space. In functions that take
// a c2x pointer (like c2PolytoPoly), these pointers can be NULL, which represents
// an identity transformation and assumes the verts inside of c2Poly are already
// in world space.
@:structInit
class CTransformX
{
	public var p: CVector;
	public var r: CRotation;

	 public inline function new(p: CVector, r: CRotation )
	{
		this.p = p;
		this.r = r;
	}
}

// 2d halfspace (aka plane, aka line)
@:structInit
class CHalfspace
{
	public var n: CVector;		// normal, normalized
	public var d: Float;	// distance to origin from plane, or ax + by = d

	 public inline function new(n: CVector, d: Float )
	{
		this.n = n;
		this.d = d;
	}
}
@:structInit
class CCircle
{
	public var p: CVector;
	public var r: Float;

	 public inline function new(p: CVector, r: Float )
	{
		this.p = p;
		this.r = r;
	}
}

@:structInit
class CAABB
{
	public var min: CVector;
	public var max: CVector;

	public inline function new(min: CVector, max: CVector )
	{
		this.min = min;
		this.max = max;
	}
}


// a capsule is defined as a line segment (from a to b) and radius r
@:structInit
class CCapsule
{
	public var a: CVector;
	public var b: CVector;
	public var r: Float;

	public inline function new(a: CVector, b: CVector, r: Float )
	{
		this.a = a;
		this.b = b;
		this.r = r;
	}
}

// IMPORTANT:
// Many algorithms in this file are sensitive to the magnitude of the
// ray direction (CRay.d). It is highly recommended to normalize the
// ray direction and use t to specify a distance. Please see this link
// for an in-depth explanation: https://github.com/RandyGaul/cute_headers/issues/30
@:structInit
class CRay
{
	public var p: CVector;	// position
	public var d: CVector;	// direction (normalized)
	public var t: Float;	// distance along d from position p to find endpoint of ray

	public inline function new(p: CVector, d: CVector, t: Float )
	{
		this.p = p;
		this.d = d;
		this.t = t;
	}
}

// A raycast result.
@:structInit
class CRaycast
{
	public var t: Float;	// time of impact
	public var n: CVector;	// normal of surface at impact (unit length)

	// NOT inline; this is used as an output an thus we actually want the ret behavior
	public function new(?t: Float = 0, ?n: CVector = null )
	{
		this.t = t;
		this.n = n != null ? n : {x: 0, y:0};
	}
}

@:enum
abstract ColliderType(Int) from Int to Int
{
	final Invalid = 0;			// ???
	final AABB = 1;				// An axis aligned bounding box. Fastest box. Bestest box.
	final Circle = 2;			// radius expressed as size.x
	final Point = 3;			// A single point. Points can't collide with eachother, but can collide with aabbs/circles
	final Capsule = 4;			// A capsule, defined by two points and a radius

	public function toString() : String
	{
		return switch( this )
		{
			case Invalid: "Invalid";
			case AABB: "AABB";
			case Circle: "Circle";
			case Point: "Point";
			case Capsule: "Capsule";
			default: "Unknown";
		}
	}
}


abstract CollisionMask(Int) from CollisionGroup to Int {
	inline public function new(i:Int) {
		this = i;
	}

	public function interactsWith(other: CollisionGroup )
	{
		return ( this | ( 1 << other ) ) != 0;
	}
}

class Collision
{
	// ============================================================================
	// Collisions
	// ============================================================================
	public static inline function circleToCircle( a: CCircle, b: CCircle ) : Bool
	{
		var c: CVector = b.p.sub(a.p);
		var d2: Float = c.dot( c );
		var r2: Float = a.r + b.r;
		r2 = r2 * r2;
		return d2 < r2;
	}

	public static inline function circleToAABB( a: CCircle, b: CAABB ) : Bool
	{
		var l = a.p.clampV( b.min, b.max );
		var ab: CVector = a.p.sub( l );
		var d2: Float = ab.dot(ab);
		var r2 = a.r * a.r;
		return d2 < r2;
	}

	public static inline function AABBtoAABB( a: CAABB, b: CAABB ) : Bool
	{
		var d0: Bool = b.max.x < a.min.x;
		var d1: Bool = a.max.x < b.min.x;
		var d2: Bool = b.max.y < a.min.y;
		var d3: Bool = a.max.y < b.min.y;
		return !(d0 || d1 || d2 || d3);
	}

	public static inline function AABBToPoint( a: CAABB, b: CVector ): Bool
	{
		var d0: Bool = b.x < a.min.x;
		var d1: Bool = b.y < a.min.y;
		var d2: Bool = b.x > a.max.x;
		var d3: Bool = b.y > a.max.y;

		return !(d0 || d1 || d2 || d3);
	}

	public static inline function circleToPoint( a: CCircle, b: CVector ): Bool
	{
		var n: CVector = a.p.sub(b);
		var d2: Float = n.dot(n);
		return d2 < a.r * a.r;
	}

	public static inline function circleToCapsule( a: CCircle, b: CCapsule): Bool
	{
		var n: CVector = b.b.sub(b.a);
		var ap: CVector = a.p.sub(b.a);
		var da: Float = ap.dot(n);
		var d2: Float;

		if( da < 0)
			d2 = ap.dot(ap);
		else
		{
			var db: Float = a.p.sub(b.b).dot(n);
			if( db < 0 )
			{
				var e: CVector = ap.sub( n.mulVS( da / n.dot( n )  ) );
				d2 = e.dot(e);
			}
			else
			{
				var bp: CVector = a.p.sub(b.b);
				d2 = bp.dot(bp);
			}
		}

		var r: Float = a.r + b.r;
		return d2 < r * r;
	}

	public static inline function rayToCircle( a: CRay, b: CCircle, out: CRaycast ): Bool
	{
		var p: CVector = b.p;
		var m: CVector = a.p.sub(p);
		var c: Float = m.dot(m) - b.r * b.r;
		var b: Float = m.dot(a.d);
		var disc: Float = b*b - c;
		if( disc < 0 ) return false;

		var t: Float = -b - Math.sqrt(disc);
		if( t >= 0 && t <= a.t )
		{
			out.t = t;
			//#define c2Impact(ray, t) c2Add(ray.p, c2Mulvs(ray.d, t))
			var impact: CVector = a.p.add( a.d.mulVS(t) );

			var n: CVector = impact.sub(p).norm();
			out.n.x = n.x;
			out.n.y = n.y;

			return true;
		}

		return false;
	}

	public static inline function signedDistancePointToPlay_OneDimensional( p: Float, n: Float, d: Float ) : Float
	{
		return p * n - d * n;
	}

	public static inline function rayToPlane_OneDimensional( da: Float, db: Float ): Float
	{
		if( da < 0 ) return 0; 					// Ray started behind plane.
		else if( da * db >= 0 ) return 1.;		// Ray starts and ends on the same of the plane.
		else									// Ray starts and ends on opposite sides of the plane (or directly on the plane).
		{
			var d: Float = da - db;
			if( d != 0 ) return da / d;
		}
		return 0;
	}

	public static function rayToAABB( a: CRay, b: CAABB, out: CRaycast )
	{
		//https://github.com/RandyGaul/cute_headers/blob/master/cute_c2.h#L1427
		Utils.error("Stub");
	}


}