package cerastes.c3d.map;


class QCollision
{
	public function new( surfaceGatherer: SurfaceGatherer )
	{
		surfaceGatherer.gatherConcaveCollisionSurfaces();

		for( s in surfaceGatherer.surfaces )
		{
			var mesh = new bullet.Native.btTriangleMesh();
			
		}
	}

}