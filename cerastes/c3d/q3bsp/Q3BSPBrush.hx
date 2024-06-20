package cerastes.c3d.q3bsp;

import hxd.BufferFormat.BufferInput;
import cerastes.macros.Metrics;
import cerastes.c3d.q3bsp.Q3BSPFile.DLeaf_t;
import h3d.mat.Data.Face;
import cerastes.c3d.Material.MaterialDef;
import h3d.mat.Texture;
import h3d.mat.Material;
import h3d.scene.RenderContext;
import h3d.Vector4;
import h3d.col.Point;
import h3d.col.Bounds;
import cerastes.c3d.Entity.EntityData;
import haxe.io.Bytes;
import h3d.Indexes;
import h3d.Buffer;
import cerastes.c3d.q3bsp.Q3BSPFile.DModel_t;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import cerastes.c3d.q3bsp.Q3BSPFile.DBrush_t;
import cerastes.c3d.q3bsp.Q3BSPEntity.Q3BSPEntityData;
import cerastes.c3d.entities.Brush.BaseBrush;

class Q3BSPBrush extends BaseBrush
{
	var visibleFaces: Map<Int, Array<Int>>;

	var bsp: BSPFileDef;

	var materialMap = new Map<Int,Material>();
	var materials = new Array<Material>();
	var vertexBuffer: Buffer = null;
	var vertexIndices: h3d.Indexes = null;


	final stride : Int = 11;


	var idxBuffer: Indexes;
	var idxBytes: Bytes;
	public static var enableVis: Bool = false;

	var skipVis = false; // This is enabled if vis is detected to be bad.
	var modelDef: DModel_t;
	var brushBounds: Bounds;
	var visLeafs: haxe.ds.Vector<DLeaf_t>;


	override function create( def: EntityData, w: World )
	{
		world = w;
		createBrush( def );

		super.create(def, w );
	}

	var bulletShapes = [];
	var bulletIfaces = [];
	var bulletTransforms = [];
	override function createBody( def: EntityData )
	{
		var col = new Q3BSPCollision();
		var compoundShape = new bullet.Native.CompoundShape(false);
		for( b in 0 ... modelDef.numBrushes )
		{
			var brushCol = col.createCollision( b + modelDef.firstBrush, bsp );


			var iface = new bullet.Native.TriangleMesh();

			for( f in 0 ... brushCol.faces.length )
			{
				var color = Std.random(0xFFFFFF);
				var s = brushCol.faces[f];
				if( s.vertices.length < 3 )
					continue;

				var i = 0;
				while( i < s.indices.length )
				{
					iface.addTriangle(
						new bullet.Native.Vector3(
							s.vertices[ s.indices[ i + 0 ] ].x,
							s.vertices[ s.indices[ i + 0 ] ].y,
							s.vertices[ s.indices[ i + 0 ] ].z
						),
						new bullet.Native.Vector3(
							s.vertices[ s.indices[ i + 1 ] ].x,
							s.vertices[ s.indices[ i + 1 ] ].y,
							s.vertices[ s.indices[ i + 1 ] ].z
						),
						new bullet.Native.Vector3(
							s.vertices[ s.indices[ i + 2 ] ].x,
							s.vertices[ s.indices[ i + 2 ] ].y,
							s.vertices[ s.indices[ i + 2 ] ].z
						),
						true
					);


					 i+=3;
				}
			}

			var shape = new bullet.Native.ConvexTriangleMeshShape(iface, true );
			var transform = new bullet.Native.Transform();
			transform.setIdentity();
			compoundShape.addChildShape( transform, shape);
			transform.delete();

			bulletShapes.push(shape);
			bulletIfaces.push(iface);

		}

		body = new cerastes.c3d.BulletBody( compoundShape, 1, CollisionObject );
		body.addTo(world.physics, WORLD, MASK_WORLD );
		body.object = this;

		//debugDrawBody(body,-1);
	}

