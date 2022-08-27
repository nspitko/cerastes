package cerastes.c3d.bsp;

import cerastes.c3d.Material.MaterialDef;
import h3d.shader.pbr.PropsValues;
import hxd.IndexBuffer;
import cerastes.c3d.bsp.BSPFile.DBrushSide_t;
import cerastes.c3d.bsp.BSPFile.DBrush_t;
import cerastes.c3d.bsp.BSPFile.DPlane_t;
import cerastes.c3d.bsp.BSPFile.MapSurfaceType_t;
import hxd.PixelFormat;
import hxd.Pixels;
import haxe.io.Bytes;
import h3d.Indexes;
import h3d.mat.Texture;
import h3d.mat.Data.TextureFlags;
import h3d.mat.Data.Wrap;
import h3d.mat.Data.Face;
import hxd.FloatBuffer;
import h3d.mat.Material;
import h3d.col.Collider.OptimizedCollider;
import h3d.col.ObjectCollider;
import h3d.col.Point;
import h3d.col.Bounds;
import h3d.Buffer;
import h3d.scene.RenderContext;
import h3d.Camera;
import h3d.scene.Object;
import cerastes.c3d.bsp.BSPFile.BSPFileDef;
import h3d.Vector;
import hxd.Math;


typedef BSPTraceResult = {
	var allSolid: Bool;
	var startSolid: Bool;
	var fraction: Float;
	var endPos: Vector;
	var plane: DPlane_t;
	var ?surfaceFlags: Int;
	var ?contents: Int;
	var ?entityNum: Int;
}

enum TraceType {
	RAY;
	SPHERE;
	BOX;
}

class BSPMap extends Object
{
	var visibleFaces: haxe.ds.Vector<Array<Int>>;
	var visibleMaterials = new Array<Int>();


	var bsp: BSPFileDef;

	var materialMap = new Map<String,Material>();
	var materials = new Array<Material>();
	var vertexBuffer: Buffer = null;
	var vertexIndices: h3d.Indexes = null;

	var bufferCache : Map<Int,h3d.Buffer.BufferOffset>;
	var prevNames : Array<String>;
	var prevBuffers : h3d.Buffer.BufferOffset;

	var stride : Int = 11;

	var bufferNames = ["position","normal","uv","uvlm","color"];
	var bufferPositions=[0,3,6,8,10];
	var emittedMaterials: Map<Int,Int> = []; // Map of emitId->textureId

	var idxBuffer: Indexes;

	var idxBytes: Bytes;

	var lightMapMegaTexture : Texture;

	var enableVis: Bool = false;



	public function new(bspFile: BSPFile, ?parent: Object )
	{
		super(parent);

		bsp = bspFile.file;

		idxBuffer = new Indexes(bsp.meshVerts.length,true);

		idxBytes = Bytes.alloc(bsp.meshVerts.length*10); // was 4 HACK HACK

		loadLightMaps();
		loadMaterials();
		loadBuffers();

		var col = new cerastes.c3d.bsp.BSPCollision();
		col.createCollision(bsp );

		var e = new cerastes.c3d.bsp.BSPEntities( this, bsp );
	}


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

