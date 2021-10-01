package cerastes;
import cerastes.macros.Metrics;
import hxd.Key;
import hxd.Pad;

enum InputButton {
	UP;
	DOWN;
	LEFT;
	RIGHT;
	A;
	B;
	X;
	Y;
	START;
	ENTER;
	MOUSE_LEFT;
}

enum InputState {
	PRESSED;
	HELD;
	UP;
}

typedef InputListener = {
	callback: (InputButton, InputState) -> Bool,
	priority: Int
}

class InputManager
{
	private static var listeners = new Array<InputListener>();
	private static var pads = new Array< hxd.Pad >();
	public  static var enabled: Bool = true;

	public static function init()
	{
		hxd.Pad.wait(onPadConnected);
	}

	private static function onPadConnected( p : hxd.Pad )
	{
		pads.push(p);
	}

	public static function register(listener: InputListener )
	{
		listeners.push( listener );

		haxe.ds.ArraySort.sort(listeners, function(a, b):Int {
			if (a.priority > b.priority) return -1;
			else if (a.priority < b.priority) return 1;
			return 0;
		});
	}

	public static function unregister(listener: InputListener )
	{
		return listeners.remove( listener );

	}

	public static function reset()
	{
		listeners = new Array<InputListener>();
	}

	public static function tick( delta: Float )
	{
		Metrics.begin();

		if( Key.isPressed( Key.UP ) )
			notifyListeners(UP, PRESSED );
		if( Key.isPressed( Key.DOWN ) )
			notifyListeners(DOWN, PRESSED );
		if( Key.isPressed( Key.LEFT ) )
			notifyListeners(LEFT, PRESSED );
		if( Key.isPressed( Key.RIGHT ) )
			notifyListeners(RIGHT, PRESSED );

		if( Key.isPressed( Key.Z ) )
			notifyListeners(A, PRESSED );
		if( Key.isPressed( Key.X ) )
			notifyListeners(B, PRESSED );
		if( Key.isPressed( Key.C ) )
			notifyListeners(X, PRESSED );
		if( Key.isPressed( Key.V ) )
			notifyListeners(Y, PRESSED );

		if( Key.isPressed( Key.SPACE ) )
			notifyListeners(START, PRESSED );

		if( Key.isPressed( Key.ENTER ) ||  Key.isPressed( Key.NUMPAD_ENTER ) )
			notifyListeners(ENTER, PRESSED );

		if( Key.isPressed( Key.MOUSE_LEFT ) )
			notifyListeners(MOUSE_LEFT, PRESSED );



		for( p in pads )
		{
			if( !p.connected )
				continue;

			var conf = hxd.Pad.DEFAULT_CONFIG;

			if( p.isPressed( conf.dpadUp ) )
				notifyListeners(UP, PRESSED );
			if( p.isPressed( conf.dpadDown ) )
				notifyListeners(DOWN, PRESSED );
			if( p.isPressed( conf.dpadLeft ) )
				notifyListeners(LEFT, PRESSED );
			if( p.isPressed( conf.dpadRight ) )
				notifyListeners(RIGHT, PRESSED );

			if( p.isPressed( conf.A ) )
				notifyListeners(A, PRESSED );
			if( p.isPressed( conf.B ) )
				notifyListeners(B, PRESSED );
			if( p.isPressed( conf.X ) )
				notifyListeners(X, PRESSED );
			if( p.isPressed( conf.Y ) )
				notifyListeners(Y, PRESSED );

			if( p.isPressed( conf.start ) )
				notifyListeners(START, PRESSED );

		}

		Metrics.end();



	}

	private static function notifyListeners( button: InputButton, state: InputState )
	{
		if( !enabled ) return;

		for( listener in listeners )
		{
			if( listener.callback(button,state) )
				return;
		}
	}
}