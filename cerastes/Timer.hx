package cerastes;

class TimerManager
{
	public static var instance(default, null):TimerManager = new TimerManager();

	private var tweens = new Array<Timer>();

	private function new () {}  // private constructor

	public function tick( delta: Float )
	{
		var i = tweens.length;
		while( i-- > 0 )
		{
			tweens[i].tick( delta );
			if( tweens[i].finished )
				tweens.splice(i,1);
		}
	}

	public function register( t : Timer )
	{
		tweens.push(t);
	}
}

class Timer
{
	var time : Float = 0;
	var duration: Float;
	public var finished = false;

	var onComplete : Void->Void;

	public function new( duration: Float, onComplete: Void->Void )
	{
		this.duration = duration;
		this.onComplete = onComplete;

		TimerManager.instance.register(this);
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
			finished = true;

		}
	}
}