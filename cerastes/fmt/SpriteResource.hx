package cerastes.fmt;

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
}

typedef CSDPoint = {
	var x: Float;
	var y: Float;
}

// Attachments must be specified on frame 0, and can additionally be
// specified again in later frames to update the position.
typedef CSDAttachment = {
	var name: String;
	var position: CSDPoint;
	var rotation: Float; // in Radians. Because heaps uses radians internally and I don't have to justify myself to youuuuuuuuuuuuuuuu
}

typedef CSDAttachmentOverride = {
	var name: String;
	var position: CSDPoint;
	var angle: CSDPoint; // 0,0 if none
	var positionTween: SpriteAttachmentTween; // tween to use from existing value to the one specified here
	var angleTween: SpriteAttachmentTween;
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
	var end: Float; 			// Can be 0 for no length when used like an event
}

typedef CSDSound = {
	var name: String;
	var start: Float;
	var end: Float; 			// Optional for looping sounds.
}

typedef CSDAnimation = {
	var name: String;
	var atlas: String;
	var frames: Array<CSDFrame>;
	var tags: Array<CSDTag>;
	var sounds: Array<CSDSound>;
	var attachmentOverrides: Array<CSDAttachmentOverride>;
}

typedef CSDDefinition = {

	var name: String;
	var animations: Array<CSDAnimation>;
	var attachments: Array<CSDAttachment>;
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

	public function toSprite( ?parent: Object )
	{
		var data = getData();

		if( cache == null )
			cache = new SpriteCache( data.sprite );

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
		sys.io.File.saveContent('res/${file}',txt);
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