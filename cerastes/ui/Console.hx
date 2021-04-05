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


}


class GlobalConsole
{
	public static var instance = new GlobalConsole();

	public var console(default, null): CerastesConsole;

	public var currentScene(default, set): cerastes.Scene;

	function set_currentScene(v : cerastes.Scene)
	{
		console.remove();
		v.s2d.addChildAt( console, 1 );

		currentScene = v;

		return v;
	}

	private function new()
	{

	}

	public function init()
	{
		console = new CerastesConsole(hxd.Res.fnt.kodenmanhou16.toFont());

		console.shortKeyChar = "`".code;
	}

	public function error( text : String, ?color ) {
		console.log(text,0xFF0000);
	}






}