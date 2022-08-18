package cerastes.c3d.entities;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import h3d.mat.Material;
import h3d.scene.RenderContext;
import cerastes.c3d.map.SurfaceGatherer;
import cerastes.c3d.Material.MaterialDef;
import hxd.IndexBuffer;
import cerastes.c3d.map.Data.Surface;
import h3d.scene.Object;
import h3d.scene.MultiMaterial;
import bullet.Body;
import cerastes.c3d.map.Data.TextureData;
import cerastes.c3d.QEntity;

class QBrushPrim extends h3d.prim.Polygon
{
	var surfaces: Array<Surface> = [];

	var indexCounts: Array<Int> = [];
	var indexOffsets: Array<Int> = [0];

	var currentMaterial = 0;


	var buf = new hxd.FloatBuffer();
	var vertOffset = 0;
	var idxOffset = 0;
	var idxCount = 0;


	public function new( )
	{
		super(null);
		idx = new IndexBuffer();
	}

	public function cutMaterial()
	{
		indexCounts.push( idxCount );
		indexOffsets.push( idxOffset );
		idxCount = 0;
	}

	public function addSurface(surface: Surface)
	{

		// @todo: Remove duplicates
		for( v in surface.vertices )
		{
			buf.push(v.vertex.x);
			buf.push(v.vertex.y);
			buf.push(v.vertex.z);

			buf.push(-v.normal.x);
			buf.push(v.normal.y);
			buf.push(v.normal.z);

			buf.push(v.tangent.x);
			buf.push(v.tangent.y);
			buf.push(v.tangent.z);

			buf.push(v.uv.u);
			buf.push(v.uv.v);
		}

		for( i in surface.indices )
			idx.push(vertOffset + i);

		idxOffset += surface.indices.length;
		vertOffset += surface.vertices.length;
		idxCount += surface.indices.length;



	}

	override function selectMaterial( i : Int )
	{
		currentMaterial = i;
	}

	override function alloc( engine: h3d.Engine )
	{
		dispose();

		var stride = 11;
		var names = ["position", "normal", "tangent", "uv"];
		var positions = [0, 3, 6, 9];


		buffer = h3d.Buffer.ofFloats(buf, stride, [ Triangles, RawFormat ]);
		indexes = h3d.Indexes.alloc(idx);

		for( i in 0...names.length )
			addBuffer(names[i], buffer, positions[i]);

		//buf = null;
		//idx = null;
	}

	override function render( engine : h3d.Engine )
	{
		if( currentMaterial < 0 )
		{
			super.render(engine);
			return;
		}
		if( indexes == null || indexes.isDisposed() )
			alloc(engine);

		engine.renderMultiBuffers(
			getBuffers(engine),
			indexes,
			Std.int(indexOffsets[currentMaterial]/3),
			Std.int(indexCounts[currentMaterial]/3)
		);

		currentMaterial = -1;
	}

}

class QBrush extends MultiMaterial
{
	var prim: QBrushPrim;

	public function new( parent: Object )
	{
		prim = new QBrushPrim();
		super(prim, [], parent);
	}

	public function addSurface( surface: Surface )
	{

		prim.addSurface(surface);
	}

	public function setCurrentMaterial( material: Material )
	{
		materials.push(material);
		prim.cutMaterial();
	}

	override function draw( ctx : RenderContext ) {
		if( materials.length > 1 )
			primitive.selectMaterial(ctx.drawPass.index);
		super.draw(ctx);
	}
}

class Brush extends QEntity
{
	var bodies: Array<BulletBody> = [];
	var brush: QBrush;

	public override function create( def: cerastes.c3d.map.Data.Entity, qworld: QWorld  )
	{
		if( def.spawnType == EST_ENTITY )
		{
			Utils.assert(def.brushes.length == 1, "Entity type brush is a group, this is unsupported!" );
			setPosition( -def.brushes[0].center.x, def.brushes[0].center.y, def.brushes[0].center.z );
		}
		world = qworld;
		var surfaceGatherer = new cerastes.c3d.map.SurfaceGatherer( world.map.data );
		buildBrush( surfaceGatherer, def );
		createStaticCollision( surfaceGatherer, def );

		super.create(def, qworld );

		for( b in bodies )
		{
			b.setTransform( new bullet.Point( x, y, z ) );
		}
	}

	function onCollision( )
	{

	}

	public function buildBrush( surfaceGatherer: SurfaceGatherer, def: cerastes.c3d.map.Data.Entity )
	{
		brush = new QBrush(this);

		var textures = [];

		for( b in  0 ... def.brushes.length )
		{
			for( f in 0 ... def.brushes[b].faces.length )
			{
				var textureId = def.brushes[b].faces[f].textureIdx;
				if( !textures.contains(textureId ) )
					textures.push( textureId );
			}
		}

		for( t in 0 ... textures.length )
		{
			// Worldspawn may get brushes merged down into it, so check every texture.
			var tex = world.map.data.getTexture( textures[t] );
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


	}

	function getBrushMaterial( t: TextureData )
	{
		var file = t.name;

		if(t.name == "__TB_empty")
			file = "editor/__TB_empty";

		if( hxd.Res.loader.exists( 'textures/${file}.material' ) )
			file = 'textures/${file}.material';
		else
			file = 'textures/${file}.png';

		var mat = MaterialDef.loadMaterial( file );
		mat.name = t.name;
		mat.texture.filter = Nearest;

		return mat;

	}

	function createStaticCollision( surfaceGatherer: SurfaceGatherer,  def: cerastes.c3d.map.Data.Entity )
	{
		var surfaceGatherer = new SurfaceGatherer( world.map.data );

		bodies = [];
		surfaceGatherer.gatherConvexCollisionSurfaces(def.index);
		var surfaces = surfaceGatherer.surfaces;

		for( s in surfaces )
		{
			var iface = new bullet.Native.TriangleMesh();
			var i = 0;
			if( s.indices.length < 3 )
				continue;

			//if( def.spawnType == EST_ENTITY )
			//	debugDrawSurfaceDetails( s, true, false, false );


			while( i < s.indices.length )
			{
				iface.addTriangle(
					new bullet.Native.Vector3(
						s.vertices[ s.indices[ i + 0 ] ].vertex.x,
						s.vertices[ s.indices[ i + 0 ] ].vertex.y,
						s.vertices[ s.indices[ i + 0 ] ].vertex.z
						),
						new bullet.Native.Vector3(
						s.vertices[ s.indices[ i + 1 ] ].vertex.x,
						s.vertices[ s.indices[ i + 1 ] ].vertex.y,
						s.vertices[ s.indices[ i + 1 ] ].vertex.z
						),
						new bullet.Native.Vector3(
						s.vertices[ s.indices[ i + 2 ] ].vertex.x,
						s.vertices[ s.indices[ i + 2 ] ].vertex.y,
						s.vertices[ s.indices[ i + 2 ] ].vertex.z
						),
						true
					);

					// DEBUG: Draw normal/tangent vectors


					i+=3;

			}

			var shape = new bullet.Native.ConvexTriangleMeshShape(iface, true );
			var b = createBody( shape );

			b.mesh = iface;
			bodies.push(b);


		}
	}

	function createBody(shape: bullet.Native.ConvexTriangleMeshShape )
	{
		var b = new cerastes.c3d.BulletBody( shape, 0, CollisionObject );
		b.addTo(world.physics, WORLD, MASK_WORLD );
		b.object = this;
		return b;
	}


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
}