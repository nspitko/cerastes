package cerastes.c3d.entities;

import cerastes.c3d.QEntity;

/**
 * Worldspawn is the root entity for a map. It contains all the physics for
 * the world and manages all entities.
 */

@qClass(
	{
		name: "worldspawn",
		desc: "World Entity",
		type: "SolidClass",
	}
)
class Worldspawn extends Brush
{
	/*
	public override function buildBrush( def: cerastes.c3d.map.Data.Entity )
	{
		brush = new QBrush(world);
		var surfaceGatherer = new cerastes.c3d.map.SurfaceGatherer( world.map.data );

		for( t in 0 ... world.map.data.textures.length )
		{
			// Worldspawn may get brushes merged down into it, so check every texture.

			var tex = world.map.data.getTexture( t );
			surfaceGatherer.surfaces = [];
			surfaceGatherer.setEntityIndexFilter( def.index );
			surfaceGatherer.gatherTextureSurfaces( tex.name, def.index );

			var foundSurfaces = false;

			for( s in 0 ... surfaceGatherer.surfaces.length )
			{
				var s = surfaceGatherer.surfaces[s];
				if( s.vertices.length == 0 )
					continue;

				foundSurfaces = true;
				brush.addSurface( s );
			}

			if( foundSurfaces )
				brush.setCurrentMaterial( getBrushMaterial( tex )  );

		}

		createStaticCollision( surfaceGatherer );


	}
	*/
}