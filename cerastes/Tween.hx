package cerastes;

import cerastes.macros.Metrics;

class TweenManager
{
	public static var instance(default, null):TweenManager = new TweenManager();

	private var tweens = new Array<Tween>();

	private function new () {}  // private constructor

	public function tick( delta: Float )
	{
		Metrics.begin();
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
		func = tweenFunc;
		updateFunc = onUpdate;
		completeFunc = onComplete;

		onUpdate(startVal);

		TweenManager.instance.register(this);
	}

	public function tick( delta: Float )
	{
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