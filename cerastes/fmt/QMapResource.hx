package cerastes.fmt;

import cerastes.c3d.map.Data.Surface;
import haxe.io.BytesOutput;
import cerastes.c3d.map.Data.MapData;
import h3d.Vector;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;
import hxd.res.Loader;

import hxd.res.Resource;

class QMapResource extends Resource
{
	static var minVersion = 1;
	static var version = 1;

	var data: String; // @todo

	public function toObject(?parent = null)
	{

		return null;
	}

	public function writeMapData( data: MapData, file: String )
	{
		final output = new BytesOutput();

		var surfaceGatherer = new cerastes.c3d.map.SurfaceGatherer( data );

		// write header
		output.writeString("CMAP");
		output.writeInt32( version );
		output.writeInt32( data.entities.length );
		output.writeInt32( data.entityGeo.length );
		output.writeInt32( data.textures.length );
		output.writeInt32( data.worldspawnLayers.length );

		// encode entities
		var e = 0;
		for( e in 0 ... data.entities.length )
		{
			var ent = data.entities[e];
			// Entity header
			output.writeFloat( ent.center.x );
			output.writeFloat( ent.center.y );
			output.writeFloat( ent.center.z );
			output.writeInt32( ent.spawnType );
			output.writeInt32( ent.brushes.length );
			output.writeInt32( ent.properties.length );

/*
			switch( ent.spawnType )
			{
				case EST_WORLDSPAWN:
					for( t in 0 ... data.textures.length )
					{
						var tex = data.textures[t];
						var surfaces: Array<Surface> = [];
						for( b in 0 ... ent.brushes.length )
						{
							surfaceGatherer.gatherTextureSurfaces(tex.name, b);
							surfaces = surfaces.concat( surfaceGatherer.surfaces );
						}

					}

				case EST_MERGE_WORLDSPAWN: // Do nothing here; these will be grabbed when building worldspawn brushes

				default:
					throw ("STUB");

			}
*/
			output.writeInt32( -1 ); // No more surfaces
		}

	}

	function writeSurfaces( output: BytesOutput, surfaces: Array<Surface>, textureId: Int )
	{
		// Write all surfaces for this texture ID
		output.writeInt32( textureId );
		output.writeInt32( surfaces.length );
		for( s in 0 ... surfaces.length )
		{
			var surf = surfaces[s];
			output.writeInt32( surf.vertices.length );
			for( v in surf.vertices )
			{
				output.writeFloat( v.vertex.x );
				output.writeFloat( v.vertex.y );
				output.writeFloat( v.vertex.z );

				output.writeFloat( v.normal.x );
				output.writeFloat( v.normal.y );
				output.writeFloat( v.normal.z );

				output.writeFloat( v.tangent.x );
				output.writeFloat( v.tangent.y );
				output.writeFloat( v.tangent.z );

				output.writeFloat( v.uv.u );
				output.writeFloat( v.uv.v );

			}

			// indices
			output.writeInt32( surf.indices.length );
			for( i in surf.indices )
				output.writeInt32( i );
		}
	}

	public function getData()
	{
		if (data != null) return data;



		//var u = new haxe.Unserializer(entry.getText());
		//data = u.unserialize();

//		data = CDParser.parse( entry.getText(), CUIFile );

/*
		var parser = new json2object.JsonParser<CUIFile>(); // Creating a parser for Cls class
		parser.fromJson(entry.getText(), entry.name); // Parsing a string. A filename is specified for errors management
		data = parser.value; // Access the parsed class
		var errors:Array<json2object.Error> = parser.errors;
		for( e in errors )
		{
			Utils.warning(json2object.ErrorUtils.convertError(e) );
		}*/

		return data;
	}
}