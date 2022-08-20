package cerastes.c3d.map;
import h3d.Vector;
import h3d.col.Point;

// Ref https://github.com/QodotPlugin/libmap

typedef QTextureId = Int;

//
// Faces
//
@:structInit
class FacePoints
{
	public var v0: Point = new Point();
	public var v1: Point = new Point();
	public var v2: Point = new Point();
}

@:structInit
class StandardUV
{
	public var u: Float = 0;
	public var v: Float = 0;
}

@:structInit
class ValveTextureAxis
{
	public var axis: Point = new Point();
	public var offset: Float = 0;
}

@:structInit
class ValveUV
{
	public var u: ValveTextureAxis = {};
	public var v: ValveTextureAxis = {};
}

@:structInit
class FaceUVExtra
{
	public var rot: Float = 0;
	public var scaleX: Float = 0;
	public var scaleY: Float = 0;
}

@:structInit
class Face
{
	public var planePoints: FacePoints = {};
	public var planeNormal: Point = new Point();
	public var planeDist: Float = 0;

	public var textureIdx: Int = -1;

	public var isValveUV: Bool = false;
	public var uvStandard: StandardUV = {};
	public var uvValve: ValveUV = {};
	public var uvExtra: FaceUVExtra = {};
}

//
// Brushes
//

@:structInit
class Brush
{
	public var faces: Array<Face> = [];
	public var center: Point = new Point();
}

//
// Entities
//

@:structInit
class Property
{
	public var key: String = null;
	public var value: String = null;
}

@:enum
abstract EntitySpawnType(Int) from Int to Int
{
	public var EST_WORLDSPAWN			= 0;
	public var EST_MERGE_WORLDSPAWN		= 1;
	public var EST_ENTITY				= 2;
	public var EST_GROUP				= 3;
}


@:structInit
class Entity
{
	public var properties: Array<Property> = [];
	public var brushes: Array<Brush> = [];

	public var center: Point = new Point();
	public var spawnType: EntitySpawnType = EST_WORLDSPAWN;

	public var index: Int = -1;

	public function getProperty(key: String, defaultVal: String = null )
	{
		for( p in properties )
		{
			if( p.key == key )
				return p.value;
		}

		return defaultVal;
	}

	public function getPropertyInt(key: String, defaultVal: Int = 0 )
	{
		for( p in properties )
		{
			if( p.key == key )
				return Std.parseInt( p.value );
		}

		return defaultVal;
	}

	public function getPropertyFloat(key: String, defaultVal: Float = 0 )
	{
		for( p in properties )
		{
			if( p.key == key )
				return Std.parseFloat( p.value );
		}

		return defaultVal;
	}

	public function getPropertyPoint(key: String, defaultVal: Point = null )
	{
		for( p in properties )
		{
			if( p.key == key )
			{
				var bits = p.value.split(" ");
				return new h3d.col.Point(
					Std.parseFloat(bits[0]),
					Std.parseFloat(bits[1]),
					Std.parseFloat(bits[2])
				);
			}
		}

		return defaultVal;
	}

	public function setProperty( key: String, value: String )
	{
		for( p in properties )
		{
			if( p.key == key )
			{
				p.value = value;
				return;
			}
		}

		properties.push( { key: key, value: value } );
	}
}

//
// Entity geo
//
@:structInit
class VertexUV
{
	public var u: Float = 0;
	public var v: Float = 0;
}

@:structInit
class FaceVertex
{
	public var vertex: Point;
	public var normal: Point;
	public var uv: VertexUV;
	public var tangent: Point;
}


@:structInit
class FaceGeometry
{
	public var vertices: Array<FaceVertex> = [];
	public var indices: haxe.ds.Vector<Int> = null;
}

@:structInit
class BrushGeometry
{
	public var faces: haxe.ds.Vector<FaceGeometry> = null;
}

@:structInit
class EntityGeometry
{
	public var brushes: haxe.ds.Vector<BrushGeometry> = null;
}

//
// Surfaces
//

