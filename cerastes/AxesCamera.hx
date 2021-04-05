package cerastes;

import h3d.Vector;
import h3d.Matrix;

class AxesCamera extends h3d.Camera
{
	public var ax = new Vector(1,0,0);
	public var ay = new Vector(0,1,0);
	public var az = new Vector(0,0,1);

	public function setRotation(x: Float, y: Float, z: Float )
	{
		ax.x = x;
		ay.y = y;
		az.z = z;
	}

	public function getRotation()
	{
		return new Vector(ax.x, ay.y, az.z);
	}

	override function makeCameraMatrix( m: Matrix ) {

		az.normalizeFast();
		ax.normalizeFast();

		m._11 = ax.x;
		m._12 = ay.x;
		m._13 = az.x;
		m._14 = 0;
		m._21 = ax.y;
		m._22 = ay.y;
		m._23 = az.y;
		m._24 = 0;
		m._31 = ax.z;
		m._32 = ay.z;
		m._33 = az.z;
		m._34 = 0;
		m._41 = -ax.dot3(pos);
		m._42 = -ay.dot3(pos);
		m._43 = -az.dot3(pos);
		m._44 = 1;
	}
}

