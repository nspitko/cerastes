package cerastes;

import tweenxcore.color.RgbColor;
import tweenxcore.Tools.Easing;
import cerastes.macros.Metrics;

class TweenManager
{
	public static var instance(default, null):TweenManager = new TweenManager();

	private var tweens = new Array<Tween>();

	public static var skipFrames = 0;
	static var timer = 0;

	private function new () {}  // private constructor

	public function tick( delta: Float )
	{
		Metrics.begin();
		if( skipFrames > 0 )
		{
			timer++;

			if( timer < skipFrames )
				return;

			delta = timer * 1/60;
			timer = 0;
		}

		var i = tweens.length;
		while( i-- > 0 )
		{
			if( tweens[i].finished )
			{
				tweens.splice(i,1);
				continue;
			}

			tweens[i].tick( delta );

		}
		Metrics.end();
	}

	public function register( t : Tween )
	{
		tweens.push(t);
	}
}

class Tween
{
	var duration: Float;
	var time: Float = 0;
	var start: Float;
	var end: Float;
	var func: Float->Float;
	var updateFunc: Float->Void;
	var completeFunc: Void->Void;
	public var finished = false;
	public var loop = false;

	public function new(tweenDuration: Float, startVal: Float, endVal: Float, onUpdate: Float->Void,
		?tweenFunc: Float->Float, ?onComplete: Void->Void )
	{
		duration = tweenDuration;
		start = startVal;
		end = endVal;
		func = tweenFunc != null ? tweenFunc : Easing.linear;
		updateFunc = onUpdate;
		completeFunc = onComplete;

		onUpdate(startVal);

		TweenManager.instance.register(this);
	}

	public function tick( delta: Float )
	{
		if( finished )
			return;

		time += delta;
		updateFunc( this.get() );
		if( finished && completeFunc != null )
			completeFunc();
	}

	public function abort( ?fireCallback = false )
	{
		finished = true;
		if( fireCallback && completeFunc != null )
			completeFunc();
	}


	public function get()
	{
		if( time / duration >= 1 )
		{
			if( loop )
			{
				time -= duration;
				return get();
			}
			else
			{
				finished = true;
			}
			return end;
		}
		else
		{
			var rate = func( time / duration );
			return start * (1 - rate) + end * rate;
		}
	}
}

class ColorTween extends Tween
{
	public override function get()
	{
		if( time / duration >= 1 )
		{
			if( loop )
			{
				time -= duration;
				return get();
			}
			else
			{
				finished = true;
			}
			return end;
		}
		else
		{
			var rate = func( time / duration );

			var r = lerpComponent( 16, rate );
			var g = lerpComponent( 8, rate );
			var b = lerpComponent( 0, rate );
			var a = lerpComponent( 24, rate );

			return r | g | b | a;
		}

	}

	function lerpComponent( shift: Int, rate: Float )
	{
		// Note of warning: Shift operation is important here!
		// If you mask then shift you end up carrying the high
		// bit in the alpha channel unless you use >>>!
		var sc = ( Std.int( start ) >> shift ) & 0xFF;
		var ec = ( Std.int( end   ) >> shift ) & 0xFF;

		var v: Int = Std.int( sc * (1 - rate) + ec * rate );

		return v << shift;


	}
}