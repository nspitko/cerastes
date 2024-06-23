package cerastes.c3d.q3bsp;

import h3d.Vector4;
import hxd.PixelFormat;
import hxd.Pixels;
import h3d.mat.Texture;
import haxe.ds.Vector;
import haxe.io.Bytes;

// Header
@:structInit class Lump_t
{
	public var offset: Int;
	public var length: Int;
}

@:structInit class DHeader_t
{
	public var magic: String = null;
	public var version: Int = 0;
	public var dirEntries: haxe.ds.Vector<Lump_t> = null;
}

// Entities (TODO)
@:structInit class BSPEntities_t
{
	public var entities: String;
}

// Textures
@:structInit class DShader_t
{
	public var shader: String;
	public var surfaceFlags: Int;
	public var contentFlags: Int;
}

// Planes
@:structInit class DPlane_t
{
	public var normal: Vector<Float>;
	public var dist: Float;
}

// Nodes
@:structInit class DNode_t
{
	public var planeNum: Int;
	public var children: Vector<Int>;
	public var mins: Vector<Int>;
	public var maxs: Vector<Int>;
}

// Models
@:structInit class DModel_t
{
	public var mins: Vector<Float>;
	public var maxs: Vector<Float>;
	public var firstSurface: Int;
	public var numSurfaces: Int;
	public var firstBrush: Int;
	public var numBrushes: Int;
}

// Leafs
@:structInit class DLeaf_t
{
	public var cluster: Int;
	public var area: Int;
	public var mins: Vector<Int>;
	public var maxs: Vector<Int>;
	public var firstLeafSurface: Int;
	public var numLeafSurfaces: Int;
	public var firstLeafBrush: Int;
	public var numLeafBrushes: Int;
}

// Brush
@:structInit class DBrush_t
{
	public var firstSide: Int;
	public var numSides: Int;
	public var shaderNum: Int;
}

// Brush Sides
@:structInit class DBrushSide_t
{
	public var planeNum: Int;
	public var shaderNum: Int;
}

// Vertices
@:structInit class DrawVert_t
{
	public var xyz: Vector<Float>;
	public var st: Vector<Float>;
	public var lightmap: Vector<Float>;
	public var normal: Vector<Float>;
	public var color: Vector<Int>;
}

// Effects
@:structInit class BSPEffectDef
{
	public var name: String;
	public var brush: Int;
	public var unknown: Int;
}

// Faces
@:structInit class DSurface_t
{
	public var shaderNum: Int;
	public var fogNum: Int;
	public var surfaceType: MapSurfaceType_t;
	public var firstVertex: Int;
	public var numVertices: Int;
	public var firstIndex: Int;
	public var numIndexes: Int;
	public var lightMapIndex: Int;
	public var lightMapStart: Vector<Int>;
	public var lightMapSize: Vector<Int>;
	public var lightMapOrigin: Vector<Float>;
	public var lightMapVectors: Vector<Vector<Float>>;
	public var normal: Vector<Float>;
	public var size: Vector<Int>;
}

// Lightmaps
@:structInit class BSPLightMapDef
{
	public var map: Vector<Vector<Vector<Int>>>; // ubyte[128][128][3]
}

// LightVols
@:structInit class BSPLightVolDef
{
	public var ambient: Vector<Int>; // ubyte[3]
	public var directional: Vector<Int>; // ubyte[3]
	public var dir: Vector<Int>; // ubyte[2]
}

// VisData
@:structInit class BSPVisDataDef
{
	public var numVectors: Int = 0;
	public var sizeVectors: Int = 0;
	public var vectors: Vector<Int> = null; // ubyte[n_vecs * sz_vecs]
}

// Patches (Generated)

@:structInit class CPatch_t
{
	public var checkcount: Int = 0;
	public var surfaceFlags: Int = 0;
	public var contentFlags: Int = 0;
	public var pc: PatchCollide_t = {};
}

