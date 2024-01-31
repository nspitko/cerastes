package cerastes.c2d;

import cerastes.c3d.Vec3;
import cerastes.c3d.Vec4;

@:structInit
class CVec2
{
	public var x:Float;
	public var y:Float;

	public inline function new(x:Float = 0, y:Float = 0)
	{
		this.x = x;
		this.y = y;
	}

	public inline function distance( v : Vec2 )
	{
		return Math.sqrt( distanceSq( v ) );
	}

	public inline function distanceSq( v : Vec2 )
	{
		var dx = v.x - x;
		var dy = v.y - y;
		return dx * dx + dy * dy;
	}

	public inline function clone() : Vec2
	{
		return new Vec2( x, y );
	}

	public inline function set( x: Float, y: Float )
	{
		this.x = x;
		this.y = y;
	}

}

// --------------------------------------------------------------------------------------------------
@:forward
abstract Vec2(CVec2) from CVec2 {
	public inline function new(x:Float, y:Float)
	{
		this = new CVec2(x, y);
	}

	// Vec4
	@:from
	static inline public function fromVec4(v:Vec4):Vec2
	{
		return new Vec2(v.x, v.y);
	}

	@:to
	public inline function toVec4():Vec4
	{
		return new Vec4(this.x, this.y, 1, 1);
	}

	// Vec3
	@:from
	static inline public function fromVec3(v:Vec3):Vec2
	{
		return new Vec2(v.x, v.y);
	}

	@:to
	public inline function toVec3():Vec3
	{
		return new Vec3(this.x, this.y, 1);
	}

	// --------------------------------------------------------------------------------------------------
	// Operations
	//
	// NOTE: you MUST define operators by order of specificity. ie, += before +, else + will always win
	// and we end up creating an extra instance for no reason

	@:op(A += B)
	public inline function addVecInline( v: Vec2 )
	{
		this.x += v.x;
		this.y += v.y;
	}

	// --------------------------------------------------------------------------------------------------

	@:op(A + B)
	public inline function addVecRet( v: Vec2 ): Vec2
	{
		return new Vec2( this.x + v.x, this.y + v.y );
	}

	// --------------------------------------------------------------------------------------------------
	@:op(A *= B)
	public inline function mulVecInline( v: Vec2 )
	{
		this.x *= v.x;
		this.y *= v.y;
	}

	@:op(A *= B)
	public inline function mulFloatInline( v: Float )
	{
		this.x *= v;
		this.y *= v;
	}

	// --------------------------------------------------------------------------------------------------

	@:op(A * B)
	public inline function mulVec( v: Vec2 ): Vec2
	{
		return new Vec2( this.x * v.x, this.y * v.y );
	}

	@:op(A * B)
	public inline function mulFloat( v: Float ): Vec2
	{
		return new Vec2( this.x * v, this.y * v );
	}

	// --------------------------------------------------------------------------------------------------
	// Heaps vector
	@:from
	static inline public function fromHeapsVector4(v: h3d.Vector4 ):Vec2
	{
		return new Vec2(v.x, v.y);
	}

	@:to
	public inline function toHeapsVector4():h3d.Vector4
	{
		return new h3d.Vector4(this.x, this.y, 1);
	}

	// --------------------------------------------------------------------------------------------------
	// Heaps point 3d
	@:from
	static inline public function fromHeapsPoint(v: h3d.col.Point ):Vec2
	{
		return new Vec2(v.x, v.y);
	}

	@:to
	public inline function toHeapsPoint():h3d.col.Point
	{
		return new h3d.col.Point(this.x, this.y, 1);
	}

	// --------------------------------------------------------------------------------------------------
	// Heaps point 2d
	@:from
	static inline public function fromHeapsPoint2d(v: h2d.col.Point ):Vec2
	{
		return new Vec2(v.x, v.y );
	}

	@:to
	public inline function toHeapsPoint2d():h2d.col.Point
	{
		return new h2d.col.Point(this.x, this.y);
	}
}