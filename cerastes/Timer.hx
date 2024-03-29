package cerastes;

import cerastes.macros.Metrics;

class TimerManager
{
	public static var instance(default, null):TimerManager = new TimerManager();

	private var tweens = new Array<Timer>();

	private function new () {}  // private constructor

	public function tick( delta: Float )
	{
		Metrics.begin();
		var i = tweens.length;
		while( i-- > 0 )
		{
			tweens[i].tick( delta );
			if( tweens[i].finished )
				tweens.splice(i,1);
		}
		Metrics.end();
	}

	public function register( t : Timer )
	{
		tweens.push(t);
	}
}

class Timer
{
	var time : Float = 0;
	public var duration: Float;
	public var finished = false;
	public var repeat = false;

	var onComplete : Void->Void;

	public function new( duration: Float, onComplete: Void->Void )
	{
		this.duration = duration;
		this.onComplete = onComplete;

		TimerManager.instance.register(this);
	}

	public function restart( )
	{
		time = 0;
		finished = false;
	}

	public function cancel( )
	{
		finished = true;
	}

	public function tick( delta: Float )
	{
		time += delta;

		if( time > duration && !finished )
		{
			onComplete();
			if( repeat )
				time = 0;
			else
				finished = true;

		}
	}
}