	function createBrush( def: EntityData )
	{
		if( !Utils.verify(def.bsp != null, "Brush loaded without bsp info!") ) return;
		bsp = def.bsp;

		var modelId = 0;
		if( def.getProperty("classname") != "worldspawn")
		{
			var model = def.getProperty("model");
			if( !Utils.verify( model != null && model.substr(0,1) == "*", "Brush has missing/invalid model specification; brush will not function" ) ) return;

			modelId = Std.parseInt( model.substr(0,1) );
		}

		modelDef = def.bsp.models[modelId];

		brushBounds = new Bounds();
		brushBounds.setMin( new Point( modelDef.mins[0], modelDef.mins[1], modelDef.mins[2] ) );
		brushBounds.setMax( new Point( modelDef.maxs[0], modelDef.maxs[1], modelDef.maxs[2] ) );

		loadBuffers( def.bsp );
		loadMaterials( def.bsp );
		loadVis( def.bsp );

	}

	function loadVis( bsp: BSPFileDef )
	{
		var vl = [];
		for( leaf in bsp.leafs )
		{
			// Invalid leaves
			if( leaf.cluster < 0 )
				continue;

			for( sl in 0 ... leaf.numLeafSurfaces )
			{
				var s = bsp.leafFaces[sl + leaf.firstLeafSurface ];

				if( s >= modelDef.firstSurface && s < modelDef.firstSurface + modelDef.numSurfaces )
				{
					vl.push( leaf );
					continue;
				}
			}
		}

		visLeafs = new haxe.ds.Vector(vl.length );
		for( i in 0 ... visLeafs.length )
		{
			visLeafs[i] = vl[i];
		}
	}

	#if useQuakeLightmaps
	// @todo Size megatexture to number of lms
	function loadLightMaps()
	{

		Utils.assert( bsp.lightMaps.length < 16*16, "Too many lightmaps! all maps past 256 will be invalid");

		var pixels = Pixels.alloc(2048,2048,PixelFormat.RGBA);
		for( x in 0 ... 16 )
		{
			for( y in 0 ... 16 )
			{
				var idx = y * 16 + x;
				if( idx >= bsp.lightMaps.length )
					break;
				var lm = bsp.lightMaps[idx];
				pixels.blit(x*128,y*128,lm,0,0,128,128);
			}
		}

		lightMapMegaTexture = Texture.fromPixels(pixels);

	}
	#end

