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

@:enum
abstract CBLTriggerType(Int) from Int to Int
{
	var None = 0;		// Do not tween attachments
	var PauseForClear = 1;		// Linear tweening
	var ChangeVelocity = 2;
	var Dialogue = 3;
	var LevelEnd = 4;

	public function toString()
	{
		return switch( this )
		{
			case PauseForClear: "PauseForClear";
			case ChangeVelocity: "ChangeVelocity";
			case Dialogue: "ChangeVeDialoguelocity";
			case LevelEnd: "LevelEnd";
			default: "None";
		}
	}
}


typedef CBLPoint = {
	var x: Float;
	var y: Float;
}

typedef CBLMesh = {
	var position: CBLPoint; // Spawn position for this group.
	var mesh: String;
	var rotation: Float;
	var scale: Float;
}

/**
 * Spawn groups are collections of objects that all spawn at once. These are
 * useful for controlling coordinated batches of enemimes that need to be timed
 * against eachother.
 */
typedef CBLSpawnGroup = {
	var position: CBLPoint; // Spawn position for this group.
	var id: Int;
}

typedef CBLTrigger = {
	var type: CBLTriggerType;
	var position: CBLPoint;
	var data: CBLPoint;
}

typedef CBLObject = {
	var sprite: String;
	var position: CBLPoint; // Spawn position outside of a group is bounds max towards level velocity, so enemies always spawn off screen
	var fiber: String; // Optional fiber to run. Must be a CannonEntity
	var rotation: Float; // In radians like a gentleman
	// Stuff for feeding into the fiber
	var speed: CBLPoint;
	var acceleration: CBLPoint;
	var spawnGroup: Int;
}

typedef CBLFile = {
	var version: Int;
	var sprites: Array<CBLObject>;
	var spawnGroups: Array<CBLSpawnGroup>;
	var triggers: Array<CBLTrigger>;
	var meshes: Array<CBLMesh>;
	var size: CBLPoint;
	var velocity: CBLPoint;
	var fogColor: Int;
}

class BulletLevelResource extends Resource
{
	var data: CBLFile;

	static var minVersion = 1;
	static var version = 1;


	public function toLevel( ?parent: Object )
	{
		var data = getData();

		return new cerastes.BulletLevel( data, 360, 480, parent );
	}


	public static function write( obj: CBLFile, file: String )
	{

		//var s = new hxbit.Serializer();
		//var bytes = s.serialize(cui);

		//var txt = Json.print( "CSDFile", csd);
		var txt = Json.stringify( obj, null, "\t" );


		#if hl
		sys.io.File.saveContent(Utils.fixWritePath(file, "cbl"),txt);
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