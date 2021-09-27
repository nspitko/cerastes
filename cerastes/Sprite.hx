package cerastes;

import cerastes.collision.Collision.CAABB;
import cerastes.collision.Collision.ColliderType;
import cerastes.collision.Collision.CollisionMask;
import game.GameState.CollisionGroup;
import h2d.RenderContext;
import h2d.Tile;
import hxd.res.Atlas;
import h2d.Bitmap;
import h2d.Object;
import cerastes.fmt.SpriteResource;
import cerastes.collision.Colliders;

/**
 * Sprites altomatically self-register with SpriteManager
 *
 * ticking, collision, and high levle updates are all handled here
**/
class SpriteManager
{
	var sprites: List<Sprite>;


	public function new()
	{
		sprites = new List<Sprite>();
	}

	public function tick(delta: Float)
	{
		for(s in sprites)
		{
			s.tick( delta );
		}
	}
}

// SpriteCache is shared between sprites with the same name.
class SpriteCache
{
	public var spriteDef: CSDDefinition;
	public var frameCache: Map<String,haxe.ds.Vector<Tile>>;

	public function new( def: CSDDefinition )
	{
		spriteDef = def;

		build();
	}

	function build()
	{
		frameCache = [];
		for( a in spriteDef.animations )
			loadAnimation(a);
	}


	// Loads animation frames into cache.
	function loadAnimation( animation: CSDAnimation )
	{
		if( animation.atlas != null )
		{
			var tiles = new haxe.ds.Vector<h2d.Tile>( animation.frames.length );
			var atlas = hxd.Res.loader.loadCache( animation.atlas, Atlas );
			for( i in 0 ... animation.frames.length )
			{
				tiles[i] = atlas.get( animation.frames[i].tile );
			}

			frameCache.set(animation.name, tiles);
		}
		else
		{
			if( animation.frames.length > 0 )
				Utils.warning('Animation ${animation.name} has multiple frames but is not using an atlas.');

			var tiles = new haxe.ds.Vector<h2d.Tile>( animation.frames.length );
			for( i in 0 ... animation.frames.length )
			{
				tiles[i] = hxd.Res.load( animation.frames[i].tile ).toTile();
			}

			frameCache.set(animation.name, tiles);
		}

	}
}

@:keep
@:keepSub
@:autoBuild(cerastes.macros.SpriteData.build())
class Sprite extends h2d.Drawable implements CollisionObject
{

	var cache: SpriteCache;

	public var colliders(default, null): haxe.ds.Vector<Collider>;

	public var collisionMask: CollisionMask = 0;
	public var collisionType: CollisionGroup = 0;

	public var collisionBounds(get, null) : CAABB;
	function get_collisionBounds()
	{
		return collisionBounds;
	}

	// Current animation being played. Indexes into frame list
	var sequence: CSDAnimation;
	public var currentAnimation(get, never): String;
	function get_currentAnimation()
	{
		return sequence.name;
	}

	// Currently running animation
	var frames: haxe.ds.Vector<Tile> = null;

	// Index into frames and sequence.frames;
	public var currentFrame(default, set): Int = 0;
	function set_currentFrame(v: Int)
	{
		currentFrame = v;
		frameTime = 0;
		return v;
	}

	// How long have we spent on this frame?
	var frameTime: Float = 0;

	// How fast should we play animations?
	public var speed : Float = 1;

	public var frameInfo(get, never): CSDFrame;

	public inline function get_frameInfo()
	{
		return sequence.frames[currentFrame];
	}

	public var spriteDef(get, never): CSDDefinition;
	public inline function get_spriteDef()
	{
		return cache.spriteDef;
	}

	public var frameCache(get, never): Map<String,haxe.ds.Vector<Tile>>;
	public inline function get_frameCache()
	{
		return cache.frameCache;
	}

	// Imported from h2d.Anim

	/**
		Setting pause will suspend the animation, preventing automatic accumulation of `Anim.currentFrame` over time.
	**/
	public var pause : Bool = false;

	/**
		Disabling loop will stop the animation at the last frame.
	**/
	public var loop : Bool = true;

	/**
		When enabled, fading will draw two consecutive frames with alpha transition between
		them instead of directly switching from one to another when it reaches the next frame.
		This can be used to have smoother animation on some effects.
	**/
	public var fading : Bool = false;

	// END import

	public function new( spriteCache: SpriteCache, ?parent: Object )
	{
		cache = spriteCache;

		Utils.assert(spriteDef.animations.length > 0, 'Sprite ${spriteDef.name} has no animations defined!!' );

		play( spriteDef.animations[0].name );


		super(parent);

		buildColliders();
		loadSpriteData();

	}

