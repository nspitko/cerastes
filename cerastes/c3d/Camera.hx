
package cerastes.c3d;

import h3d.Matrix;

// Base override camera that requires manually touching the camera matrix
class Camera extends h3d.Camera
{
	override function update()
	{


		makeFrustumMatrix(mproj);

		DebugDraw.text(mproj.toString(),0xFFFFFF,);

		m.multiply(mcam, mproj);

		needInv = true;
		//if( mcamInv != null ) mcamInv._44 = 0;
		//if( mprojInv != null ) mprojInv._44 = 0;

		frustum.loadMatrix(m);

	}

	override function makeFrustumMatrix( m : Matrix )
	{
		m.zero();

		// this will take into account the aspect ratio and normalize the z value into [0,1] once it's been divided by w
		// Matrixes have to solve the following formulaes :
		//
		// transform P by Mproj and divide everything by
		//    [x,y,-zNear,1] => [sx/zNear, sy/zNear, 0, 1]
		//    [x,y,-zFar,1] => [sx/zFar, sy/zFar, 1, 1]

		// we apply the screen ratio to the height in order to have the fov being a horizontal FOV. This way we don't have to change the FOV when the screen is enlarged


		var degToRad = (Math.PI / 180);
		var halfFovX = Math.atan( Math.tan(fovY * 0.5 * degToRad) * screenRatio );
		var scale = zoom / Math.tan(halfFovX);
		m._11 = scale;
		m._22 = scale * screenRatio;
		m._33 = zFar / (zFar - zNear);
		m._34 = 1;
		m._43 = -(zNear * zFar) / (zFar - zNear);


		m._11 += viewX * m._14;
		m._21 += viewX * m._24;
		m._31 += viewX * m._34;
		m._41 += viewX * m._44;

		m._12 += viewY * m._14;
		m._22 += viewY * m._24;
		m._32 += viewY * m._34;
		m._42 += viewY * m._44;

		// our z is negative in that case
		if( rightHanded ) {
			m._33 *= -1;
			m._34 *= -1;
		}
	}

}