@:enum
abstract SurfaceSplitType(Int) from Int to Int
{
	public var SST_NONE		= 0;
	public var SST_ENTITY	= 1;
	public var SST_BRUSH	= 2;
}

@:structInit
class Surface
{
	public var vertices: Array<FaceVertex> = [];
	public var indices: Array<Int> = [];
}

//
// MapData
//

@:structInit
class TextureData
{
	public var name: String = null;
	public var width: Int = 0;
	public var height: Int = 0;
}

@:structInit
class WorldspawnLayer
{
	public var textureIdx: Int = 0;
	public var buildVisuals: Bool = false;
}

@:structInit
class MapData
{
	public var entities: Array<Entity> = [];
	public var entityGeo: haxe.ds.Vector<EntityGeometry> = null;
	public var textures: Array<TextureData> = [];

	public var worldspawnLayers: Array<WorldspawnLayer> = [];

	public function registerWorldspawnLayer( name: String, buildVisuals: Bool )
	{
		var layer: WorldspawnLayer = {};
		worldspawnLayers.push(layer);

		layer.textureIdx = findTexture( name );
		layer.buildVisuals = buildVisuals;
	}

	public static function resolveTextureName( name: String )
	{
		if(name == "__TB_empty")
			name = "editor/__TB_empty";

		if(  hxd.Res.loader.exists( 'textures/${name}.material' ) )
			return 'textures/${name}.material';

		if(  hxd.Res.loader.exists( 'textures/${name}.png' ) )
			return 'textures/${name}.png';

		// HACK FALLBACK
		var fname = 'textures/quake/${name.toLowerCase()}.png';

		if( hxd.Res.loader.exists( fname ) )
			return fname;

		return null;

	}

	// ----------------------------------------------------------------------------
	public function registerTexture( name: String )
	{
		for( i in  0 ... textures.length )
		{
			if( textures[i].name == name )
				return i;
		}

		var t: TextureData = {};
		textures.push(t);

		t.name = name;

		var file = resolveTextureName( name );

		if( file != null && hxd.Res.loader.exists( file ) )
		{
			var actualTexture = hxd.Res.loader.load( file ).toTexture();

			t.width = actualTexture.width;
			t.height = actualTexture.height;
		}
		else
		{
			Utils.warning('Could not find referenced texture ${name}');
			t.width = 32;
			t.height = 32;
		}


		return textures.length - 1;
	}

	public function findWorldspawnLayer( textureIdx: QTextureId )
	{
		for( l in worldspawnLayers )
		{
			if( l.textureIdx == textureIdx )
				return l;
		}

		return null;
	}

	public function getTexture( id: QTextureId )
	{
		return textures[id];
	}

	public function findTexture( name: String ) : QTextureId
	{
		for( i in  0 ... textures.length )
		{
			if( textures[i].name == name )
				return i;
		}
		return -1;
	}

	public function setSpawnTypeByClassName( key: String, spawnType: EntitySpawnType )
	{
		for( e in 0 ... entities.length )
		{
			var ent = entities[e];
			if( ent.properties.length == 0 )
				continue;

			var cls = ent.getProperty("classname");
			if( cls == key )
			{
				ent.spawnType = spawnType;
			}
		}
	}

	public function printEntities()
	{
		for( e in 0 ... entities.length )
		{
			var entity = entities[e];
			trace('Entity ${e}');
			for( b  in 0 ... entity.brushes.length )
			{
				var brush = entity.brushes[b];
				trace('	Brush ${b}');
				trace('		Face count: ${brush.faces.length}');
				for( f in 0 ... brush.faces.length )
				{
					trace('		Face ${f}');
					var face = brush.faces[f];
					trace('			(${face.planePoints.v0}) (${face.planePoints.v1}) (${face.planePoints.v2})');
					trace('			${getTexture(face.textureIdx).name} ${face.uvStandard.u} ${face.uvStandard.v}');
					trace('			${face.uvExtra.rot} ${face.uvExtra.scaleX} ${face.uvExtra.scaleY}');

				}
			}
		}
	}
}