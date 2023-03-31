package cerastes;

interface Tickable
{
	public function tick( delta: Float ): Void;
	public var finished(get, null): Bool;
}

class TimeManager
{
	static var tickables: Array<Tickable> = [];

	public static function register( t: Tickable )
	{
		tickables.push(t);
	}
	public static function unregister( t: Tickable )
	{
		tickables.remove(t);
	}

	public static function tick( delta: Float )
	{
		var i = tickables.length;
		while( i-- > 0 )
		{
			if( tickables[i].finished )
			{
				tickables.splice(i,1);
				continue;
			}

			tickables[i].tick( delta );

		}
	}
}