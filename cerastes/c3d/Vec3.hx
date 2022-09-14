package cerastes.c3d;

import cerastes.c3d.Matrix;

@:structInit
class CVec3
{
	public var x:Float;
	public var y:Float;
	public var z:Float;

	public inline function new(x:Float, y:Float, z:Float)
	{
		this.x = x;
		this.y = y;
		this.z = z;
	}

	public inline function distance( v : Vec3 )
	{
		return Math.sqrt( distanceSq( v ) );
	}

	public inline function distanceSq( v : Vec3 )
	{
		var dx = v.x - x;
		var dy = v.y - y;
		var dz = v.z - z;
		return dx * dx + dy * dy + dz * dz;
	}

	public inline function clone() : Vec3
	{
		return new Vec3( x, y, z);
	}

	public inline function set( x: Float, y: Float, z: Float )
	{
		this.x = x;
		this.y = y;
		this.z = z;
	}

}

// --------------------------------------------------------------------------------------------------
@:forward
abstract Vec3(CVec3) {
	public inline function new(x:Float, y:Float, z:Float)
	{
		this = new CVec3(x, y, z);
	}

	// Vec4
	@:from
	static inline public function fromVec3(v:Vec4):Vec3
	{
		return new Vec3(v.x, v.y, v.z);
	}

	@:to
	public inline function toVec4():Vec4
	{
		return new Vec4(this.x, this.y, this.z, 1);
	}

	// --------------------------------------------------------------------------------------------------
	// Operations
	//
	// NOTE: you MUST define operators by order of specificity. ie, += before +, else + will always win
	// and we end up creating an extra instance for no reason

	@:op(A += B)
	public inline function addVecInline( v: Vec3 )
	{
		this.x += v.x;
		this.y += v.y;
		this.z += v.z;
	}

	// --------------------------------------------------------------------------------------------------

	@:op(A + B)
	public inline function addVecRet( v: Vec3 ): Vec3
	{
		return new Vec3( this.x + v.x, this.y + v.y, this.z + v.z );
	}

	// --------------------------------------------------------------------------------------------------
	@:op(A *= B)
	public inline function mulVecInline( v: Vec3 )
	{
		this.x *= v.x;
		this.y *= v.y;
		this.z *= v.z;
	}

	@:op(A *= B)
	public inline function mulFloatInline( v: Float )
	{
		this.x *= v;
		this.y *= v;
		this.z *= v;
	}

	@:op(A *= B)
	public inline function mulMatrix3x4Inline( m: Matrix )
	{
		var px = this.x * m._11 + this.y * m._21 + this.z * m._31 + m._41;
		var py = this.x * m._12 + this.y * m._22 + this.z * m._32 + m._42;
		var pz = this.x * m._13 + this.y * m._23 + this.z * m._33 + m._43;
		this.x = px;
		this.y = py;
		this.z = pz;
	}

	// --------------------------------------------------------------------------------------------------

	@:op(A * B)
	public inline function mulVec( v: Vec3 ): Vec3
	{
		return new Vec3( this.x * v.x, this.y * v.y, this.z * v.z );
	}

	@:op(A * B)
	public inline function mulFloat( v: Float ): Vec3
	{
		return new Vec3( this.x * v, this.y * v, this.z * v );
	}

	@:op(A * B)
	public inline function mulMatrix3x4( m : Matrix )
	{
		var px = this.x * m._11 + this.y * m._21 + this.z * m._31 + m._41;
		var py = this.x * m._12 + this.y * m._22 + this.z * m._32 + m._42;
		var pz = this.x * m._13 + this.y * m._23 + this.z * m._33 + m._43;
		return new Vec3(px,py,pz);
	}

	// --------------------------------------------------------------------------------------------------
	// Heaps vector
	@:from
	static inline public function fromHeapsVector(v: h3d.Vector ):Vec3
	{
		return new Vec3(v.x, v.y, v.z);
	}

	@:to
	public inline function toHeapsVector():h3d.Vector
	{
		return new h3d.Vector(this.x, this.y, this.z);
	}

	// --------------------------------------------------------------------------------------------------
	// Heaps point
	@:from
	static inline public function fromHeapsPoint(v: h3d.col.Point ):Vec3
	{
		return new Vec3(v.x, v.y, v.z);
	}

	@:to
	public inline function toHeapsPoint():h3d.col.Point
	{
		return new h3d.col.Point(this.x, this.y, this.z);
	}
}