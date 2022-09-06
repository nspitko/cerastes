package cerastes.c3d.entities;

import cerastes.c3d.World.BaseWorld;
import h3d.col.Point;
import haxe.io.Bytes;
#if hlimgui
import hl.BytesAccess;
#end
import webidl.Types.NativePtr;
import cerastes.c3d.Entity.EntityData;

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

	override function tick( delta: Float )
	{
		super.tick(delta);
		debugDrawBody(body);
	}

	override function create(def: EntityData, world: World )
	{
		super.create(def, world);

		#if recast
		// Ok yeah but...
		var config = new recast.Native.RcConfig();

		config.cs = 0.2 * BaseWorld.METERS_TO_WORLD;
		config.ch = 0.2 * BaseWorld.METERS_TO_WORLD;
		config.walkableSlopeAngle = 35;
		config.walkableHeight = 1;
		config.walkableClimb = 1;
		config.walkableRadius = 1;
		config.maxEdgeLen = 12;
		config.maxSimplificationError = 1.3;
		config.minRegionArea = 8;
		config.mergeRegionArea = 20;
		config.maxVertsPerPoly = 6;
		config.detailSampleDist = 6 * BaseWorld.METERS_TO_WORLD;
		config.detailSampleMaxError = 1;

		var navMesh = new recast.Native.NavMesh();

		var numPos = bsp.vertices.length * 3;
		var positions: hl.BytesAccess<Single> = new hl.Bytes( numPos * 4 * 3 );

		var modelDef = bsp.models[0];

		var pos = 0;
		for( s in 0 ... modelDef.numSurfaces )
		{
			var surf = bsp.surfaces[ modelDef.firstSurface + s ];
			for( i in 0 ... surf.numVertices )
			{
				var v = bsp.vertices[i + surf.firstVertex];
				positions.set(pos++, -v.xyz[0]);
				positions.set(pos++, v.xyz[2]);
				positions.set(pos++, v.xyz[1]);

				Utils.assert(pos <= numPos, "Bad write" );
			}
		}


		var numIdx = 0;

		for( s in 0 ... modelDef.numSurfaces )
			numIdx += bsp.surfaces[ s + modelDef.firstSurface ].numIndexes;


		var indexes: hl.BytesAccess<Int> = new hl.Bytes( numIdx * 4 );

		var i = 0;

		for( s in 0 ... modelDef.numSurfaces )
		{
			var face = bsp.surfaces[ s + modelDef.firstSurface ];
			for(f in 0 ... face.numIndexes )
			{
				var index = face.firstVertex  + bsp.meshVerts[f + face.firstIndex ];

				indexes.set(i++, index);
			}
		}


		if( false )
			{
				var idx = 0;
				while ( idx < numIdx  )
				{

					var vOffset = indexes[idx] * 3;
					var p1 = new Point( positions.get(vOffset), positions.get(vOffset+1), positions.get(vOffset+2) );
					vOffset = indexes[idx + 1] * 3;
					var p2 = new Point( positions.get(vOffset), positions.get(vOffset+1), positions.get(vOffset+2) );
					vOffset = indexes[idx + 2] * 3;
					var p3 = new Point( positions.get(vOffset), positions.get(vOffset+1), positions.get(vOffset+2) );

					DebugDraw.line( p1,p2, 0x002288, -1 );
					DebugDraw.line( p3, p2 , 0x002288, -1 );
					DebugDraw.line( p1, p3, 0x002288, -1 );

					idx += 3;


				}
			}



		navMesh.build(cast positions, bsp.vertices.length, cast indexes, numIdx, config);

		trace("?OK?");


		if( false )
		{
			// Draw bounds
			var debugMesh = navMesh.getDebugNavMesh();

			for( i in 0 ... debugMesh.getTriangleCount() )
			{
				var triangle = debugMesh.getTriangle( i );
				var p1 = triangle.getPoint(0);
				var p2 = triangle.getPoint(1);
				var p3 = triangle.getPoint(2);


				DebugDraw.line( new Point( -p1.x, p1.z, p1.y ), new Point( -p2.x, p2.z, p2.y ), 0x002288, -1 );
				DebugDraw.line( new Point( -p3.x, p3.z, p3.y ), new Point( -p2.x, p2.z, p2.y ), 0x002288, -1 );
				DebugDraw.line( new Point( -p1.x, p1.z, p1.y ), new Point( -p3.x, p3.z, p3.y ), 0x002288, -1 );


			}
		}

		#end

	}
}