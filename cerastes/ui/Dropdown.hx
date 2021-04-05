package cerastes.ui;

import h2d.Dropdown;

class DropdownParser extends h2d.domkit.BaseComponents.CustomParser
{
	function parseOptions( value ) : Array<String> {
		return switch( value : domkit.CssValue ) {
        case VList(vl): [for( v in vl ) parseString(v)]; // comma separated values
        default: [parseString(value)]; // single value
        }
	}
}

class CerastesDropdown extends Dropdown
{
	public var selectedItemString(get, null) : String;
	public var font(default, set): h2d.Font;

	public function new(?parent) 
	{
		super(parent);

		minHeight = maxHeight = 10;
		tileArrow = tileArrowOpen = h2d.Tile.fromColor(0x404040, maxHeight - 2, maxHeight - 2);

		dropdownList.backgroundTile = backgroundTile;
	}

	override function addItem( v : h2d.Object )
	{
		if( font != null )
			cast (v, h2d.Text).font = font;
		
		super.addItem( v );
	}

	public function addItemString( v : String )
	{
		var itm = new h2d.Text(font != null ? font : hxd.res.DefaultFont.get());
		itm.text = v;
		
		super.addItem( itm );
	}

	function set_font( newStr )
	{
		font = newStr;
		for( item in items )
			cast (item, h2d.Text).font = newStr;
		return newStr;
	}

	function get_selectedItemString() {
		return items.length > 0 && selectedItem != -1 ? cast (items[ selectedItem ], h2d.Text).text : null;
	}

	public function removeItems() {
		items = [];
		dropdownList.removeChildren();
		@:privateAccess selectedItem = -1;
		//var width = Std.int(DropdownList.getSize().width);
		//if( maxWidth != null && width > maxWidth ) width = maxWidth;
		//minWidth = hxd.Math.imax(minWidth, Std.int(width-arrow.getSize().width));
	}
}

@:uiComp("dropdown") 
class DropdownComp extends h2d.domkit.BaseComponents.DrawableComp  implements domkit.Component.ComponentDecl<CerastesDropdown> 
{

	@:p(font) var font : h2d.Font;

	static function create( parent : h2d.Object ) {
		return new CerastesDropdown(parent);
	}

	static function addItem( o : CerastesDropdown, v : h2d.Object  ) {
		o.addItem( v );

		
	}

}
