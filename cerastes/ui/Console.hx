package cerastes.ui;


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
	public static var instance = new GlobalConsole();

	public var console(default, null): CerastesConsole;

	public var currentScene(default, set): cerastes.Scene;

	function set_currentScene(v : cerastes.Scene)
	{
		if(console == null )
			return v;

		console.remove();
		v.s2d.addChild( console );


		currentScene = v;

		return v;
	}

	private function new()
	{

	}

	public function init()
	{
		// @todo: Allow this to be configurable.
		console = new CerastesConsole( cerastes.App.defaultFont );

		console.shortKeyChar = "`".code;
	}

	public function error( text : String, ?color ) {
		console.log(text,0xFF0000);
	}






}