@:structInit class PatchPlane_t
{
	public var plane: Vector<Int>;
	public var signBits: Int; // signx + (signy<<1) + (signz<<2), used as lookup during collision
}

@:structInit class Facet_t
{
	public var surfacePlane: Int = 0;
	public var numBorders: Int = 0;  // 3 or four + 6 axial bevels + 4 or 3 * 4 edge bevels
	public var borderPlanes: Vector<Int> = null; // All 4+6+16
	public var borderInwards: Vector<Int> = null;
	public var borderNoAdjust: Vector<Bool> = null;
}

@:structInit class CGrid_t
{
	public var width: Int;
	public var height: Int;
	public var wrapWidth: Bool;
	public var wrapHeight: Bool;
	public var points: Vector<Vector<h3d.Vector4>>;
}

@:structInit class PatchCollide_t
{
	public var bounds: Vector<Float> = null;
	public var numPlanes: Int = 0;
	public var planes: Vector<PatchPlane_t> = null;
	public var numFacets: Int = 0;
}


enum abstract MapSurfaceType_t(Int) from Int to Int {
	public var MST_BAD = 0;
	public var MST_PLANAR = 1;
	public var MST_PATCH = 2;
	public var MST_TRIANGLE_SOUP = 3;
	public var MST_FLARE = 4;
}




// Root
@:structInit class BSPFileDef
{
	public var header: DHeader_t = {};
	public var entities: String = null;
	public var shaders: Vector<DShader_t> = null;
	public var planes: Vector<DPlane_t> = null;
	public var nodes: Vector<DNode_t> = null;
	public var leafs: Vector<DLeaf_t> = null;
	public var leafFaces: Vector<Int> = null;
	public var leafBrushes: Vector<Int> = null;
	public var models: Vector<DModel_t> = null;
	public var brushes: Vector<DBrush_t> = null;
	public var brushSides: Vector<DBrushSide_t> = null;
	public var vertices: Vector<DrawVert_t> = null;
	public var verticesRaw: Bytes = null;
	public var meshVerts: Vector<Int> = null;
	public var meshVertsRaw: Bytes = null;
	public var effects: Vector<BSPEffectDef> = null;
	public var surfaces: Vector<DSurface_t> = null;
	public var lightMaps: Vector<Pixels> = null;
	public var lightMapVols: Vector<BSPLightVolDef> = null;
	public var visData: BSPVisDataDef = {};
	public var patches: Vector<CPatch_t> = null;
	public var facets: Facet_t = null;

	//
	public var fileName: String;
}


class Q3BSPFile
{
	var fileName: String;
	var bytes: Bytes;
	public var file: BSPFileDef;

	public function new( fileName: String )
	{
		this.fileName = fileName;
	}

	public function addToWorld( world: World )
	{
		Q3BSPEntities.spawnEntities( file, world );
	}

	public function load()
	{
		var resource = hxd.Res.loader.load( fileName );
		bytes = resource.entry.getBytes();

		file = { fileName: fileName};

		loadHeader();
		loadEntities();
		loadTextures();
		loadPlanes();
		loadNodes();
		loadLeafs();
		loadLeafFaces();
		loadLeafBrushes();
		loadModels();
		loadBrushes();
		loadBrushSides();
		loadVertices();
		loadMeshVerts();
		loadEffects();
		loadFaces();
		loadLightMaps();
		loadLightVols();
		loadVisData();
		loadPatchData();
	}

	function loadHeader()
	{
		file.header = {
			magic: bytes.getString(0,4),
			version: bytes.getInt32(4),
			dirEntries: new Vector<Lump_t>(17)
		};

		for( i in 0 ... 17 )
		{
			var pos = 8 + i * 8;
			var lump: Lump_t = {
				offset: bytes.getInt32(pos),
				length: bytes.getInt32(pos + 4 ),
			};
			file.header.dirEntries[i] = lump;
		}
	}

