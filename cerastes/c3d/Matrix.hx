package cerastes.c3d;

@:structInit
class CMatrix
{
	public var _11 : Float;
	public var _12 : Float;
	public var _13 : Float;
	public var _14 : Float;
	public var _21 : Float;
	public var _22 : Float;
	public var _23 : Float;
	public var _24 : Float;
	public var _31 : Float;
	public var _32 : Float;
	public var _33 : Float;
	public var _34 : Float;
	public var _41 : Float;
	public var _42 : Float;
	public var _43 : Float;
	public var _44 : Float;

	public inline function new()
	{
	}

	public inline function zero()
	{
		_11 = 0.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = 0.0; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 0.0; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 0.0;
	}

	public inline function identity()
	{
		_11 = 1.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = 1.0; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 1.0; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	public function isIdentity()
	{
		if( _41 != 0 || _42 != 0 || _43 != 0 )
			return false;
		if( _11 != 1 || _22 != 1 || _33 != 1 )
			return false;
		if( _12 != 0 || _13 != 0 || _14 != 0 )
			return false;
		if( _21 != 0 || _23 != 0 || _24 != 0 )
			return false;
		if( _31 != 0 || _32 != 0 || _34 != 0 )
			return false;
		return _44 == 1;
	}

	public function isIdentityEpsilon( e : Float )
	{
		if( Math.abs(_41) > e || Math.abs(_42) > e || Math.abs(_43) > e )
			return false;
		if( Math.abs(_11-1) > e || Math.abs(_22-1) > e || Math.abs(_33-1) > e )
			return false;
		if( Math.abs(_12) > e || Math.abs(_13) > e || Math.abs(_14) > e )
			return false;
		if( Math.abs(_21) > e || Math.abs(_23) > e || Math.abs(_24) > e )
			return false;
		if( Math.abs(_31) > e || Math.abs(_32) > e || Math.abs(_34) > e )
			return false;
		return Math.abs(_44 - 1) <= e;
	}

	public inline function initRotationX( a : Float )
	{
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		_11 = 1.0; _12 = 0.0; _13 = 0.0; _14 = 0.0;
		_21 = 0.0; _22 = cos; _23 = sin; _24 = 0.0;
		_31 = 0.0; _32 = -sin; _33 = cos; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	public function initRotationY( a : Float )
	{
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		_11 = cos; _12 = 0.0; _13 = -sin; _14 = 0.0;
		_21 = 0.0; _22 = 1.0; _23 = 0.0; _24 = 0.0;
		_31 = sin; _32 = 0.0; _33 = cos; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	public function initRotationZ( a : Float )
	{
		var cos = Math.cos(a);
		var sin = Math.sin(a);
		_11 = cos; _12 = sin; _13 = 0.0; _14 = 0.0;
		_21 = -sin; _22 = cos; _23 = 0.0; _24 = 0.0;
		_31 = 0.0; _32 = 0.0; _33 = 1.0; _34 = 0.0;
		_41 = 0.0; _42 = 0.0; _43 = 0.0; _44 = 1.0;
	}

	public inline function setPosition( v : Vec4 )
	{
		_41 = v.x;
		_42 = v.y;
		_43 = v.z;
		_44 = v.w;
	}
}

// --------------------------------------------------------------------------------------------------
@:forward
abstract Matrix(CMatrix)
{
	public inline function new()
	{
		this = new CMatrix();
	}

	@:from
	static inline public function fromHeapsMatrix(m:h3d.Matrix):Matrix
	{
		var o = new Matrix();
		o._11 = m._11; o._12 = m._12; o._13 = m._13; o._14 = m._14;
		o._21 = m._21; o._22 = m._22; o._23 = m._23; o._24 = m._24;
		o._31 = m._31; o._32 = m._32; o._33 = m._33; o._34 = m._34;
		o._41 = m._41; o._42 = m._42; o._43 = m._43; o._44 = m._44;
		return o;
	}

	@:to
	public inline function toHeapsMatrix():h3d.Matrix
	{
		var o = new h3d.Matrix();
		o._11 = this._11; o._12 = this._12; o._13 = this._13; o._14 = this._14;
		o._21 = this._21; o._22 = this._22; o._23 = this._23; o._24 = this._24;
		o._31 = this._31; o._32 = this._32; o._33 = this._33; o._34 = this._34;
		o._41 = this._41; o._42 = this._42; o._43 = this._43; o._44 = this._44;

		return o;
	}
}