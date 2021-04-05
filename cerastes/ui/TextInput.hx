package cerastes.ui;

import hxd.res.DefaultFont;
@:uiComp("textinput")
class TextinputComp extends h2d.domkit.BaseComponents.TextComp  implements domkit.Component.ComponentDecl<h2d.TextInput> 
{
	@:p(colorF) var backgroundColor : h3d.Vector;
	
	static function create( parent : h2d.Object ) {
		return new h2d.TextInput( DefaultFont.get(), parent);
	}

	
	static function set_backgroundColor( o : h2d.TextInput, v ) {
		var bg = @:privateAccess o.backgroundColor;
		
		o.backgroundColor = v.toColor();
	}

}