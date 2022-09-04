package cerastes.c3d.entities;

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

		config.cs = 0.2;
		config.ch = 0.2;
		config.walkableSlopeAngle = 35;
		config.walkableHeight = 1;
		config.walkableClimb = 1;
		config.walkableRadius = 1;
		config.maxEdgeLen = 12;
		config.maxSimplificationError = 1.3;
		config.minRegionArea = 8;
		config.mergeRegionArea = 20;
		config.maxVertsPerPoly = 6;
		config.detailSampleDist = 6;
		config.detailSampleMaxError = 1;

		var navMesh = new recast.Native.NavMesh();

		var numPos = bsp.vertices.length * 3;
		var positions: hl.BytesAccess<Single> = new hl.Bytes( numPos * 2 );

		for( i in  0 ... bsp.vertices.length )
		{
			var v = bsp.vertices[i];
			positions.set(i*3 + 0, v.xyz[0]);
			positions.set(i*3 + 1, v.xyz[1]);
			positions.set(i*3 + 2, v.xyz[2]);
		}

		var numIdx = 0;
		for( m in 0 ... bsp.models.length )
		{
			for( s in 0 ... bsp.models[m].numSurfaces )
				numIdx += bsp.surfaces[ s + bsp.models[m].firstSurface ].numIndexes;
		}

		var indexes: hl.BytesAccess<Int> = new hl.Bytes( numIdx * 2 );

		var i = 0;
		for( m in 0 ... bsp.models.length )
		{
			for( s in 0 ... bsp.models[m].numSurfaces )
			{
				var surf = bsp.surfaces[ s + bsp.models[m].firstSurface ];
				for(idx in 0 ... surf.numIndexes )
				{
					indexes.set(i++, bsp.meshVerts[idx + surf.firstIndex]);
				}
			}

		}



		navMesh.build(cast positions, numPos, cast indexes, numIdx, config);

		#end

	}
}