	/**
	 * Entities
	 *
		string[length]	ents	Entity descriptions, stored as a string.
	 */
	function loadEntities()
	{
		var dirEntry = file.header.dirEntries[0];
		file.entities = bytes.getString(dirEntry.offset, dirEntry.length);
		//trace(file.entities);
	}

	/**
	 * Textures
	 *
		string[64]	name		Texture name.
		int			flags		Surface flags.
		int			contents	Content flags.
	 */
	function loadTextures()
	{
		var dirEntry = file.header.dirEntries[1];

		var entrySize = 72;  // Size = 64 + 4 + 4
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.shaders = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			var shader: DShader_t =  {
				shader: bytes.getString(pos,64),
				surfaceFlags: bytes.getInt32(pos+64),
				contentFlags: bytes.getInt32(pos+68)
			};

			file.shaders[i] = shader;
		}
	}

	/**
	 * Planes
	 *
		float[3]	normal	Plane normal.
		float		dist	Distance from origin to plane along normal.
	 */
	function loadPlanes()
	{
		var dirEntry = file.header.dirEntries[2];

		var entrySize = 16;  // Size =  4 * 3 + 4
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.planes = new Vector(numEntries);

		var mconv = new h3d.Matrix();
		mconv.loadValues([
			-1, 0,  0, 0,
			0, 1, 0, 0,
			0, 0,  1, 0,
			0, 0, 0, 1
		]);

		var vconv = new h3d.Vector();

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			vconv.set(
				bytes.getFloat(pos),
				bytes.getFloat(pos + 4),
				bytes.getFloat(pos + 8 )
			);

			vconv *= mconv;

			var plane: DPlane_t = {
				normal: Vector.fromData([
					vconv.x,
					vconv.y,
					vconv.z
				]),
				dist: bytes.getFloat(pos+12)
			};
			file.planes[i] = plane;
		}
	}

	/**
	 * Nodes
	 *
		int 	plane		Plane index.
		int[2] 	children	Children indices. Negative numbers are leaf indices: -(leaf+1).
		int[3] 	mins		Integer bounding box min coord.
		int[3] 	maxs		Integer bounding box max coord.
	 */
	function loadNodes()
	{
		var dirEntry = file.header.dirEntries[3];

		var entrySize = 36;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.nodes = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			var node: DNode_t = {
				planeNum: bytes.getInt32(pos),
				children: Vector.fromData([
					bytes.getInt32(pos+4),
					bytes.getInt32(pos+8)
				]),
				mins: Vector.fromData([
					bytes.getInt32(pos+12),
					bytes.getInt32(pos+16),
					bytes.getInt32(pos+20)
				]),
				maxs: Vector.fromData([
					bytes.getInt32(pos+24),
					bytes.getInt32(pos+28),
					bytes.getInt32(pos+32)
				])
			};

			file.nodes[i] = node;
		}
	}

	/**
	 * Leafs
	 *

		int 	cluster			Visdata cluster index.
		int 	area			Areaportal area.
		int[3] 	mins			Integer bounding box min coord.
		int[3] 	maxs			Integer bounding box max coord.
		int 	leafface		First leafface for leaf.
		int 	n_leaffaces		Number of leaffaces for leaf.
		int 	leafbrush		First leafbrush for leaf.
		int 	n_leafbrushes	Number of leafbrushes for leaf.
	 */
	function loadLeafs()
	{
		var dirEntry = file.header.dirEntries[4];

		var entrySize = 48;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.leafs = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;
			var leaf: DLeaf_t = {
				cluster: bytes.getInt32(pos),
				area: bytes.getInt32(pos+4),
				mins: Vector.fromData([
					bytes.getInt32(pos+8),
					bytes.getInt32(pos+12),
					bytes.getInt32(pos+26)
				]),
				maxs: Vector.fromData([
					bytes.getInt32(pos+20),
					bytes.getInt32(pos+24),
					bytes.getInt32(pos+28)
				]),
				firstLeafSurface: bytes.getInt32(pos+32),
				numLeafSurfaces: bytes.getInt32(pos+36),
				firstLeafBrush: bytes.getInt32(pos+40),
				numLeafBrushes: bytes.getInt32(pos+44),
			};
			file.leafs[i] = leaf;
		}

	}

	/**
	 * Leaf Faces
	 *
		int		face		Face index.
	 */
	function loadLeafFaces()
	{
		var dirEntry = file.header.dirEntries[5];

		var entrySize = 4;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.leafFaces = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;
			file.leafFaces[i] = bytes.getInt32(pos);
		}
	}

	/**
	 * Leaf Brushes
	 *
		int		face		Face index.
	 */
	 function loadLeafBrushes()
	{
		var dirEntry = file.header.dirEntries[6];

		var entrySize = 4;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.leafBrushes = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;
			file.leafBrushes[i] = bytes.getInt32(pos);
		}
	}

	/**
	 * Models
	 *

		float[3]	 mins		Bounding box min coord.
		float[3]	 maxs		Bounding box max coord.
		int			 face		First face for model.
		int			 n_faces	Number of faces for model.
		int			 brush		First brush for model.
		int			 n_brushes	Number of brushes for model.
	*/
	function loadModels()
	{
		var dirEntry = file.header.dirEntries[7];

		var entrySize = 40;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.models = new Vector(numEntries);

		var mconv = new h3d.Matrix();
		mconv.loadValues([
			-1, 0,  0, 0,
			0, 1, 0, 0,
			0, 0,  1, 0,
			0, 0, 0, 1
		]);

		var vconvmin = new h3d.Vector();
		var vconvmax = new h3d.Vector();

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			vconvmin.set(
				bytes.getFloat(pos),
				bytes.getFloat(pos+4),
				bytes.getFloat(pos+8)
			);

			vconvmax.set(
				bytes.getFloat(pos+12),
				bytes.getFloat(pos+16),
				bytes.getFloat(pos+20)
			);

			vconvmin *= mconv;
			vconvmax *= mconv;

			var model: DModel_t = {
				mins: Vector.fromData([
					vconvmax.x, vconvmin.y, vconvmin.z
				]),
				maxs: Vector.fromData([
					vconvmin.x, vconvmax.y, vconvmax.z
				]),
				firstSurface: bytes.getInt32(pos+24),
				numSurfaces: bytes.getInt32(pos+28),
				firstBrush: bytes.getInt32(pos+32),
				numBrushes: bytes.getInt32(pos+36),
			};
			file.models[i] = model;
		}

	}

	/**
	 * Brushes
	 *

		int 	brushside		First brushside for brush.
		int 	n_brushsides	Number of brushsides for brush.
		int 	texture			Texture index.
	*/
	function loadBrushes()
	{
		var dirEntry = file.header.dirEntries[8];

		var entrySize = 12;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.brushes = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;
			var brush: DBrush_t = {
				firstSide: bytes.getInt32(pos),
				numSides: bytes.getInt32(pos+4),
				shaderNum: bytes.getInt32(pos+8)
			};
			file.brushes[i] = brush;
		}
	}

	/**
	 * Brush Sides
	 *

		int 	plane		Plane index.
		int 	texture		Texture index.
	*/
	function loadBrushSides()
	{
		var dirEntry = file.header.dirEntries[9];

		var entrySize = 8;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.brushSides = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;
			var brushSide: DBrushSide_t =  {
				planeNum: bytes.getInt32(pos),
				shaderNum: bytes.getInt32(pos+4)
			};
			file.brushSides[i] = brushSide;
		}
	}

	/**
	 * Vertices
	 *

		float[3] 		position	Vertex position.
		float[2][2] 	texcoord	Vertex texture coordinates. 0=surface, 1=lightmap.
		float[3] 		normal		Vertex normal.
		ubyte[4] 		color		Vertex color. RGBA.
	 */
	function loadVertices()
	{
		var dirEntry = file.header.dirEntries[10];

		var entrySize = 44;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.vertices = new Vector(numEntries);
		file.verticesRaw = bytes.sub(dirEntry.offset, dirEntry.length);

		var mconv = new h3d.Matrix();
		mconv.loadValues([
			-1, 0,  0, 0,
			0, 1, 0, 0,
			0, 0,  1, 0,
			0, 0, 0, 1
		]);

		var vconv = new h3d.Vector();


		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			vconv.set(
				bytes.getFloat(pos),
				bytes.getFloat(pos+4),
				bytes.getFloat(pos+8)
			);
			vconv *= mconv;

			var vertex: DrawVert_t = {

				xyz: Vector.fromData([
					vconv.x,
					vconv.y,
					vconv.z
				]),
				st: Vector.fromData([
					bytes.getFloat(pos+12),
					bytes.getFloat(pos+16),
				]),
				lightmap: Vector.fromData([
					bytes.getFloat(pos+20),
					bytes.getFloat(pos+24),
				]),
				normal: Vector.fromData([
					bytes.getFloat(pos+28),
					bytes.getFloat(pos+32),
					bytes.getFloat(pos+36)
				]),
				color: Vector.fromData([
					bytes.get(pos+40),
					bytes.get(pos+41),
					bytes.get(pos+42),
					bytes.get(pos+43)
				]),
			};

			file.vertices[i] = vertex;
		}

	}

	/**
	 * Mesh Vertices
	 *
		int 	offset		Vertex index offset, relative to first vertex of corresponding face.
	 */
	function loadMeshVerts()
	{
		var dirEntry = file.header.dirEntries[11];

		var entrySize = 4;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.meshVerts = new Vector(numEntries);

		#if resample16

		var meshVertsRaw = bytes.sub(dirEntry.offset, dirEntry.length);

		// resample to 16bit
		var meshVertsOut = Bytes.alloc(numEntries*2);
		var meshVerts16: hxd.impl.UncheckedBytes = meshVertsOut;
		var meshVerts32: hxd.impl.UncheckedBytes = meshVertsRaw;

		// fix format
		for ( x in 0 ... numEntries )
		{
			meshVerts16[x*2] = meshVerts32[x*4];
			meshVerts16[x*2+1] = meshVerts32[x*4+1];
		}

		file.meshVertsRaw = meshVertsOut;

		#else
		file.meshVertsRaw = bytes.sub(dirEntry.offset, dirEntry.length);
		#end

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;
			file.meshVerts[i] = bytes.getInt32(pos);
		}
	}

	/**
	 * Effects
	 *
		string[64] 	name		Effect shader.
		int			 brush		Brush that generated this effect.
		int			 unknown	Always 5, except in q3dm8, which has one effect with -1.
	 */
	function loadEffects()
	{
		var dirEntry = file.header.dirEntries[12];

		var entrySize = 72;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.effects = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			var effect: BSPEffectDef = {
				name: bytes.getString( pos, 64 ),
				brush: bytes.getInt32( pos+64 ),
				unknown: bytes.getInt32( pos+68 ),
			};

			file.effects[i] = effect;
		}

	}

	/**
	 * Faces
	 *
		int 			texture			Texture index.
		int 			effect			Index into lump 12 (Effects), or -1.
		int 			surfaceType			Face type. 1=polygon, 2=patch, 3=mesh, 4=billboard
		int 			vertex			Index of first vertex.
		int 			n_vertexes		Number of vertices.
		int 			meshvert		Index of first meshvert.
		int 			n_meshverts		Number of meshverts.
		int 			lm_index		Lightmap index.
		int[2] 			lm_start		Corner of this face's lightmap image in lightmap.
		int[2] 			lm_size			Size of this face's lightmap image in lightmap.
		float[3] 		lm_origin		World space origin of lightmap.
		float[2][3]		lm_vecs			World space lightmap s and t unit vectors.
		float[3] 		normal			Surface normal.
		int[2] 			size			Patch dimensions.
	 */
	function loadFaces()
	{
		var dirEntry = file.header.dirEntries[13];

		var entrySize = 104;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.surfaces = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			var surface: DSurface_t = {
				shaderNum: bytes.getInt32( pos ),
				fogNum: bytes.getInt32( pos + 4 ),
				surfaceType: bytes.getInt32( pos + 8 ),
				firstVertex: bytes.getInt32( pos + 12 ),
				numVertices: bytes.getInt32( pos + 16 ),
				firstIndex: bytes.getInt32( pos + 20 ),
				numIndexes: bytes.getInt32( pos + 24 ),
				lightMapIndex: bytes.getInt32( pos + 28 ),
				lightMapStart: Vector.fromData([
					bytes.getInt32(pos + 32),
					bytes.getInt32(pos+ 36)
				]),
				lightMapSize: Vector.fromData([
					bytes.getInt32(pos + 40),
					bytes.getInt32(pos+ 44)
				]),
				lightMapOrigin: Vector.fromData([
					bytes.getFloat(pos + 48),
					bytes.getFloat(pos+ 52),
					bytes.getFloat(pos+ 56)
				]),
				lightMapVectors: Vector.fromData([
					Vector.fromData([
						bytes.getFloat(pos+60),
						bytes.getFloat(pos+64),
						bytes.getFloat(pos+68),
					]),
					Vector.fromData([
						bytes.getFloat(pos+72),
						bytes.getFloat(pos+76),
						bytes.getFloat(pos+80),
					])
				]),
				normal: Vector.fromData([
					bytes.getFloat(pos+84),
					bytes.getFloat(pos+88),
					bytes.getFloat(pos+92)
				]),
				size: Vector.fromData([
					bytes.getInt32(pos+96),
					bytes.getInt32(pos+100)
				])
			};

			file.surfaces[i] = surface;
		}
	}

	/**
	 * Light Maps
	 *
		ubyte[128][128][3] 	map		Lightmap color data. RGB.
	 */
	function loadLightMaps()
	{
		var dirEntry = file.header.dirEntries[14];

		var entrySize = 128*128*3;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.lightMaps = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			var pixels = Pixels.alloc(128,128, PixelFormat.RGBA );
			var rgb8pixels: hxd.impl.UncheckedBytes = bytes.sub(pos, entrySize);
			var rgbapixels: hxd.impl.UncheckedBytes = pixels.bytes;

			// fix format
			var rgbCursor = 0;
			var rgbaCursor = 0;
			for ( x in 0...128 * 128 ) {
				var a = 255;
				var rgb = brighten(rgb8pixels[rgbCursor++], rgb8pixels[rgbCursor++], rgb8pixels[rgbCursor++]);
				rgbapixels[rgbaCursor++] = rgb[0];
				rgbapixels[rgbaCursor++] = rgb[1];
				rgbapixels[rgbaCursor++] = rgb[2];
				rgbapixels[rgbaCursor++] = a;
			}


			file.lightMaps[i] = pixels;
		}

	}

	function brighten(r: Int, g: Int, b: Int): Vector<Int>
	{
		var gamma = 2;

		var ir: Int, ig : Int, ib : Int;

		ir = r << gamma;
		ig = g << gamma;
		ib = b << gamma;

		var iMax  = Math.max( ir, Math.max( ig, ib ) );
		if( iMax > 255 )
		{
			var factor = 255 / iMax;
			ir = cast ir * factor;
			ig = cast ig * factor;
			ib = cast ib * factor;
		}

		return Vector.fromData([ir, ig, ib]);
	}

	/**
	 * Light map volumes
	 *
		ubyte[3]	 ambient		Ambient color component. RGB.
		ubyte[3]	 directional	Directional color component. RGB.
		ubyte[2]	 dir			Direction to light. 0=phi, 1=theta.
	 */
	function loadLightVols()
	{
		var dirEntry = file.header.dirEntries[15];

		var entrySize = 8;
		var numEntries : Int = cast dirEntry.length / entrySize;

		file.lightMapVols = new Vector(numEntries);

		for( i in 0 ... numEntries )
		{
			var pos = dirEntry.offset + i * entrySize;

			var vol : BSPLightVolDef = {
				ambient: Vector.fromData([
					bytes.get(pos),
					bytes.get(pos+1),
					bytes.get(pos+2),
				]),
				directional: Vector.fromData([
					bytes.get(pos+3),
					bytes.get(pos+4),
					bytes.get(pos+5),
				]),
				dir: Vector.fromData([
					bytes.get(pos+6),
					bytes.get(pos+7),
				])
			};

			file.lightMapVols[i] = vol;
		}
	}

	/**
	 * Vis Data
	 *
		int						 	n_vecs		Number of vectors.
		int 						sz_vecs		Size of each vector, in bytes.
		ubyte[n_vecs * sz_vecs] 	vecs		Visibility data. One bit per cluster per vector.
	 */
	function loadVisData()
	{

		var dirEntry = file.header.dirEntries[16];

		if( dirEntry.length == 0 )
		{
			file.visData = {
				numVectors: 0,
				sizeVectors: 0,
				vectors: null
			};
			return;
		}

		var pos = dirEntry.offset;

		var numVectors = bytes.getInt32(pos);
		var sizeVectors = bytes.getInt32(pos+4);

		var vectors = new Vector(numVectors * sizeVectors );

		for( i in 0...numVectors * sizeVectors )
		{
			vectors[i] = bytes.get(pos + 8 + i);
		}

		file.visData = {
			numVectors: numVectors,
			sizeVectors: sizeVectors,
			vectors: vectors
		};


	}

	/*
	* Patches
	*/
	function loadPatchData()
	{

		var dv: DrawVert_t, dv_p: DrawVert_t;
		var surface: DSurface_t;
		var count: Int;
		var c: Int;

		var points: Vector<Vector<Float>>;
		var width: Int, height: Int;

		count = file.surfaces.length;

		file.patches = new Vector(file.vertices.length);

		// scan through all surfaces
		for( i in 0 ... count )
		{
			surface = file.surfaces[i];
			var patch: CPatch_t = {};
			//dv = file.vertices[i];

			if( surface.surfaceType != MST_PATCH )
				continue; // Ignore other surfaces

			// FIXME check for non-colliding patches

			width = surface.size[0];
			height = surface.size[1];

			c = width * height;

			if( c > 1024) // MAX_PATCH_VERTS
				Utils.error("ParseMesh: MAX_PATCH_VERTS");



			points = new Vector(c);

			for( j in 0...c)
			{
				var dv_p = file.vertices[ surface.firstVertex + j ];
				points[j] = new Vector(3);
				points[j][0] = dv_p.xyz[0];
				points[j][1] = dv_p.xyz[1];
				points[j][2] = dv_p.xyz[2];
			}

			var shaderNum = surface.shaderNum;
			patch.contentFlags = file.shaders[shaderNum].contentFlags;
			patch.surfaceFlags = file.shaders[shaderNum].surfaceFlags;

			// Create the internal facet structure


		}
	}

	function generatePatchCollide(width: Int, height: Int, points: Vector<Float> )
	{

		if( width <= 2 || height <= 2 || points.length == 0 )
		{
			Utils.error("generatePatchCollide: Even sizes are invalid for quadratic meshes");
		}

		if( width > 129 || height > 129)
		{
			Utils.error("generatePatchCollide: source is > MAX_GRID_SIZE");
		}

		// build a grid


	}


}