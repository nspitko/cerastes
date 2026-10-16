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

	public function multiply( b : Matrix ) 
	{
		var a = this;
		var a11 = a._11; var a12 = a._12; var a13 = a._13; var a14 = a._14;
		var a21 = a._21; var a22 = a._22; var a23 = a._23; var a24 = a._24;
		var a31 = a._31; var a32 = a._32; var a33 = a._33; var a34 = a._34;
		var a41 = a._41; var a42 = a._42; var a43 = a._43; var a44 = a._44;
		var b11 = b._11; var b12 = b._12; var b13 = b._13; var b14 = b._14;
		var b21 = b._21; var b22 = b._22; var b23 = b._23; var b24 = b._24;
		var b31 = b._31; var b32 = b._32; var b33 = b._33; var b34 = b._34;
		var b41 = b._41; var b42 = b._42; var b43 = b._43; var b44 = b._44;

		return Matrix.from4x4(
			a11 * b11 + a12 * b21 + a13 * b31 + a14 * b41,
			a11 * b12 + a12 * b22 + a13 * b32 + a14 * b42,
			a11 * b13 + a12 * b23 + a13 * b33 + a14 * b43,
			a11 * b14 + a12 * b24 + a13 * b34 + a14 * b44,

			a21 * b11 + a22 * b21 + a23 * b31 + a24 * b41,
			a21 * b12 + a22 * b22 + a23 * b32 + a24 * b42,
			a21 * b13 + a22 * b23 + a23 * b33 + a24 * b43,
			a21 * b14 + a22 * b24 + a23 * b34 + a24 * b44,

			a31 * b11 + a32 * b21 + a33 * b31 + a34 * b41,
			a31 * b12 + a32 * b22 + a33 * b32 + a34 * b42,
			a31 * b13 + a32 * b23 + a33 * b33 + a34 * b43,
			a31 * b14 + a32 * b24 + a33 * b34 + a34 * b44,

			a41 * b11 + a42 * b21 + a43 * b31 + a44 * b41,
			a41 * b12 + a42 * b22 + a43 * b32 + a44 * b42,
			a41 * b13 + a42 * b23 + a43 * b33 + a44 * b43,
			a41 * b14 + a42 * b24 + a43 * b34 + a44 * b44,

		);




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

	public static function from4x4( 
		a11: Float, a12: Float, a13: Float, a14: Float,
		a21: Float, a22: Float, a23: Float, a24: Float,
		a31: Float, a32: Float, a33: Float, a34: Float,
		a41: Float, a42: Float, a43: Float, a44: Float,
	)
	{
		var o = new Matrix();
		o._11 = a11; o._12 = a12; o._13 = a13; o._14 = a14;
		o._21 = a21; o._22 = a22; o._23 = a23; o._24 = a24;
		o._31 = a31; o._32 = a32; o._33 = a33; o._34 = a34;
		o._41 = a41; o._42 = a42; o._43 = a43; o._44 = a44;
		return o;
	}
}