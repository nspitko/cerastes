
package cerastes.c3d;

// Base override camera that requires manually touching the camera matrix
class Camera extends h3d.Camera
{
	override function update()
	{


		makeFrustumMatrix(mproj);

		m.multiply(mcam, mproj);

		needInv = true;
		//if( mcamInv != null ) mcamInv._44 = 0;
		//if( mprojInv != null ) mprojInv._44 = 0;

		frustum.loadMatrix(m);

	}

}