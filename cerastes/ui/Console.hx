package cerastes.ui;

import hxd.snd.Data.SampleFormat;
import h2d.Console.ConsoleArg;

@:structInit class ConvarInstance
{
	public var name: String;
	public var help: String;
	public var type: ConsoleArg;
	public var value: Any;
	public var onChange: Any -> Void;
}

class CerastesConsole extends h2d.Console
{

	public function new(font:h2d.Font,?parent) {
		super(font, parent);
		tf.onKeyUp = function(e){
			if( tf.text == "`")
				tf.text = "";
		}

	}


	public function externalLog( text, ?color ) {
		super.log(text, color);
	}

	public override function log( text : String, ?color ) {

		super.log(text, color);
		Utils.writeLog( text, ALWAYS );
	}


}

@:keep
class GlobalConsole
{

	static var convars: Map<String, ConvarInstance> = [];

	public static var console(default, null): CerastesConsole;

	public static var currentScene(default, set): cerastes.Scene;

	static function set_currentScene(v : cerastes.Scene)
	{
		if( console == null )
			return v;

		console.remove();
		v.s2d.addChild( console );


		currentScene = v;

		return v;
	}

	static public function init()
	{
		// @todo: Allow this to be configurable.
		console = new CerastesConsole( cerastes.App.defaultFont );

		console.shortKeyChar = "`".code;

		for( c in convars )
		{
			console.addCommand( c.name, c.help, [ {name: "value", t: c.type } ], ( newVal ) -> {
				var oldVal = c.value;
				c.value = cast newVal;
				if( c.onChange != null )
					c.onChange( cast oldVal );

				Utils.info('${c.name}=${c.value}');

			} );
		}
	}

	public function error( text : String, ?color ) {
		console.log(text,0xFF0000);
	}



	@:generic
	public static function registerConvar<T>( name: String, defaultValue: T, onChange: T -> Void, ?help )
	{
		Utils.assert( !convars.exists(name),'Convar "$name" already exists! Overwriting old value....');

		var t: ConsoleArg = switch( Type.typeof(defaultValue) )
		{
			case TInt: AInt;
			case TBool: ABool;
			default: AString;
		}

		var inst: ConvarInstance = {
			name: name,
			help: help,
			type: t,
			value: defaultValue,
			onChange: cast onChange
		};

		convars.set(name, inst);


		return true;
	}

	@:generic
	public static function convar<T>(name:String)
	{
		var c = convars.get(name);

		// I'd like to handle this more gracefully but afaik thre's no way to return
		// out of a generic without a type.
		Utils.assert(c != null, 'Unknown convar $name');

		var out: T = cast c.value;

		return out;
	}


}