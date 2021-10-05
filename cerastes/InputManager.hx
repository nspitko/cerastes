package cerastes;
import haxe.ds.Vector;
import cerastes.macros.Metrics;
import hxd.Key;
import hxd.Pad;

@:enum
abstract InputButton(Int) from Int to Int
{
	var UP 			= 0;
	var DOWN 		= 1;
	var LEFT 		= 2;
	var RIGHT		= 3;
	var A			= 4;
	var B			= 5;
	var X			= 6;
	var Y			= 7;
	var START 		= 8;
	var ENTER		= 9;
	var MOUSE_LEFT	= 10;
	var MOUSE_RIGHT = 11;
	var BUTTON_MAX	= 12;
}

enum InputState {
	PRESSED;
	HELD;
	RELEASED;
}

typedef InputListener = {
	callback: (InputButton, InputState, Float) -> Bool,
	priority: Int
}

class InputManager
{
	private static var listeners = new Array<InputListener>();
	private static var pads = new Array< hxd.Pad >();
	public  static var enabled: Bool = true;

	public static var state: Vector<InputState>;

	public static function init()
	{
		state = new Vector(InputButton.BUTTON_MAX);
		#if gamepad
		hxd.Pad.wait(onPadConnected);
		#end
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

	static inline function checkKeyState( code : Int, button: InputButton, delta: Float )
	{
		if( Key.isPressed( code ) )
			notifyListeners(button, PRESSED, delta );
		if( Key.isDown( code ) )
			notifyListeners(button, HELD, delta );
		if( Key.isReleased( code ) )
			notifyListeners(button, RELEASED, delta );
	}

	static inline function checkPadState( pad: Pad, key : Int, button: InputButton, delta: Float )
	{

	}

	public static function tick( delta: Float )
	{
		Metrics.begin();

		// Check pressed

		// Arrow keys
		checkKeyState( Key.UP, UP, delta );
		checkKeyState( Key.DOWN, DOWN, delta );
		checkKeyState( Key.LEFT, LEFT, delta );
		checkKeyState( Key.RIGHT, RIGHT, delta );
		// WASD
		checkKeyState( Key.W, UP, delta );
		checkKeyState( Key.A, LEFT, delta );
		checkKeyState( Key.S, DOWN, delta );
		checkKeyState( Key.D, RIGHT, delta );

		// zxcv
		checkKeyState( Key.Z, A, delta );
		checkKeyState( Key.X, B, delta );
		checkKeyState( Key.C, X, delta );
		checkKeyState( Key.V, Y, delta );

		// Start/Select
		checkKeyState( Key.SPACE, START, delta );
		checkKeyState( Key.ENTER, ENTER, delta );
		checkKeyState( Key.NUMPAD_ENTER, ENTER, delta );

		// Mouse
		checkKeyState( Key.MOUSE_LEFT, MOUSE_LEFT, delta );
		checkKeyState( Key.MOUSE_RIGHT, MOUSE_RIGHT, delta );
		#if gamepad
		for( p in pads )
		{
			if( !p.connected )
				continue;

			var conf = hxd.Pad.DEFAULT_CONFIG;

			checkPadState( p, conf.dpadUp, UP, delta );
			checkPadState( p, conf.dpadDown, DOWN, delta );
			checkPadState( p, conf.dpadLeft, LEFT, delta );
			checkPadState( p, conf.dpadRight, RIGHT, delta );

			checkPadState( p, conf.A, A, delta );
			checkPadState( p, conf.B, B, delta );
			checkPadState( p, conf.X, X, delta );
			checkPadState( p, conf.Y, Y, delta );

			checkPadState( p, conf.start, START, delta );

		}
		#end

		Metrics.end();



	}

	private static function notifyListeners( button: InputButton, state: InputState, delta: Float )
	{
		if( !enabled ) return;

		// Write up/down states
		if( state != PRESSED )
			InputManager.state[button] = state;

		for( listener in listeners )
		{
			if( listener.callback(button,state, delta) )
				return;
		}
	}
}