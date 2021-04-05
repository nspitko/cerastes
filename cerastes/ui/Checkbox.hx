package cerastes.ui;

import hxd.res.DefaultFont;
import h2d.Object;

class CerastesCheckbox extends cerastes.ui.BaseComponents.Flow
{
	public var text(default, set): String;
	public var value( default, set ): Bool;
	public var font(default, set): h2d.Font;

	public var onClick : ( value: Bool )->Void;

	var label: h2d.Text;

	var b: h2d.Graphics;
	var size = 7;

	function set_font( newStr )
	{
		label.font = newStr;
		return newStr;
	}

	function set_text( newStr )
	{
		label.text = newStr;
		this.contentChanged(label);
		return newStr;
	}

	function set_value( newVal )
	{
		value = newVal;
		redraw();
		return value;
	}

	public function new(?parent) {
		super(parent);


		label = new h2d.Text(hxd.res.DefaultFont.get(), this);
		label.text = text;

		//label.textAlign = Right;


		
		b = new h2d.Graphics(this);
	
		var i = new h2d.Interactive(size, size, b);
		i.onClick = function(_) {
			value = !value;
			onClick( value );
			redraw();
		};
		redraw();
	}

	function redraw() {
		b.clear();
		b.beginFill(0x808080);
		b.drawRect(0, 0, size, size);
		b.beginFill(0);
		b.drawRect(1, 1, size-2, size-2);
		if( value ) {
			b.beginFill(0xC0C0C0);
			b.drawRect(2, 2, size-4, size-4);
		}
	}
}

@:uiComp("checkbox")
class CheckboxComp extends h2d.domkit.BaseComponents.DrawableComp  implements domkit.Component.ComponentDecl<CerastesCheckbox> {

	@:p var text: String;
	@:p(font) var font : h2d.Font;

	static function create( parent : h2d.Object ) {
		return new CerastesCheckbox(parent);
	}

	static function set_text(o:h2d.Object,v) {
		cast (o, CerastesCheckbox).text = v;
	}


}