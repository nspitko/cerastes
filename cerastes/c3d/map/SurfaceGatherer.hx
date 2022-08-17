package cerastes.c3d.map;

import cerastes.c3d.map.Data.FaceVertex;
import cerastes.c3d.map.Data.WorldspawnLayer;
import cerastes.c3d.map.Data.MapData;
import cerastes.c3d.map.Data.Surface;
import cerastes.c3d.map.Data.SurfaceSplitType;

class SurfaceGatherer
{

	var splitType: SurfaceSplitType;
	var entityFilterIdx = -1;
	var textureFilterIdx = -1;
	var brushFilterTextureIdx = -1;
	var faceFilterTextureIdx = -1;
	var filterWorldspawnLayers: Bool;

	public var surfaces: Array<Surface>;

	var data: MapData;

	public function new( d: MapData )
	{
		data = d;
	}

	public function resetParams()
	{
		splitType = SST_NONE;
		entityFilterIdx = -1;
		textureFilterIdx = -1;
		brushFilterTextureIdx = -1;
		faceFilterTextureIdx = -1;
		filterWorldspawnLayers = true;
	}


	public function setSplitType( type: SurfaceSplitType )
	{
		splitType = type;
	}

	public function setEntityIndexFilter( entityIdx: Int )
	{
		entityFilterIdx = entityIdx;
	}

	public function setTextureFilter( name: String )
	{
		textureFilterIdx = data.findTexture( name );
	}

	public function setBrushFilterTexture( name: String )
	{
		brushFilterTextureIdx = data.findTexture( name );
	}

	public function setFaceFilterTexture( name: String )
	{
		faceFilterTextureIdx = data.findTexture( name );
	}

	public function setWorldspawnLayerFilter( filter: Bool )
	{
		filterWorldspawnLayers = filter;
	}

	function filterEntity( entityIdx: Int )
	{
		var ents = data.entities;
		var ent = ents[entityIdx];

		// omit filtered entity indices
		if( entityFilterIdx != -1 && entityIdx == entityFilterIdx )
		{
			return true;
		}

		return false;
	}

	function filterBrush( entityIdx: Int, brushIdx: Int )
	{
		var ents = data.entities;
		var brush = ents[entityIdx].brushes[brushIdx];

		if( brushFilterTextureIdx != -1 )
		{
			var fullytextured = true;
			for( f in 0 ... brush.faces.length )
			{
				var face = brush.faces[f];
				if( face.textureIdx != brushFilterTextureIdx )
				{
					fullytextured = false;
					break;
				}
			}

			if( fullytextured )
				return true;
		}

		// Omit brushes that are part of a worldspawn layer
		for( f in  0 ... brush.faces.length )
		{
			var face = brush.faces[f];
			for( l in 0 ... data.worldspawnLayers.length )
			{
				var layer = data.worldspawnLayers[l];
				if( face.textureIdx == layer.textureIdx )
					return filterWorldspawnLayers;
			}
		}

		return false;
	}

	function filterFace( entityIdx: Int, brushIdx: Int, faceIdx: Int )
	{
		var ents = data.entities;
		var face = ents[entityIdx].brushes[brushIdx].faces[faceIdx];
		var faceGeo = data.entityGeo[entityIdx].brushes[brushIdx].faces[faceIdx];

		// omit faces with less than 3 verts
		if( faceGeo.vertices.length < 3 )
			return true;

		// omit faces that are textures with skip
		if( faceFilterTextureIdx != -1 && face.textureIdx == faceFilterTextureIdx )
			return true;

		// omit filtered texture indices
		if( textureFilterIdx != -1 && face.textureIdx != textureFilterIdx )
			return true;

		return false;
	}

	function resetState()
	{
		surfaces = [];
	}



	public function run( )
	{
		resetState();

		var indexOffset = 0;
		var surface: Surface = null;

		if( splitType == SST_NONE )
		{
			indexOffset = 0;
			surface = addSurface();
		}

		for( e in  0 ... data.entities.length )
		{
			var entity = data.entities[e];
			var entityGeo = data.entityGeo[e];

			if( filterEntity(e) )
				continue;

			if( splitType == SST_ENTITY )
			{
				if( entity.spawnType == EST_MERGE_WORLDSPAWN )
				{
					addSurface();
					surface = surfaces[0];
					indexOffset = surface.vertices.length;
				}
				else
				{
					surface = addSurface();
					indexOffset = surface.vertices.length;
				}

			}

			for( b in  0 ... entity.brushes.length )
			{
				var brush = entity.brushes[b];
				var brushGeo = entityGeo.brushes[b];

				if( filterBrush(e,b) )
					continue;

				if( splitType == SST_BRUSH )
				{
					indexOffset = 0;
					surface = addSurface();
				}

				for( f in 0 ... brush.faces.length )
				{
					var faceGeo = brushGeo.faces[f];

					if( filterFace( e, b, f ) )
						continue;

					for( v in 0 ... faceGeo.vertices.length )
					{
						var faceVertex = faceGeo.vertices[v];
						// Copy!!
						var vertex: FaceVertex = {
							vertex: faceVertex.vertex.clone(),
							normal: faceVertex.normal,
							tangent: faceVertex.tangent,
							uv: faceVertex.uv
						};

						if( entity.spawnType == EST_ENTITY || entity.spawnType == EST_GROUP )
							vertex.vertex = vertex.vertex.sub( entity.center );

						// @todo hackhack invert X
						vertex.vertex.x = -vertex.vertex.x;

						surface.vertices.push(vertex);
					}

					for( i in 0 ... faceGeo.indices.length )
					{
						surface.indices.push( indexOffset + faceGeo.indices[i]);
					}

					indexOffset += faceGeo.vertices.length;
				}
			}
		}

	}

	function addSurface()
	{
		var surface: Surface = {};
		surfaces.push(surface);

		return surface;
	}

	// public accessors
	public function gatherConvexCollisionSurfaces( entityFilter: Int = -1, filterLayers: Bool = false )
	{
		resetParams();
		setSplitType(SST_BRUSH);
		setEntityIndexFilter( entityFilter );
		setWorldspawnLayerFilter(filterLayers);

		run();
	}

	public function gatherConcaveCollisionSurfaces( entityFilter: Int = -1, filterLayers: Bool = false )
	{
		resetParams();
		setSplitType(SST_NONE);
		setEntityIndexFilter( entityFilter );
		setWorldspawnLayerFilter(filterLayers);

		run();
	}

	public function gatherTextureSurfaces( textureName: String = null, brushFilter: String = null, faceFilter: String = null, filterLayers = false )
	{
		resetParams();
		setSplitType( SST_ENTITY );
		setTextureFilter( textureName );
		setBrushFilterTexture( brushFilter );
		setFaceFilterTexture( faceFilter );
		setWorldspawnLayerFilter( filterLayers );

		run();
	}
}