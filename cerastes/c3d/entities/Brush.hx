package cerastes.c3d.entities;

import cerastes.c3d.map.SerializedMap.BrushDef;
import cerastes.c3d.map.SerializedMap.TextureDef;
import cerastes.c3d.map.SerializedMap.EntityDef;
import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import h3d.mat.Material;
import h3d.scene.RenderContext;
import cerastes.c3d.Material.MaterialDef;
import hxd.IndexBuffer;
import h3d.scene.Object;
import h3d.scene.MultiMaterial;
import bullet.Body;
import cerastes.c3d.QEntity;

class QBrushPrim extends h3d.prim.Polygon
{

	var indexCounts: Array<Int> = [];
	var indexOffsets: Array<Int> = [];

	var currentMaterial = 0;


	var buf = new hxd.FloatBuffer();
	var bounds: h3d.col.Bounds;

	public var data: BrushDef;


	public function new( d: BrushDef )
	{
		super(null);
		idx = new IndexBuffer();

		data = d;

		bounds = new h3d.col.Bounds();

		bounds.xMin = data.bounds.xMin;
		bounds.xMax = data.bounds.xMax;
		bounds.yMin = data.bounds.yMin;
		bounds.yMax = data.bounds.yMax;
		bounds.zMin = data.bounds.zMin;
		bounds.zMax = data.bounds.zMax;

	}

	override function getBounds()
	{
		return bounds;
	}

	override function selectMaterial( i : Int )
	{
		currentMaterial = i;
	}

	override function alloc( engine: h3d.Engine )
	{
		dispose();



		var stride = 13;
		var names = ["position", "normal", "tangent", "uv", "lightmapuv" ];
		var positions = [0, 3, 6, 9, 11];

		// @todo optimize

		buf.resize( data.buf.length );

		for( f in 0 ... data.buf.length )
			buf[f] = data.buf[f];

		var ib = new IndexBuffer( data.indexes.length );
		var i = 0;
		for( i in 0 ... data.indexes.length )
			ib[i] = data.indexes[i];

		buffer = h3d.Buffer.ofFloats(buf, stride, [ Triangles, RawFormat ]);
		indexes = h3d.Indexes.alloc(ib);

		for( i in 0...names.length )
			addBuffer(names[i], buffer, positions[i]);

		indexCounts = data.indexCounts.copy();
		indexOffsets = data.indexOffsets.copy();

		buf = null;
		idx = null;
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

	public function new( parent: Object, b: BrushDef )
	{
		prim = new QBrushPrim(b);
		super(prim, [], parent);

		build( b );
	}

	public function build( b: BrushDef )
	{
		var lmt = hxd.Res.textures.lightmap.toTexture();
		for( tex in b.textures )
		{
			var m = MaterialDef.loadMaterial( findTexture(tex.name ) );
			m.texture.filter = Nearest;

			m.staticShadows = true;
			//m.texture.filter = Nearest;
			//m.mainPass.enableLights = false;
			//m.shadows = false;

			//var lm = new cerastes.shaders.LightMap(lmt);
			//m.mainPass.addShader( lm );
			materials.push( m );
		}
	}

	function findTexture( t: String )
	{
		var out = tryExt(t);
		if( out != null ) return out;

		out = tryExt('textures/${t}');
		if( out != null ) return out;

		// quake hack
		out = tryExt('textures/quake/${t.toLowerCase()}');
		if( out != null ) return out;

		return 'textures/editor/__TB_empty.png';
	}

	function tryExt( t: String )
	{
		//return "textures/lightmap.png";
		if( hxd.Res.loader.exists( t ) )
			return t;
		if( hxd.Res.loader.exists( '${t}.material' ) )
			return '${t}.material';
		if( hxd.Res.loader.exists( '${t}.png' ) )
			return '${t}.png';

		return null;
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

	public override function create( def: EntityDef, qworld: QWorld  )
	{
		if( def.spawnType == EST_ENTITY )
		{

			//setPosition( -def.brushes[0].center.x, def.brushes[0].center.y, def.brushes[0].center.z );
			setPosition( def.center.x, def.center.y, def.center.z );
		}
		world = qworld;

		buildBrush( def );
		createStaticCollision( def );

		super.create(def, qworld );

		for( b in bodies )
		{
			b.setTransform( new bullet.Point( x, y, z ) );
		}
	}

	public override function setAbsOrigin( x : Float, y : Float, z : Float )
	{
		super.setAbsOrigin(x,y,z);
		for( b in bodies )
		{
			b.setTransform( new bullet.Point(x,y,z) );
		}
	}

	function onCollision( )
	{

	}

	public function buildBrush( def: EntityDef )
	{
		brush = new QBrush(this, def.brush);



	}

	function createStaticCollision( def: EntityDef )
	{

		for( s in def.collisionBodies )
		{
			var iface = new bullet.Native.TriangleMesh();
			var i = 0;
			while( i < s.vertices.length )
			{
				iface.addTriangle(
					new bullet.Native.Vector3(
						s.vertices[ s.indices[ i + 0 ] * 3 + 0 ],
						s.vertices[ s.indices[ i + 0 ] * 3 + 1 ],
						s.vertices[ s.indices[ i + 0 ] * 3 + 2 ]
					),
					new bullet.Native.Vector3(
						s.vertices[ s.indices[ i + 1 ] * 3 + 0 ],
						s.vertices[ s.indices[ i + 1 ] * 3 + 1 ],
						s.vertices[ s.indices[ i + 1 ] * 3 + 2 ]
					),
					new bullet.Native.Vector3(
						s.vertices[ s.indices[ i + 2 ] * 3 + 0 ],
						s.vertices[ s.indices[ i + 2 ] * 3 + 1 ],
						s.vertices[ s.indices[ i + 2 ] * 3 + 2 ]
					),
					true
				);
				i+=3;
			}

			var shape = new bullet.Native.ConvexTriangleMeshShape(iface, true );
			var b = createBody( shape );

			@:privateAccess b.mesh = iface;
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
	}*/
}