package cerastes.ui;

import hxd.res.DefaultFont;
import h2d.Object;

class CerastesButton extends cerastes.ui.BaseComponents.Flow
{
	public var text(default, set): String;
	public var font(default, set): h2d.Font;
	public var value( default, set ): Bool;

	public var onClick( default, set ) : (hxd.Event) -> Void;

	var label: h2d.Text;

	var b: h2d.Graphics;
	var size = 10;

	function set_text( newStr )
	{
		label.text = newStr;
		//this.reflow();
		return newStr;
	}

	function set_font( newStr )
	{
		label.font = newStr;
		return newStr;
	}

	function set_value( newVal )
	{
		value = newVal;
		return value;
	}

	function set_onClick( newVal )
	{
		this.interactive.onClick = newVal;
		return newVal;
	}

	public function new(?parent) {
		super(parent);


		label = new h2d.Text(DefaultFont.get(), this);
		label.text = text;

		//label.textAlign = Right;

		
		this.padding = 2;
		this.paddingBottom = 2;
		this.backgroundTile = h2d.Tile.fromColor(0x404040);

		this.enableInteractive = true;
		this.interactive.cursor = Button;
		//this.interactive.onClick = function(_) onClick();
		this.interactive.onOver = function(_) this.backgroundTile = h2d.Tile.fromColor(0x606060);
		this.interactive.onOut = function(_) this.backgroundTile = h2d.Tile.fromColor(0x404040);
		this.interactive.onClick = onClick;

		this.reflow();
	}

}

@:uiComp("button")
class ButtonComp extends h2d.domkit.BaseComponents.DrawableComp  implements domkit.Component.ComponentDecl<CerastesButton> {

	@:p var text: String;
	@:p(font) var font : h2d.Font;

	static function create( parent : h2d.Object ) {
		return new CerastesButton(parent);
	}



}

