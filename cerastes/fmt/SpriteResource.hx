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

// Cerastes Sprites
@:enum
abstract SpriteAttachmentTween(Int) from Int to Int
{
	var None = 0;		// Do not tween attachments
	var Linear = 1;		// Linear tweening
	var ExpoIn = 2;
	var ExpoOut = 3;
	var ExpoInOut = 4;

	public function toString()
	{
		return switch( this )
		{
			case None: "None";
			case Linear: "Linear";
			case ExpoIn: "ExpoIn";
			case ExpoOut: "ExpoOut";
			case ExpoInOut: "ExpoInOut";
			default: "None";
		}
	}
}

typedef CSDPoint = {
	var x: Float;
	var y: Float;
}

// Colliders. Sprites can have multiple colliders, and animations may change them.
typedef CSDCollider = {
	var type: ColliderType;
	var position: CSDPoint;
	var size: CSDPoint;
}

// Attachments must be specified on frame 0, and can additionally be
// specified again in later frames to update the position.
typedef CSDAttachment = {
	var name: String;
	var position: CSDPoint;
	var rotation: Float; // in Radians. Because heaps uses radians internally and I don't have to justify myself to youuuuuuuuuuuuuuuu
	var attachmentSprite: String; // If set, loads a sprite into this attachment position. This is useful for multi-component sprites
}

typedef CSDAttachmentOverride = {
	var name: String;
	var position: CSDPoint;
	var rotation: Float; // radians.jpg
	var positionTween: SpriteAttachmentTween; // tween to use from existing value to the one specified here
	var rotationTween: SpriteAttachmentTween;
	var start: Float;		// The most recent non-expired override always wins.
	var duration: Float;	// If 0 then forever
	var tweenDuration: Float;	// How long to tween. if 0 then use duration. if duration is also  0 then don't tween regardless
}


typedef CSDFrame = {
	var tile: String;		// lookup id for the atlas
	var duration: Float;		// How long to keep the tile on screen.
	var offsetX: Float;		// Optional x/y offsets
	var offsetY: Float;
}

// Tags provide feedback to the code as to the state of the animation
typedef CSDTag = {
	var name: String;
	var start: Float;
	var duration: Float; 			// Can be 0 for no length when used like an event
}

typedef CSDSound = {
	var name: String;
	var start: Float;
	var duration: Float; 			// Optional for looping sounds.
}

typedef CSDAnimation = {
	var name: String;
	var atlas: String;
	var frames: Array<CSDFrame>;
	var tags: Array<CSDTag>;
	var sounds: Array<CSDSound>;
	var attachmentOverrides: Array<CSDAttachmentOverride>;
}

typedef CSDKV = {
	var key: String;
	var value: Dynamic;
}

typedef CSDDefinition = {

	var name: String;
	var ?type: String; // Underlying type for spritedata stuff. Can be empty
	var typeData: Array<CSDKV>; // KV of the packed struct
	var animations: Array<CSDAnimation>;
	var attachments: Array<CSDAttachment>;
	var colliders: Array<CSDCollider>;
}

typedef CSDFile = {
	var version: Int;
	var sprite: CSDDefinition;
}

class SpriteResource extends Resource
{
	var data: CSDFile;

	static var minVersion = 1;
	static var version = 1;

	var cache: SpriteCache = null;

	public function toSprite( ?parent: Object, ?localCache: SpriteCache = null )
	{
		var data = getData();

		if( cache == null )
			cache = new SpriteCache( data.sprite );

		return SpriteMeta.create( localCache != null ? localCache : cache, parent );

		return new cerastes.Sprite(cache,parent);
	}


	public static function write( sprite: CSDDefinition, file: String )
	{
		var csd: CSDFile = {
			version: version,
			sprite: sprite
		};

		//var s = new hxbit.Serializer();
		//var bytes = s.serialize(cui);

		//var txt = Json.print( "CSDFile", csd);
		var txt = Json.stringify( csd, null, "\t" );

		#if hl
		sys.io.File.saveContent( Utils.fixWritePath(file, "csd"),txt);
		#end
	}


	public function getData( ?cache: Bool = true ) : CSDFile
	{
		if (data != null && cache) return data;

		//var u = new hxbit.Serializer();
		//data = u.unserialize(entry.getBytes(), CSDFile);
		//data = cast Json.parse( "cerastes.fmt.SpriteResource.CSDFile", entry.getText()  );
		var d  = Json.parse( entry.getText()  );
		if( cache )
			data = d;

		Utils.assert( d.version <= version, "Warning: Sprite file generated with newer version than this parser supports" );
		Utils.assert( d.version >= minVersion, "Warning: Sprite file version newer than parser understands; parsing will probably fail!" );


		return d;
	}
}