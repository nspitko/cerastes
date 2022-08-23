package cerastes.c3d.map;


import h3d.col.Point;
import cerastes.c3d.map.Data.EntitySpawnType;
import h3d.col.Bounds;

#if mapcompiler
import cerastes.c3d.map.Data.TextureData;
import cerastes.c3d.map.Data.Surface;
#end

@:structInit
class Vector3Def implements hxbitmini.Serializable
{
	@:s public var x: Float = 0;
	@:s public var y: Float = 0;
	@:s public var z: Float = 0;
}

@:structInit
class TextureDef implements hxbitmini.Serializable
{
	@:s public var name: String;
	@:s public var width: Int;
	@:s public var height: Int;
}

@:structInit
class BoundsDef implements hxbitmini.Serializable
{
	@:s public var xMin : Float = 1e20;
	@:s public var xMax : Float = -1e20;
	@:s public var yMin : Float = 1e20;
	@:s public var yMax : Float = -1e20;
	@:s public var zMin : Float = 1e20;
	@:s public var zMax : Float = -1e20;

	public inline function addPoint( px: Float, py: Float, pz: Float )
	{
		if( px < xMin ) xMin = px;
		if( px > xMax ) xMax = px;
		if( py < yMin ) yMin = py;
		if( py > yMax ) yMax = py;
		if( pz < zMin ) zMin = pz;
		if( pz > zMax ) zMax = pz;
	}
}


@:structInit
class BrushDef implements hxbitmini.Serializable
{
	@:s public var buf: Array<Float> = [];
	@:s public var indexes: Array<Int> = [];
	@:s public var indexOffsets: Array<Int> = [];
	@:s public var indexCounts: Array<Int> = [];
	@:s public var bounds: BoundsDef = {};
	@:s public var textures: Array<TextureDef> = [];
	@:s public var center: Vector3Def = {};

	@:s var idxOffset = 0;
	@:s var vertOffset = 0;
	@:s var idxCount = 0;

	#if mapcompiler
	public function addSurfaces( surfaces: Array<Surface>, tex: TextureData )
	{
		for( surface in surfaces )
		{

			if( surface.vertices.length < 3 )
				continue;

			indexOffsets.push( idxOffset );

			for( v in surface.vertices )
			{
				// @todo: Need to be more consistent about where we flip shit.

				buf.push(-v.vertex.x);
				buf.push(v.vertex.y);
				buf.push(v.vertex.z);

				bounds.addPoint( -v.vertex.x, v.vertex.y, v.vertex.z );

				buf.push(-v.normal.x);
				buf.push(v.normal.y);
				buf.push(v.normal.z);

				buf.push(v.tangent.x);
				buf.push(v.tangent.y);
				buf.push(v.tangent.z);

				buf.push(v.uv.u);
				buf.push(v.uv.v);

				// Lightmap UVs (will be filled in later)
				buf.push(0);
				buf.push(0);
			}

			for( i in surface.indices )
				indexes.push(vertOffset + i);

			idxOffset += surface.indices.length;
			vertOffset += surface.vertices.length;
			idxCount += surface.indices.length;

			textures.push({
				name: tex.name,
				// @todo do we need to store this??
				width: tex.width,
				height: tex.height
			});

			indexCounts.push( idxCount );
			idxCount = 0;

		}
	}
	#end
}

@:structInit
class BrushCollisionDef implements hxbitmini.Serializable
{
	@:s public var vertices: Array<Float> = [];
	@:s public var indices: Array<Int> = [];

	#if mapcompiler

	public function addSurface( s: Surface )
	{
		if( s.indices.length < 3 )
			return;

		// @todo: dedupe verts; bullet will do it for us at runtime but
		// we should use a smarter interface and not just push
		// triangles.


		for( v in s.vertices )
		{
			vertices.push( -v.vertex.x );
			vertices.push( v.vertex.y );
			vertices.push( v.vertex.z );
		}

		for( i in s.indices )
		{
			indices.push(i);
		}

	}
	#end
}

@:structInit
class EntityDef implements hxbitmini.Serializable
{
	@:s public var props: Map<String, String> = [];
	@:s public var brush: BrushDef = {};
	@:s public var collisionBodies: Array<BrushCollisionDef> = [];
	@:s public var spawnType: EntitySpawnType = EST_ENTITY;
	@:s public var center: Vector3Def = {};

	public function getProperty( key: String, defaultVal: String = null )
	{
		if( props.exists( key ) )
			return props[key];
		return defaultVal;
	}

	public function getPropertyInt(key: String, defaultVal: Int = 0 )
	{
		if( props.exists( key ) )
			return Std.parseInt( props[key] );
		return defaultVal;
	}

	public function getPropertyFloat(key: String, defaultVal: Float = 0 )
	{
		if( props.exists( key ) )
			return Std.parseFloat( props[key] );
		return defaultVal;
	}

	public function getPropertyPoint(key: String, defaultVal: Point = null )
	{
		if( props.exists( key ) )
		{
			var bits = props[key].split(" ");
			return new h3d.col.Point(
				Std.parseFloat(bits[0]),
				Std.parseFloat(bits[1]),
				Std.parseFloat(bits[2])
			);
		}
		return defaultVal;
	}

	#if mapcompiler

	public function build( def: cerastes.c3d.map.Data.Entity, surfaceGatherer: SurfaceGatherer )
	{
		for( p in def.properties )
			props.set(p.key, p.value);

		var textures = [];

		spawnType = def.spawnType;
		center.x = -def.center.x;
		center.y = def.center.y;
		center.z = def.center.z;

		// @todo: Right now we assume all textured surfaces are the same;
		// need to consider surface flags for stuff like unlit, and store
		// for later stages like lightmapping!
		//
		// May make sense to create texture id permuations and treat these as
		// separate permutations in the parsing stage.

		// Build textured surfaces
		for( b in  0 ... def.brushes.length )
		{
			for( f in 0 ... def.brushes[b].faces.length )
			{
				var textureId = def.brushes[b].faces[f].textureIdx;
				if( !textures.contains(textureId ) )
					textures.push( textureId );
			}
		}

		var cls = def.getProperty("classname");

		// Geo brushes
		for( t in 0 ... textures.length )
		{
			var tex = @:privateAccess surfaceGatherer.data.getTexture(textures[t]);

			surfaceGatherer.surfaces = [];
			surfaceGatherer.setEntityIndexFilter( def.index );
			surfaceGatherer.gatherTextureSurfaces( tex.name, def.index );

			brush.addSurfaces(surfaceGatherer.surfaces, tex );

		}

		// Hack??
		if( def.brushes.length > 0 )
		{
			brush.center = {
				x: -def.brushes[0].center.x,
				y: def.brushes[0].center.y,
				z: def.brushes[0].center.z
			};
		}


		// Collision geo
		surfaceGatherer.gatherConvexCollisionSurfaces(def.index);
		var surfaces = surfaceGatherer.surfaces;
		for( s in surfaces )
		{
			if( s.vertices.length < 3 )
				continue;

			var b: BrushCollisionDef = {};
			b.addSurface(s);
			collisionBodies.push(b);
		}




	}

	#end
}

@:structInit
class MapFile implements hxbitmini.Serializable
{
	@:s public var version: Int = 1;
	@:s public var entities: Array<EntityDef> = [];
}