	function loadBuffers()
	{
		// Create our vertex buffer. We don't use quake's because we want to stuff a bit more info in.

		vertexBuffer = new Buffer(bsp.vertices.length, stride);
		var vertexBytes = Bytes.alloc( bsp.vertices.length * stride * 4 );
		var pos = 0;

		var mapVertexToLightMap = new Map<Int, Int>();

		for( face in bsp.surfaces )
		{
			for( i in 0...face.numIndexes )
				mapVertexToLightMap.set(face.firstVertex  + bsp.meshVerts[i + face.firstIndex ], face.lightMapIndex);
				//var vertex = face.vertex  + bsp.meshVerts[i + face.meshVert ]
		}


		for( i in 0... bsp.vertices.length )
		{
			var v = bsp.vertices[i];
			// position
			vertexBytes.setFloat(pos, v.xyz[0]);
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
			var lmIdx = mapVertexToLightMap[i];
			if( lmIdx != null && lmIdx != -1 )
			{
				#if biglightmaps
				var lmX =  v.lightmap[0];
				var lmY =  v.lightmap[1];
				#else
				var lmOffsetX = ( lmIdx % 16 ) / 16;
				var lmOffsetY = Math.floor( lmIdx / 16 ) / 16;

				var lmX =  ( ( v.lightmap[0] ) / 16 ) + lmOffsetX;
				var lmY =  ( ( v.lightmap[1] ) / 16 ) + lmOffsetY ;
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
		vertexBuffer.uploadBytes( vertexBytes, 0, bsp.vertices.length );

		for( i in 0...bufferNames.length )
			addBuffer(bufferNames[i], vertexBuffer, bufferPositions[i]);

	}

	function addBuffer( name : String, buf, offset = 0 )
	{
		if( bufferCache == null )
			bufferCache = new Map();
		var id = hxsl.Globals.allocID(name);
		var old = bufferCache.get(id);
		if( old != null ) old.dispose();
		bufferCache.set(id, new h3d.Buffer.BufferOffset(buf, offset));
	}


	function getBuffers( engine : h3d.Engine, ?offset: Int )
	{
		if( bufferCache == null )
			bufferCache = new Map();
		var names = @:privateAccess engine.driver.getShaderInputNames();
		if( names.names == prevNames )
		{
			/*
			var b = prevBuffers;
			for( name in names.names )
			{
				var idx = bufferNames.indexOf(cast name);

				Utils.assert(idx != -1,"Unmapped buffer name: " + name);
				b.offset = offset * stride + bufferPositions[idx];

				b = b.next;
			}*/
			return prevBuffers;
		}
		var buffers = null, prev = null;
		for( name in names.names )
		{
			var id = hxsl.Globals.allocID(name);
			var b = bufferCache.get(id);
			if( b == null ) {
				//b = allocBuffer(engine, name);
				if( b == null ) throw "Buffer " + name + " is not available";
				bufferCache.set(id, b);
			}
			//var idx = bufferNames.indexOf(cast name);
			//Utils.assert(idx != -1,"Unmapped buffer name: " + name);
			//b.offset = offset * stride + bufferPositions[idx];

			b.next = null;

			if( prev == null ) {
				buffers = prev = b;
			} else {
				prev.next = b;
				prev = b;
			}
		}
		prevNames = names.names;
		return prevBuffers = buffers;
	}

	function loadMaterials()
	{
		for( matInfo in bsp.shaders )
		{
			var matPath = '${matInfo.shader}';
			var tex = null;
			if( hxd.Res.loader.exists('$matPath.png') )
				matPath = '$matPath.png';
			else
			{
				matPath = 'bsp/${matInfo.shader}';

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


			trace('Loaded: ${matInfo.shader}');



			var shader = new cerastes.c3d.bsp.shaders.Q3PBRLightmapShader();
			//mat.mainPass.removeShader( mat.textureShader );
			mat.mainPass.addShader( shader );
			mat.texture.filter = Nearest;


			var lmTex = hxd.Res.maps.bsp2_compile.lm_0000_png.toTexture();
			shader.texture = lmTex;

			//shader.lightMapTexture = lmTex;



			mat.name = matInfo.shader;
			mat.mainPass.culling = Face.Front;
			//mat.mainPass.
			materialMap.set(matInfo.shader, mat);
			materials.push(mat);

		}
	}

	// needed??
	override function getBoundsRec( b : Bounds )
	{
		b = super.getBoundsRec(b);
		var tmp = new Bounds();
		tmp.setMin(new Point(-10000,-10000,-10000));
		tmp.setMax(new Point(10000,10000,10000));
		tmp.transform(absPos);
		b.add(tmp);
		return b;
	}

	override function getMaterialByName( name : String ) : h3d.mat.Material
	{
		if( materialMap.exists( name ) )
		{
			return materialMap.get( name );
		}
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

	inline function swizzle( v: Vector )
	{
		var t: Float = v.y;
		v.y = v.z;
		v.z = -t;
	}

	function findLeaf( cameraPosition: Vector ) : Int
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

			var planeVec = new Vector(plane.normal[0], plane.normal[1], plane.normal[2]);
			//swizzle(planeVec)
			var distance = planeVec.dot3( cameraPosition ) - plane.dist;

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
		visibleFaces = new haxe.ds.Vector(bsp.shaders.length);
		for( i in 0 ... bsp.shaders.length )
		{
			visibleFaces[i] = [];
		}
		emittedMaterials = [];
		visibleMaterials = [];


		var rootLeafIdx = findLeaf(ctx.camera.pos);
		var rootLeaf = bsp.leafs[rootLeafIdx];
		var emitIdx = 0;

		for( leaf in bsp.leafs )
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


				if (visibleFaces[face.shaderNum].indexOf(f) == -1 )
					visibleFaces[face.shaderNum].push(f);

				var bFound = visibleMaterials.indexOf(face.shaderNum) != -1;



				if( !bFound )
				{
					emittedMaterials.set(emitIdx, face.shaderNum );
					visibleMaterials.push(face.shaderNum);
					ctx.emit(materials[face.shaderNum], this, emitIdx);
					emitIdx++;
				}
			}
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
		//var mat = materials[ctx.drawPass.index];
		var textureIdx = emittedMaterials[ctx.drawPass.index];
		//return;
		// first pass: How many verts do we have?
		var indices = 0;
		var idx = 0;

		var size = 0;
		var indexTotal = 0;

		// Quick scan to determine our alloc size
		for( faceIdx in visibleFaces[textureIdx] )
		{
			var face = bsp.surfaces[faceIdx];

			if( face.surfaceType != MST_PLANAR && face.surfaceType != MST_TRIANGLE_SOUP)
				continue;

			indexTotal += face.numIndexes;

		}

		size = indexTotal * 4;


		if( idxBytes.length < size )
		{
			idxBytes = Bytes.alloc( size );
			idxBuffer = new Indexes( indexTotal, true);
		}



		for( faceIdx in visibleFaces[textureIdx] )
		//for( face in bsp.faces )
		{
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
		ctx.engine.renderMultiBuffers(bufs,idxBuffer,0, CMath.floor( indices / 3 ) );

		//idxBuffer.dispose();

		//trace( ctx.engine.drawCalls - ds );

		// DBG

		/*
		for( faceIdx in visibleFaces[textureIdx] )
		//for( face in bsp.faces )
		{
			var face = bsp.surfaces[faceIdx];

			if( face.surfaceType != MST_PLANAR && face.surfaceType != MST_TRIANGLE_SOUP)
				continue;

			var i=0;
			var col = 0x00FF00;
			while( i < face.numIndexes )
			{
				var vi1 = face.firstVertex  + bsp.meshVerts[i + face.firstIndex ];
				var vi2 = face.firstVertex  + bsp.meshVerts[i + 1 + face.firstIndex ];
				var vi3 = face.firstVertex  + bsp.meshVerts[i + 2 + face.firstIndex ];
				var vtx1 = bsp.vertices[ vi1 ];
				var vtx2 = bsp.vertices[ vi2 ];
				var vtx3 = bsp.vertices[ vi3 ];

				DebugDraw.line( new Point( vtx1.xyz[0], vtx1.xyz[1], vtx1.xyz[2] ), new Point( vtx2.xyz[0], vtx2.xyz[1], vtx2.xyz[2] ), col );
				DebugDraw.line( new Point( vtx2.xyz[0], vtx2.xyz[1], vtx2.xyz[2] ), new Point( vtx3.xyz[0], vtx3.xyz[1], vtx3.xyz[2] ), col );
				DebugDraw.line( new Point( vtx1.xyz[0], vtx1.xyz[1], vtx1.xyz[2] ), new Point( vtx3.xyz[0], vtx3.xyz[1], vtx3.xyz[2] ), col );


				i+=3;

			}
		}
*/

	}



}
