package cerastes.ui;

class TransitionComp extends DrawableComp implements domkit.Component.ComponentDecl<h2d.Drawable> {

	@:p(colorF) var color : h3d.Vector;
	@:p(auto) var smooth : Null<Bool>;
	@:p var tileWrap : Bool;

	static function set_transitionProperties( o : h2d.Drawable, v ) {
		if(v != null)
			o.color.load(v);
		else
			o.color.set(1,1,1);
	}
}