	function loadBuffers( bsp: BSPFileDef)
	{
		// First pass: Figure out how big we need our buffers

		var numVerts = 0;
		var numIndexes = 0;

		for( s in 0 ... modelDef.numSurfaces )
		{
			var surf = bsp.surfaces[ modelDef.firstSurface + s ];
			numVerts += surf.numVertices;
			numIndexes = surf.numIndexes;
		}

		// Alloc
		vertexBuffer = new Buffer(numVerts, hxd.BufferFormat.make([
			new BufferInput("position", DVec3),
			new BufferInput("normal", DVec3),
			new BufferInput("uv", DVec2),
			new BufferInput("uvlm", DVec2),
			new BufferInput("color", DBytes4),

		]));
		var vertexBytes = Bytes.alloc( bsp.vertices.length * stride * 4 );


		var pos = 0;

		for( s in 0 ... modelDef.numSurfaces )
		{
			var surf = bsp.surfaces[ modelDef.firstSurface + s ];
			for( i in 0 ... surf.numVertices )
			{
				var v = bsp.vertices[i + surf.firstVertex];
				// position
				vertexBytes.setFloat(pos + 0, v.xyz[0]);
				vertexBytes.setFloat(pos + 4, v.xyz[1]);
				vertexBytes.setFloat(pos + 8, v.xyz[2]);

				// normal
				vertexBytes.setFloat(pos + 12, v.normal[0]);
				vertexBytes.setFloat(pos + 16, v.normal[1]);
				vertexBytes.setFloat(pos + 20, v.normal[2]);

				// uv
				vertexBytes.setFloat(pos + 24, 1 - v.st[0]);
				vertexBytes.setFloat(pos + 28, v.st[1]);

				// lightmap uv
				var lmIdx = surf.lightMapIndex;
				if( lmIdx != -1 )
				{
					#if useQuakeLightmaps
					var lmOffsetX = ( lmIdx % 16 ) / 16;
					var lmOffsetY = Math.floor( lmIdx / 16 ) / 16;

					var lmX =  ( ( v.lightmap[0] ) / 16 ) + lmOffsetX;
					var lmY =  ( ( v.lightmap[1] ) / 16 ) + lmOffsetY;
					#else
					var lmX =  v.lightmap[0];
					var lmY =  v.lightmap[1];
					#end

					vertexBytes.setFloat(pos + 32, lmX );
					vertexBytes.setFloat(pos + 36, lmY  );
				}
				else
				{
					vertexBytes.setFloat(pos + 32, 1 );
					vertexBytes.setFloat(pos + 36, 1 );
				}

				// vertex color
				vertexBytes.set(pos + 40, v.color[0]);
				vertexBytes.set(pos + 41, v.color[1]);
				vertexBytes.set(pos + 42, v.color[2]);
				vertexBytes.set(pos + 43, 255);

				// vertex lightmap index
				//vertexBytes.setInt32(pos + 52, );

				pos += stride * 4;
			}

		}


		// @todo: Need to segement based on LM index; brushes may span more than one!
		// This might be covered by shader segmentation already, but maybe not!
		/*

		var mapVertexToLightMap = new Map<Int, Int>();

		for( face in bsp.surfaces )
		{
			for( i in 0...face.numIndexes )
				mapVertexToLightMap.set(face.firstVertex  + bsp.meshVerts[i + face.firstIndex ], face.lightMapIndex);
				//var vertex = face.vertex  + bsp.meshVerts[i + face.meshVert ]
		}
		*/

		vertexBuffer.uploadBytes( vertexBytes, 0, CMath.floor( pos / stride / 4 ) );

	}



	function getBuffers( engine : h3d.Engine, ?offset: Int )
	{
		return vertexBuffer;
	}

	inline function getMaterialId( shaderIdx: Int, lightmapIdx: Int )
	{
		return shaderIdx | ( ( lightmapIdx & 0xFF) << 24 );
	}

	function loadMaterials( bsp: BSPFileDef )
	{
		for( s in 0 ... modelDef.numSurfaces )
		{
			var surface = bsp.surfaces[s + modelDef.firstSurface ];

			var shaderIdx = surface.shaderNum;
			var shader = bsp.shaders[ shaderIdx ];

			// Create a unique ID for this combination factoring in shader num
			var matId = getMaterialId( shaderIdx, surface.lightMapIndex );
			if( materialMap.exists( matId ) )
				continue;

			var matPath = '${shader.shader}';
			var tex = null;

			// Special case
			if( matPath == "textures/__TB_empty")
				matPath = 'textures/editor/__TB_empty';
			trace(matPath);

			if( hxd.Res.loader.exists('$matPath.png') )
				matPath = '$matPath.png';
			else
			{
				matPath = 'bsp/${shader.shader}';

				// search order: tga -> jpg
				if( hxd.Res.loader.exists('$matPath.tga') )
					tex = hxd.Res.loader.load('$matPath.tga').toTexture();
				else if( hxd.Res.loader.exists('$matPath.jpg') )
					tex = hxd.Res.loader.load('$matPath.jpg').toTexture();
				else
				{
					Utils.warning('Missing texture: $matPath');
					tex = Texture.fromColor(0xFFFF00FF);
				}
			}
			//tex.wrap = Wrap.Repeat;
			//var mat = Material.create(tex);
			var mat = MaterialDef.loadMaterial(matPath);


			trace('Loaded: ${shader.shader}');



			var lmShader = new cerastes.c3d.q3bsp.shaders.Q3PBRLightmapShader();
			//mat.mainPass.removeShader( mat.textureShader );
			mat.mainPass.addShader( lmShader );
			mat.texture.filter = Nearest; // @todo: move this into a standard materialdef we load for map as a whole
			mat.mainPass.isStatic = true;
			//mat.mainPass.enableLights = false;
			mat.castShadows = false;
			//mat.receiveShadows = true;

			// @todo: need more context upstream to derive this
			var texFile = '${bsp.fileName.substr(0, bsp.fileName.length - 4)}/lm_${ StringTools.lpad(""+surface.lightMapIndex,"0",4) }.tga';

			var lmTex: Texture;
			try
			{
				lmTex = hxd.Res.loader.load( texFile ).toTexture();
			}
			catch(e)
			{
				Utils.error('Failed to load lightmap ${texFile}: $e');
				lmTex = Utils.invalidTexture();
			}
			lmShader.texture = lmTex;

			//shader.lightMapTexture = lmTex;



			mat.name = shader.shader;
			//mat.mainPass.culling = Front;
			//mat.mainPass.
			materialMap.set(matId, mat);
			//materialIdMap.set( )
			materials.push(mat);

		}
	}