	function loadSpriteData()
	{

	}

	function buildColliders()
	{
		colliders = new haxe.ds.Vector( spriteDef.colliders.length );
		for( i in 0 ... spriteDef.colliders.length)
		{
			var c = spriteDef.colliders[i];
			switch( c.type )
			{
				case ColliderType.AABB:
					colliders[i] = new AABB({
						min: { x: c.position.x, y: c.position.y	},
						max: { x: c.size.x, y: c.size.y	},
					 });
				case ColliderType.Circle:
					colliders[i] = new Circle({
						p: { x: c.position.x, y: c.position.y},
						r: c.size.x
					});
				case ColliderType.Point:
					colliders[i] = new Point({ x: c.position.x, y: c.position.y});
				default:
					Utils.error("Unsupported collision type");

			}
		}

		// Update collision bounds
		collisionBounds = {
			min: {x: 0, y: 0},
			max: {x: 0, y: 0},
		};

		for( c in colliders )
		{
			switch( c.colliderType )
			{
				case AABB:
					var aabb: AABB = cast c;
					collisionBounds.min.x = Math.min( collisionBounds.min.x, aabb.min_x );
					collisionBounds.min.y = Math.min( collisionBounds.min.y, aabb.min_y );
					collisionBounds.max.x = Math.max( collisionBounds.max.x, aabb.max_x );
					collisionBounds.max.y = Math.max( collisionBounds.max.y, aabb.max_y );

				case Circle:
					var circle: Circle = cast c;
					collisionBounds.min.x = Math.min( collisionBounds.min.x, circle.p_x - circle.r );
					collisionBounds.min.y = Math.min( collisionBounds.min.y, circle.p_y - circle.r );
					collisionBounds.max.x = Math.max( collisionBounds.max.x, circle.p_x + circle.r );
					collisionBounds.max.y = Math.max( collisionBounds.max.y, circle.p_y + circle.r );

				case Point:
					var point: Point = cast c;
					collisionBounds.min.x = Math.min( collisionBounds.min.x, point.x );
					collisionBounds.min.y = Math.min( collisionBounds.min.y, point.y );
					collisionBounds.max.x = Math.max( collisionBounds.max.x, point.x );
					collisionBounds.max.y = Math.max( collisionBounds.max.y, point.y );

				default:
					Utils.error("Unsupported collision type");

			}
		}

	}

	public function handleCollision( other: CollisionObject )
	{
		trace("unbound collision");
	}


	function getAnimation( name: String )
	{
		for( a in spriteDef.animations )
		{
			if( a.name == name ) return a;
		}

		Utils.assert(false,'Sprite ${spriteDef.name} has no animations defined!!');
		return null;
	}

	public function play( name: String, ?atFrame: Int = 0 )
	{
		sequence = getAnimation(name);

		frames = frameCache[ sequence.name ];
		currentFrame = atFrame;
		pause = false;
	}


	// Imported from h2d.Anim


	/**
		Sent each time the animation reaches past the last frame.

		If `loop` is enabled, callback is sent every time the animation loops.
		During the call, `currentFrame` is already wrapped around and represent new frame position so it's safe to modify it.

		If `loop` is disabled, callback is sent only once when the animation reaches `currentFrame == frames.length`.
		During the call, `currentFrame` is always equals to `frames.length`.
	**/
	public dynamic function onAnimEnd() {
	}

	override function getBoundsRec( relativeTo : Object, out : h2d.col.Bounds, forSize : Bool ) {
		super.getBoundsRec(relativeTo, out, forSize);
		var tile = getFrame();
		if( tile != null ) addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
	}

	override function sync( ctx : RenderContext ) {
		super.sync(ctx);
		var prev = currentFrame;
		if (!pause)
			frameTime += speed * ctx.elapsedTime;

		if( frameTime > frameInfo.duration )
		{
			frameTime -= frameInfo.duration;
			currentFrame++;
		}

		if( currentFrame < frames.length )
			return;
		if( loop ) {
			if( frames.length == 0 )
				currentFrame = 0;
			else
				currentFrame %= frames.length;
			onAnimEnd();
		} else if( currentFrame >= frames.length ) {
			currentFrame = frames.length;
			if( currentFrame != prev ) onAnimEnd();
		}
	}

	inline function getFrame()
	{
		return frames[ currentFrame ];
	}

	override function draw( ctx : RenderContext )
	{
		var t = getFrame();

		emitTile(ctx,t);

	}

	public function tick( delta: Float )
	{

	}

}