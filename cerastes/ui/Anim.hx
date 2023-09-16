package cerastes.ui;

import cerastes.fmt.AtlasResource.AtlasFrame;
import h2d.Tile;
import h2d.RenderContext;
import cerastes.fmt.AtlasResource.AtlasEntry;

/**
	Displays an animated sequence of bitmap Tiles on the screen.

	Anim does not provide animation sequence management and it's up to user on how to implement it.
	Another limitation is framerate. Anim runs at a fixed framerate dictated by `Anim.speed`.
	Switching animations can be done through `Anim.play` method.

	Note that animation playback happens regardless of Anim visibility and only can be paused by `Anim.pause` flag.
	Anim should be added to an active `h2d.Scene` in order to function.
**/
class Anim extends h2d.Drawable {

	public var entry: AtlasEntry;
	public var currentFrameIdx(get,set) : Int;
	public var currentFrame(get,never) : AtlasFrame;
	var frameIndex: Int = 0;

	/**
		Setting pause will suspend the animation, preventing automatic accumulation of `Anim.currentFrameIdx` over time.
	**/
	public var pause : Bool = false;

	/**
		Disabling loop will stop the animation at the last frame.
	**/
	public var loop : Bool = true;
	var frameTimer: Float = 0;

	function get_currentFrame()
	{
		return entry.frames[currentFrameIdx];
	}

	public function new( ?entry : AtlasEntry, ?parent : h2d.Object ) {
		super(parent);
		this.entry = entry == null ? {} : entry;
		this.currentFrameIdx = 0;
	}

	inline function get_currentFrameIdx() {
		return frameIndex;
	}

	/**
		Change the currently playing animation and unset the pause if it was set.
		@param frames The list of frames to play.
		@param atFrame Optional starting frame of the new animation.
	**/
	public function play( entry : AtlasEntry, atFrame = 0 ) {
		this.entry = entry == null ? {} : entry;
		currentFrameIdx = atFrame;
		pause = false;
	}

	public function replay()
	{
		currentFrameIdx = 0;
		frameTimer = 0;
		pause = false;
	}

	/**
		Sent each time the animation reaches past the last frame.

		If `loop` is enabled, callback is sent every time the animation loops.
		During the call, `currentFrameIdx` is already wrapped around and represent new frame position so it's safe to modify it.

		If `loop` is disabled, callback is sent only once when the animation reaches `currentFrameIdx == frames.length`.
		During the call, `currentFrameIdx` is always equals to `frames.length`.
	**/
	public dynamic function onAnimEnd() {
	}

	function set_currentFrameIdx( frame : Int ) {
		frameIndex = entry.frames.length == 0 ? 0 : frame % entry.frames.length;
		if( frameIndex < 0 ) frameIndex += entry.frames.length;
		return frameIndex;
	}

	override function getBoundsRec( relativeTo : h2d.Object, out : h2d.col.Bounds, forSize : Bool ) {
		super.getBoundsRec(relativeTo, out, forSize);
		var tile = currentFrame.tile;
		if( tile != null ) addBounds(relativeTo, out, tile.dx, tile.dy, tile.width, tile.height);
	}

	override function sync( ctx : RenderContext ) {
		super.sync(ctx);
		var prev = currentFrameIdx;

		var frame = entry.frames[currentFrameIdx];
		var frameDuration = currentFrame.duration / 1000; // ms

		if (!pause)
			frameTimer += ctx.elapsedTime;

		if( frameTimer > frameDuration )
		{
			frameTimer -= frameDuration;
			frameIndex++;
		}

		if( frameIndex < entry.frames.length )
			return;

		if( loop )
		{
			if( entry.frames.length == 0 )
				frameIndex = 0;
			else
				frameIndex %= entry.frames.length;
			onAnimEnd();
		}
		else if( frameIndex >= entry.frames.length )
		{
			pause = true;

			if( entry.defaultFrame != -1 )
				frameIndex = entry.defaultFrame;
			else
				frameIndex = entry.frames.length - 1;

			if( frameIndex != prev )
				onAnimEnd();

		}
	}

	override function draw( ctx : RenderContext ) {

		emitTile(ctx,currentFrame.tile);
	}
}
