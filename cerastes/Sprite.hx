package cerastes;

import haxe.ds.Vector;
import cerastes.collision.Collision.CAABB;
import cerastes.collision.Collision.ColliderType;
import cerastes.collision.Collision.CollisionMask;
import h2d.RenderContext;
import h2d.Tile;
import hxd.res.Atlas;
import h2d.Bitmap;
import h2d.Object;
import cerastes.fmt.SpriteResource;
import cerastes.collision.Colliders;
using tweenxcore.Tools;

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

	public var collisionMask: CollisionMask = cast 0;
	public var collisionType(default, set): CollisionGroup = None;
	public var mute: Bool = false;

	function set_collisionType(v) { collisionType = v;  return v; }


	var attachments: Map<String, Object> = [];

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
		return v;
	}

	// How long have we spent on this frame?
	var frameTime: Float = 0;
	// How long have we spent on this animation cycle?
	var animTime: Float = 0;
	// Used to determine what state we've yet to apply
	var animTimeLast: Float = 0;

	// How fast should we play animations?
	public var speed : Float = 1;

	public var originX: Float = 0;
	public var originY: Float = 0;

	public var frameInfo(get, never): CSDFrame;

	function get_frameInfo()
	{
		return sequence.frames[currentFrame];
	}

	public var spriteDef(get, never): CSDDefinition;
	function get_spriteDef()
	{
		return cache.spriteDef;
	}

	public var frameCache(get, never): Map<String,haxe.ds.Vector<Tile>>;
	function get_frameCache()
	{
		return cache.frameCache;
	}

	public function getAttachment( name: String ) : Null<Object>
	{
		Utils.assert(attachments.exists(name), 'Tried looking up unknown attachment ${name}!' );
		return attachments.get(name);
	}

	// @todo refactor this into a setter for a more consistent, less error prone API
	public function setAnimTime( newTime: Float )
	{
		// First, find the correct frame
		var ft: Float = 0;
		for( idx in 0 ... sequence.frames.length )
		{
			var f = sequence.frames[idx];
			if( ft + f.duration > newTime )
			{
				currentFrame = idx;
				frameTime = ( newTime - ft );
				break;
			}

			ft += f.duration;
		}

		animTime = newTime;


		updateAnimationState();

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

	// END import

	public function new( spriteCache: SpriteCache, ?parent: Object )
	{
		cache = spriteCache;

		Utils.assert(spriteDef.animations.length > 0, 'Sprite ${spriteDef.name} has no animations defined!!' );
		super(parent);
		if( spriteCache.spriteDef.origin != null )
		{
			originX = spriteCache.spriteDef.origin.x;
			originY = spriteCache.spriteDef.origin.y;
		}

		play( spriteDef.animations[0].name );

		buildColliders();
		loadSpriteData();
		loadAttachments();

	}

	function loadSpriteData()
	{

	}

	/**
	 * Loads all our attachments for this sprite, based on spriteDef.
	 *
	 * Sprites may be explicitly specified, else empty objects will be created so they can be
	 * manipulated using a common interface and filled out with contents later as needed.
	 */
	function loadAttachments()
	{
		var needsFixup = false;
		for( a in spriteDef.attachments )
		{
			var attachment: Object = null;

			var attachmentParent: Object = cast this;
			if( a.parent != null )
			{
				attachmentParent = attachments.get(a.parent);
				if( attachmentParent == null ) needsFixup = true;
			}

			if( a.attachmentSprite != null )
			{
				attachment = hxd.Res.loader.loadCache( a.attachmentSprite, SpriteResource ).toSprite(attachmentParent);
			}
			else
			{
				attachment = new h2d.Object(attachmentParent);
			}

			attachment.x = a.position.x;
			attachment.y = a.position.y;
			attachment.rotation = a.rotation;

			attachments.set(a.name, attachment);
		}

		if( needsFixup )
		{
			Utils.warning('Need attachment for ${spriteDef.name} fixeup! this is slow... fix order in csd please!');

			for( name => a in attachments )
			{
				if( a.parent == null )
				{
					for( d in spriteDef.attachments )
					{
						if( d.name == name)
						{
							var other = attachments.get(d.parent);
							Utils.assert(other != null, '${spriteDef.name} has Invalid attachment parent: ${d.name} for attachment ${name}');
							if( other == null ) break;
							other.addChild( a );
						}
					}
				}
			}
		}

	}

	/**
	 * Applies transforms that occured between the last two frame ticks
	 *
	 * @todo: This doesn't currently support multiple overrides at once.
	 */
	function updateAnimationState()
	{
		for( a in spriteDef.attachments )
		{
			var localAttachment = attachments.get( a.name );

			var localPosX = a.position.x;
			var localPosY = a.position.y;
			var localRot = a.rotation;

			// optimize: We could cache off a map here to avoid the extra looping
			for( o in sequence.attachmentOverrides )
			{
				if( o.name != a.name ) continue;
				if( o.start <= animTime && o.start + o.duration > animTime )
				{
					var localAttachment = attachments.get( a.name );
					if( localAttachment == null ) continue;

					if( o.positionTween == None || animTime > o.start + o.tweenDuration )
					{
						localPosX = o.position.x;
						localPosY = o.position.y;
					}
					else
					{
						if( o.tweenOrigin != null )
						{
							localPosX = o.tweenOrigin.x;
							localPosY = o.tweenOrigin.y;
						}
						var rate = ( animTime - o.start ) / o.tweenDuration;
						switch( o.positionTween )
						{
							case Linear:
								localPosX = rate.linear().lerp( localPosX, o.position.x );
								localPosY = rate.linear().lerp( localPosY, o.position.y );
							case ExpoIn:
								localPosX = rate.expoIn().lerp( localPosX, o.position.x );
								localPosY = rate.expoIn().lerp( localPosY, o.position.y );
							case ExpoOut:
								localPosX = rate.expoOut().lerp( localPosX, o.position.x );
								localPosY = rate.expoOut().lerp( localPosY, o.position.y );
							case ExpoInOut:
								localPosX = rate.expoInOut().lerp( localPosX, o.position.x );
								localPosY = rate.expoInOut().lerp( localPosY, o.position.y );
							case CircIn:
								localPosX = rate.circIn().lerp( localPosX, o.position.x );
								localPosY = rate.circIn().lerp( localPosY, o.position.y );
							case CircOut:
								localPosX = rate.circOut().lerp( localPosX, o.position.x );
								localPosY = rate.circOut().lerp( localPosY, o.position.y );
							case CircInOut:
								localPosX = rate.circInOut().lerp( localPosX, o.position.x );
								localPosY = rate.circInOut().lerp( localPosY, o.position.y );
							case SineIn:
								localPosX = rate.sineIn().lerp( localPosX, o.position.x );
								localPosY = rate.sineIn().lerp( localPosY, o.position.y );
							case SineOut:
								localPosX = rate.sineOut().lerp( localPosX, o.position.x );
								localPosY = rate.sineOut().lerp( localPosY, o.position.y );
							case SineInOut:
								localPosX = rate.sineInOut().lerp( localPosX, o.position.x );
								localPosY = rate.sineInOut().lerp( localPosY, o.position.y );

							case None:
						}
						//new Tween( a.tweenDuration )
					}

					if( o.rotationTween	== None || animTime > o.start + o.tweenDuration )
					{
						localRot = o.rotation;
					}
					else
					{
						var rate = ( animTime - o.start ) / o.tweenDuration;
						if( o.tweenRotation != null )
						{
							localRot = o.tweenRotation;
						}
						switch( o.rotationTween )
						{
							case Linear:
								localRot = rate.linear().lerp( localRot, o.rotation );
							case ExpoIn:
								localRot = rate.expoIn().lerp( localRot, o.rotation );
							case ExpoOut:
								localRot = rate.expoOut().lerp( localRot, o.rotation );
							case ExpoInOut:
								localRot = rate.expoInOut().lerp( localRot, o.rotation );
							case CircIn:
								localRot = rate.circIn().lerp( localRot, o.rotation );
							case CircOut:
								localRot = rate.circOut().lerp( localRot, o.rotation );
							case CircInOut:
								localRot = rate.circInOut().lerp( localRot, o.rotation );
							case SineIn:
								localRot = rate.sineIn().lerp( localRot, o.rotation );
							case SineOut:
								localRot = rate.sineOut().lerp( localRot, o.rotation );
							case SineInOut:
								localRot = rate.sineInOut().lerp( localRot, o.rotation );
							case None:
						}
					}
				}
			}
			// avoid resync if possible
			if( localPosX != localAttachment.x || localPosY != localAttachment.y || localRot != localAttachment.rotation )
			{
				localAttachment.x = localPosX;
				localAttachment.y = localPosY;
				localAttachment.rotation = localRot;
			}
		}

		// Edge detect sound events
		if( !mute )
		{
			for( s in sequence.sounds )
			{
				if( animTimeLast <= s.start && animTime > s.start )
				{
					// @todo fix sound system
					//SoundManager.sfx( s.name );
				}
			}
		}

		// Edge detect tags
		for( s in sequence.tags )
		{
			if( animTimeLast <= s.start && animTime > s.start )
			{
				// 0 duration tags are events
				if( s.duration == 0 )
				{
					onEvent(s.name);
				}
				else
				{
					onTagBegin(s.name);
				}
			}
			// Check for trailing edge for tags
			if( s.duration > 0 && animTimeLast <= s.start + s.duration && animTime > s.start + s.duration )
			{
				onTagEnd(s.name);
			}
		}
		animTimeLast = animTime;
	}

	// Called when a tag with no duration is hit
	function onEvent(event: String )
	{

	}

	// Called when a tag begins
	function onTagBegin(tag: String )
	{

	}

	// Called when a tag ends
	function onTagEnd( tag: String )
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
						min: { x: c.position.x - originX, y: c.position.y - originY	},
						max: { x: c.position.x + c.size.x - originX, y: c.position.y + c.size.y - originY	},
					 });
				case ColliderType.Circle:
					colliders[i] = new Circle({
						p: { x: c.position.x - originX, y: c.position.y- originY},
						r: c.size.x
					});
				case ColliderType.Point:
					colliders[i] = new Point({ x: c.position.x- originX, y: c.position.y- originY});
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
		frameTime = 0;
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
		if( !visible ) return;
		var prev = currentFrame;
		if (!pause)
		{
			frameTime += speed * ctx.elapsedTime;
			animTime += speed * ctx.elapsedTime;
		}

		if( frameInfo != null && frameTime > frameInfo.duration )
		{
			frameTime -= frameInfo.duration;
			currentFrame++;
		}

		updateAnimationState();


		if( currentFrame < frames.length )
			return;

		// Fallthrough: We're done with this cycle.
		animTime = 0;
		animTimeLast = 0;

		if( loop )
		{
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
/*
	override function emitTile( ctx : RenderContext, tile : Tile ) {
		if( tile == null )
			tile = @:privateAccess new Tile(null, 0, 0, 5, 5);
		if( !ctx.hasBuffering() ) {
			if( !ctx.drawTile(this, tile) ) return;
			return;
		}
		if( !ctx.beginDrawBatch(this, tile.getTexture()) ) return;

		var alpha = color.a * ctx.globalAlpha;
		var ax = absX + originX * matA + originY * matC;
		var ay = absY + originX * matB + originY * matD;
		var buf = ctx.buffer;
		var pos = ctx.bufPos;
		buf.grow(pos + 4 * 8);

		inline function emit(v:Float) buf[pos++] = v;

		emit(ax);
		emit(ay);
		emit(@:privateAccess tile.u);
		emit(@:privateAccess tile.v);
		emit(@:privateAccess color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);


		var tw = tile.width;
		var th = tile.height;
		var dx1 = tw * matA;
		var dy1 = tw * matB;
		var dx2 = th * matC;
		var dy2 = th * matD;

		emit(ax + dx1);
		emit(ay + dy1);
		emit(@:privateAccess tile.u2);
		emit(@:privateAccess tile.v);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);

		emit(ax + dx2);
		emit(ay + dy2);
		emit(@:privateAccess tile.u);
		emit(@:privateAccess tile.v2);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);

		emit(ax + dx1 + dx2);
		emit(ay + dy1 + dy2);
		emit(@:privateAccess tile.u2);
		emit(@:privateAccess tile.v2);
		emit(color.r);
		emit(color.g);
		emit(color.b);
		emit(alpha);

		ctx.bufPos = pos;
	}
*/
	@:dox(show)
	override function calcAbsPos() {
		if( parent == null ) {
			var cr, sr;
			if( rotation == 0 ) {
				cr = 1.; sr = 0.;
				matA = scaleX;
				matB = 0;
				matC = 0;
				matD = scaleY;
			} else {
				cr = Math.cos(rotation);
				sr = Math.sin(rotation);
				matA = scaleX * cr;
				matB = scaleX * sr;
				matC = scaleY * -sr;
				matD = scaleY * cr;
			}
			absX = x - originX;
			absY = y - originY;
		} else {
			// M(rel) = S . R . T
			// M(abs) = M(rel) . P(abs)
			var cr: Float=1;
			var sr: Float=1;
			if( rotation == 0 ) {
				matA = scaleX * parent.matA;
				matB = scaleX * parent.matB;
				matC = scaleY * parent.matC;
				matD = scaleY * parent.matD;
			} else {
				cr = Math.cos(rotation);
				sr = Math.sin(rotation);
				var tmpA = scaleX * cr;
				var tmpB = scaleX * sr;
				var tmpC = scaleY * -sr;
				var tmpD = scaleY * cr;
				matA = tmpA * parent.matA + tmpB * parent.matC;
				matB = tmpA * parent.matB + tmpB * parent.matD;
				matC = tmpC * parent.matA + tmpD * parent.matC;
				matD = tmpC * parent.matB + tmpD * parent.matD;
			}

			absX = x * parent.matA + y * parent.matC + parent.absX - ( originX * matA + originY * matC );
          	absY = x * parent.matB + y * parent.matD + parent.absY - ( originX * matB + originY * matD );
		}
	}

	@:noCompletion
	public function getKV() : Array<CSDKV>
	{
		return null;
	}

	public function tick( delta: Float )
	{

	}

}