	// @todo model specifies these, just need to import
	override function addBoundsRec( b : h3d.col.Bounds, relativeTo : h3d.Matrix )
	{
		var tmp = brushBounds.clone();
		tmp.transform(absPos); // @todo checkme
		b.add(tmp);
		return super.addBoundsRec( b, relativeTo );
	}

	override function getMaterialByName( name : String ) : h3d.mat.Material
	{
		for( m in materials )
			if( m.name == name )
				return m;

		return super.getMaterialByName(name);
	}

	override function getMaterials( ?a : Array<h3d.mat.Material>, recursive = true )
	{
		if( a == null ) a = [];

		for( m in materials )
			if( m != null && a.indexOf(m) < 0 )
				a.push(m);

		if( recursive ) {
			for( o in children )
				o.getMaterials(a);
		}

		return a;
	}
/*
	inline function swizzle( v: Vector )
	{
		var t: Float = v.y;
		v.y = v.z;
		v.z = -t;
	}
*/
	function findLeaf( cameraPosition: h3d.Vector ) : Int
	{
		// Create a local camera vector and convert it to goofy ass quake coords.
		//var localCamera = cameraPosition.clone();
		//swizzle(localCamera);

		//return 142;

		var index: Int = 0;

		while( index >= 0 )
		{
			var node = bsp.nodes[index];
			var plane = bsp.planes[node.planeNum];

			var planeVec = new h3d.Vector(plane.normal[0], plane.normal[1], plane.normal[2]);
			//swizzle(planeVec)
			var distance = planeVec.dot( cameraPosition ) - plane.dist;

			if( distance >= 0 )
				index = node.children[0];
			else
				index = node.children[1];
		}

		return -index - 1;
	}

	function isClusterVisible( visCluster: Int, testCluster: Int )
	{
		if( bsp.visData.vectors == null || visCluster == 0 )
			return true;

		var i: Int = ( visCluster * bsp.visData.sizeVectors) + (testCluster >> 3);
		var visSet: Int = bsp.visData.vectors[i];


		return (visSet & (1 << (testCluster & 7))) != 0;
	}

	function getTextureIndex(name: String )
	{
		for( i in 0 ... bsp.shaders.length )
		{
			if( bsp.shaders[i].shader == name )
				return i;
		}

		return -1;
	}

