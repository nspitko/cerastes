package cerastes.c3d.map;

import cerastes.c3d.map.SerializedMap.MapFile;
import h3d.scene.Graphics;
import h3d.scene.Mesh;
import hxd.IndexBuffer;
import h3d.Indexes;
import hxd.fmt.hmd.Data.Material;
import h3d.prim.UV;
import h3d.col.Point;
import h3d.prim.MeshPrimitive;
import h3d.prim.Primitive;
import h3d.scene.MultiMaterial;
import cerastes.c3d.Material.MaterialDef;
import h3d.scene.Object;
import cerastes.c3d.DebugDraw;




class QMap extends Object
{
	public var data: MapFile;
	var world: QWorld;

	var bodies: Array<BulletBody>;


	public function new( file: String, world: QWorld, ?parent: Object )
	{
		this.world = world;

		var entry = hxd.Res.loader.load( file ).entry;
		data = (new hxbitmini.Serializer()).unserialize(entry.getBytes(), MapFile );

		super( parent );

	}

	public function init()
	{

		// Add entity spawns
		for( e in data.entities )
		{
			QEntity.createEntity( e, world );
		}

	}

/*

	function debugDrawSurfaceDetails( s: Surface, drawFaces = false, drawNormals = false, drawTangents = false )
	{

		if( s.indices.length < 3 )
			return;

		// Draw triangles
		var i = 0;
		if( drawFaces )
		{
			while( i < s.indices.length )
			{
				var idx =  s.indices[i];
				var idxn =  s.indices[i+1];
				DebugDraw.line( s.vertices[idx].vertex, s.vertices[idxn].vertex, 0x00FF00, -1, 0.25 );
				i++;
				if( i % 3 == 2 ) i++;
			}
		}

		// Draw normal/tangent
		var i = 0;
		var scale: Float = 8;
		while( i < s.vertices.length )
		{
			var vtx = s.vertices[i];
			if( drawNormals )
				DebugDraw.line( vtx.vertex, vtx.vertex.add( vtx.normal.multiply(scale) ), 0x0000FF,-1 );
			if( drawTangents )
				DebugDraw.line( vtx.vertex, vtx.vertex.add( vtx.tangent.multiply(scale) ), 0xFF0000,-1 );

			i++;
		}
	}
	*/
}