package cerastes.c3d.map;

import h3d.scene.Graphics;
import h3d.scene.Mesh;
import cerastes.c3d.map.Data.Surface;
import cerastes.c3d.map.Data.Entity;
import hxd.IndexBuffer;
import h3d.Indexes;
import hxd.fmt.hmd.Data.Material;
import h3d.prim.UV;
import h3d.col.Point;
import cerastes.c3d.map.Data.BrushGeometry;
import cerastes.c3d.map.Data.Brush;
import h3d.prim.MeshPrimitive;
import h3d.prim.Primitive;
import h3d.scene.MultiMaterial;
import cerastes.c3d.Material.MaterialDef;
import cerastes.c3d.map.Data.MapData;
import h3d.scene.Object;

class QBrushPrim extends h3d.prim.Polygon
{
	var brushGeo: BrushGeometry;
	var entity: Entity;

	public function new( e: Entity, bGeo: BrushGeometry )
	{
		super(null);
		this.entity = e;
		this.brushGeo = bGeo;
	}

	override function alloc( engine: h3d.Engine )
	{
		dispose();

		var stride = 11;
		var names = ["position", "normal", "tangent", "uv"];
		var positions = [0, 3, 6, 9];

		var buf = new hxd.FloatBuffer();

		var idx = new IndexBuffer();

		for( f in brushGeo.faces )
		{
			if( f.indices == null )
				continue;

			for( v in f.vertices )
			{
				buf.push(v.vertex.x);
				buf.push(v.vertex.y);
				buf.push(v.vertex.z);

				buf.push(v.normal.x);
				buf.push(v.normal.y);
				buf.push(v.normal.z);

				buf.push(v.tangent.x);
				buf.push(v.tangent.y);
				buf.push(v.tangent.z);

				buf.push(v.uv.u);
				buf.push(v.uv.v);
			}

			for( i in f.indices )
				idx.push(i);
		}

		if( idx.length == 0 )
			return;

		buffer = h3d.Buffer.ofFloats(buf, stride, [ Triangles, RawFormat ]);
		indexes = h3d.Indexes.alloc(idx);

		for( i in 0...names.length )
			addBuffer(names[i], buffer, positions[i]);
	}

}

class QBrush extends MultiMaterial
{
	public function new( e: Entity, brush: BrushGeometry, materials, parent: Object )
	{
		var prim = new QBrushPrim( e, brush );
		super(prim, materials, parent);

	}
}


class QSurfacePrim extends h3d.prim.Polygon
{
	var surface: Surface;

	public function new( s: Surface )
	{
		super(null);
		this.surface = s;
	}

	override function alloc( engine: h3d.Engine )
	{
		dispose();

		var stride = 11;
		var names = ["position", "normal", "tangent", "uv"];
		var positions = [0, 3, 6, 9];

		var buf = new hxd.FloatBuffer();

		var idx = new IndexBuffer();

		for( v in surface.vertices )
		{
			buf.push(v.vertex.x);
			buf.push(v.vertex.y);
			buf.push(v.vertex.z);

			buf.push(v.normal.x);
			buf.push(v.normal.y);
			buf.push(v.normal.z);

			buf.push(v.tangent.x);
			buf.push(v.tangent.y);
			buf.push(v.tangent.z);

			buf.push(v.uv.u);
			buf.push(v.uv.v);
		}

		for( i in surface.indices )
			idx.push(i);


		buffer = h3d.Buffer.ofFloats(buf, stride, [ Triangles, RawFormat ]);
		indexes = h3d.Indexes.alloc(idx);

		for( i in 0...names.length )
			addBuffer(names[i], buffer, positions[i]);
	}

}

class QSurface extends Mesh
{
	public function new( surface: Surface, material: h3d.mat.Material, parent: Object )
	{
		var prim = new QSurfacePrim( surface );
		super(prim, material, parent);
	}
}

class QMap extends Object
{
	var data: MapData;

	public function new( file: String, ?parent: Object )
	{
		super( parent );
		//var entry = hxd.Loader.load(file);

		var parser = new cerastes.c3d.map.MapParser();
		data = parser.load( hxd.Res.map.test1.entry );

		data.setSpawnTypeByClassName("worldspawn", EST_WORLDSPAWN);
		data.setSpawnTypeByClassName("func_group", EST_WORLDSPAWN);

		var generator = new cerastes.c3d.map.GeoGenerator();
		generator.run( data );

		init();
	}

	function init()
	{
		var materials = new Array<h3d.mat.Material>();
		// @todo
		for( t in data.textures )
		{
			var mat = MaterialDef.loadMaterial( "mat/__TB_empty.material" );
			mat.name = t.name;
			mat.shadows = true;

			materials.push(mat);

		}

		var surfaceGatherer = new cerastes.c3d.map.SurfaceGatherer();
		surfaceGatherer.setSplitType( SST_ENTITY );
		surfaceGatherer.run( data );

		for( s in 0 ... surfaceGatherer.surfaces.length )
		{
			var s = surfaceGatherer.surfaces[s];
			if( s.vertices.length == 0 )
				continue;

			new QSurface(s, materials[0], this);
		}

		// Add entity spawns
		for( e in data.entities )
		{
			if( e.spawnType == EST_ENTITY )
			{
				var g = new Graphics(this);

				var origin = e.getProperty('origin');
				var bits = origin.split(" ");
				g.setPosition(
					-Std.parseFloat(bits[0]),
					Std.parseFloat(bits[1]),
					Std.parseFloat(bits[2])
				 );


				g.material.mainPass.setPassName("overlay");
				g.material.mainPass.depthTest = Always;

				var lineSize = 25;
				var arrowSize = 10;

				// X (Red)
				g.lineStyle(1, 0xFF0000, 1);
				g.drawLine(new Point(-lineSize,0,0), new Point(lineSize,0,0));
				g.drawLine(new Point(lineSize,arrowSize,0), new Point(lineSize,-arrowSize,0));

				// Y (Green)
				g.lineStyle(1, 0x00FF00, 1);
				g.drawLine(new Point(0,-lineSize,0), new Point(0,lineSize,0));
				g.drawLine(new Point(arrowSize,lineSize,0), new Point(-arrowSize,lineSize,0));

				// Z (Blue)
				g.lineStyle(1, 0x0000FF, 1);
				g.drawLine(new Point(0,0,-lineSize), new Point(0,0,lineSize));
				g.drawLine(new Point(arrowSize,0,lineSize), new Point(-arrowSize,0,lineSize));
			}
		}

/*
		for( e in 0 ... data.entityGeo.length )
		{
			var entity = data.entities[e];
			var entityGeo = data.entityGeo[e];
			for( b in entityGeo.brushes )
			{
				var brush =  new QBrush(entity, b, materials, this );
			}
		}
*/

	}




}