	override function emit( ctx : RenderContext )
	{

		// Fast path for when vis fails.
		if( skipVis )
		{
			for( matId => mat in materialMap )
			{
				ctx.emit(mat, this, matId);
			}
			return;
		}

		visibleFaces = [];
		for( key => val in materialMap )
		{
			// @todo: Perf
			visibleFaces[key] = [];
		}

		var visibleMaterials: Array<Int> = [];


		var rootLeafIdx = findLeaf(ctx.camera.pos);
		var rootLeaf = bsp.leafs[rootLeafIdx];

		Metrics.begin("Vis");
		var numVisibleLeaves = 0;
		//for( leaf in bsp.leafs )
		for( leaf in visLeafs )
		{

			// Vis check.
			if( enableVis && leaf.cluster != rootLeaf.cluster && !isClusterVisible( rootLeaf.cluster, leaf.cluster ) )
				continue;

			for(i in 0 ... leaf.numLeafSurfaces )
			{
				var lf = i + leaf.firstLeafSurface;

				var f = bsp.leafFaces[lf];

				var face = bsp.surfaces[f];
				Utils.assert( face != null, "Leaf points to invalid face ???" );

				var matId = getMaterialId( face.shaderNum, face.lightMapIndex );

				if (visibleFaces[matId].indexOf(f) == -1 )
					visibleFaces[matId].push(f);

				var bFound = visibleMaterials.indexOf(matId) != -1;

				if( !bFound )
				{

					visibleMaterials.push(matId);
					ctx.emit(materialMap[matId], this, matId);
				}

			}
			numVisibleLeaves++;
		}

		Metrics.end();

		if( numVisibleLeaves == visLeafs.length )
		{
			Utils.warning("Vis is invalid! Skipping future vis checks.");
			skipVis = true;
		}
		//trace('Visible faces: ${visibleFaces.length}');
		//trace('Emitted textures: $emitIdx');




		//trace("Emit called");
	}

	override function draw( ctx : RenderContext )
	{
		super.draw(ctx);

		renderFaces(ctx);
	}

	function renderFaces(ctx: RenderContext)
	{
		//return;
		// one pass per index, figure out which mat we're on
		var matId = ctx.drawPass.index;
		//return;
		// first pass: How many verts do we have?
		var indices = 0;
		var idx = 0;

		var size = 0;
		var indexTotal = 0;

		// Quick scan to determine our alloc size
		for( materialId in visibleFaces[matId] )
		{
			var faceIdx = materialId & 0x00FFFFFF;
			var face = bsp.surfaces[faceIdx];

			if( face.surfaceType != MST_PLANAR && face.surfaceType != MST_TRIANGLE_SOUP)
				continue;

			indexTotal += face.numIndexes;

		}

		size = indexTotal * 4;


		if( idxBytes == null || idxBytes.length < size )
		{
			idxBytes = Bytes.alloc( size );
			idxBuffer = new Indexes( indexTotal, true);
		}



		for( materialId in visibleFaces[matId] )
		//for( face in bsp.faces )
		{
			var faceIdx = materialId & 0x00FFFFFF;
			var face = bsp.surfaces[faceIdx];

			if( face.surfaceType != MST_PLANAR && face.surfaceType != MST_TRIANGLE_SOUP)
				continue;

			Utils.assert( face.firstIndex % 3 == 0 && face.numIndexes % 3 == 0, "Invalid meshvert offset" );

			indices += face.numIndexes;

			for( i in 0 ... face.numIndexes )
			{
				var index = face.firstVertex  + bsp.meshVerts[i + face.firstIndex ];
				idxBytes.setInt32(idx, index );
				idx+=4;
			}
		}

		// indices OK
		//var v = 256;
		//if( verts > v )
		//	trace('buffer sample: ${idxAccess[ 4*v ]},${idxAccess[ 4*v+1 ]},${idxAccess[ 4*v+2 ]},${idxAccess[ 4*v+3 ]}');

		Utils.assert( indices == size / 4, "????" );

		idxBuffer.uploadBytes(idxBytes.sub(0,size),0,indices);

		var bufs = getBuffers(ctx.engine);

		//ctx.engine.renderIndexed(vertexBuffer,idxBuffer,0 );
		ctx.engine.renderIndexed(bufs,idxBuffer,0, CMath.floor( indices / 3 ) );


	}

}