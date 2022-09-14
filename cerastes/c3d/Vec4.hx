package cerastes.c3d;

@:structInit
class CVec4
{
	public var x:Float;
	public var y:Float;
	public var z:Float;
	public var w:Float;

	public inline function new(x:Float, y:Float, z:Float, w:Float)
	{
		this.x = x;
		this.y = y;
		this.z = z;
		this.w = w;
	}
}

// --------------------------------------------------------------------------------------------------
@:forward
abstract Vec4(CVec4)
{
	public inline function new(x:Float, y:Float, z:Float, w:Float)
	{
		this = new CVec4(x, y, z, w);
	}

	// --------------------------------------------------------------------------------------------------
	@:from
	static inline public function fromVec3(v:Vec3):Vec4
	{
		return new Vec4(v.x, v.y, v.z, 1);
	}

	@:to
	public inline function toVec3():Vec3
	{
		return new Vec3(this.x, this.y, this.z);
	}

	// --------------------------------------------------------------------------------------------------
	@:from
	static inline public function fromHeapsVector(v:h3d.Vector):Vec4
	{
		return new Vec4(v.x, v.y, v.z, v.w);
	}

	@:to
	public inline function toHeapsVector():h3d.Vector
	{
		return new h3d.Vector(this.x, this.y, this.z, this.w);
	}
}