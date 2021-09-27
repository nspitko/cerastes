package cerastes.fmt;

import cerastes.collision.Collision.ColliderType;
import cerastes.Sprite.SpriteCache;
import h2d.col.Point;
import haxe.EnumTools;
import h3d.Vector;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;
import h2d.Bitmap;
import hxd.res.BitmapFont;
import h2d.Font;
import hxd.res.Loader;
import h2d.Object;
import hxd.res.Resource;

import haxe.Json;


typedef CBLPoint = {
	var x: Float;
	var y: Float;
}

typedef CBLObject = {

	var type: String; // type to load. MUST implement BulletLevelObject
	var position: CBLPoint;
}

typedef CBLFile = {
	var version: Int;
	var objects: Array<CBLObject>;
	var length: Float;
	var speed: Float;
}

class BulletLevelResource extends Resource
{
	var data: CBLFile;

	static var minVersion = 1;
	static var version = 1;


	public function toLevel( ?parent: Object )
	{
		var data = getData();

		//return new cerastes.Sprite(cache,parent);
	}


	public static function write( obj: CBLFile, file: String )
	{

		//var s = new hxbit.Serializer();
		//var bytes = s.serialize(cui);

		//var txt = Json.print( "CSDFile", csd);
		var txt = Json.stringify( obj, null, "\t" );


		#if hl
		sys.io.File.saveContent('res/${file}',txt);
		#end
	}


	public function getData( ?cache: Bool = true ) : CBLFile
	{
		if (data != null && cache) return data;

		//var u = new hxbit.Serializer();
		//data = u.unserialize(entry.getBytes(), CSDFile);
		//data = cast Json.parse( "cerastes.fmt.SpriteResource.CSDFile", entry.getText()  );
		var d : CBLFile = Json.parse( entry.getText()  );
		if( cache )
			data = d;

		Utils.assert( d.version <= version, "Warning: CBL file generated with newer version than this parser supports" );
		Utils.assert( d.version >= minVersion, "Warning: CBL file version newer than parser understands; parsing will probably fail!" );


		return d;
	}
}