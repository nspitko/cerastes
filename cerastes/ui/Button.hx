package cerastes.ui;

import h2d.Object;
import hxd.res.BitmapFont;
import hxd.res.DefaultFont;
import cerastes.fmt.CUIResource;
import h3d.Vector;
import h2d.Bitmap;

enum ButtonState
{
	Default; // Can also be seen as an "off" state.
	On;
	Hover;
	Disabled;
}

enum ButtonType
{
	Momentary;
	Toggle;
}

enum BitmapMode
{
	ButtonTile;
	ButtonScalegrid;
}

@:keep
interface IButton
{

	public var onActivate : (hxd.Event) -> Void;
	public var onMouseOver : (hxd.Event) -> Void;
	public var onMouseOut : (hxd.Event) -> Void;

	/**
	 * For toggle buttons, their on/off state
	 */
	public var toggled(default, set): Bool;

	/**
	 * Disabled buttons don't fire events and have special styling.
	 */
	public var enabled(default, set): Bool;

	/**
	 * Hidden buttons similar to visible = false but still take up space (useful for flows)
	 */
	public var hidden(default, set): Bool;

}

@:keep
class Button extends h2d.Flow implements IButton
{
	public var text(get, set): String;

	public var bitmapMode: BitmapMode = ButtonTile;
	public var font(never, set): String;
	public var buttonType: ButtonType;

	public var defaultColor: Int = 0xFFFFFFFF;
	public var defaultTextColor: Int = 0xFFFFFFFF;
	public var defaultTile(default, set): String;

	public var hoverColor: Int = 0xFFFFFFFF;
	public var hoverTextColor: Int = 0xFFFFFFFF;
	public var hoverTile: String;

	public var onColor: Int = 0xFFFFFFFF;
	public var onTextColor: Int = 0xFFFFFFFF;
	public var onTile: String;

	public var disabledColor: Int = 0xFFFFFFFF;
	public var disabledTextColor: Int = 0xFFFFFFFF;
	public var disabledTile: String;

	public var colorChildren: Bool = true;

	public var onActivate : (hxd.Event) -> Void;
	public var onMouseOver : (hxd.Event) -> Void;
	public var onMouseOut : (hxd.Event) -> Void;

	// Sounds
	public var hoverSound: String;

	public var enabled(default, set): Bool = true;
	public var toggled(default, set): Bool = false;

	// similar to visible but when hidden we still reserve space
	public var hidden(default, set): Bool = false;

	public var state(default,set): ButtonState = Default;

	public var ellipsis(never, set): Bool;

	var elText: cerastes.ui.AdvancedText = null;
	var bitmap: h2d.Bitmap = null;

	function set_defaultTile(v)
	{
		defaultTile = v;
		updateTiles();
		return v;
	}

	function set_ellipsis(v)
	{
		if( elText == null )
			elText = new AdvancedText( DefaultFont.get(), this );

		elText.ellipsis = v;

		return v;
	}

	function set_font(v)
	{
		var fnt = hxd.Res.loader.loadCache(v, BitmapFont ).toFont();
		if( elText == null )
			elText = new AdvancedText( fnt, this );
		else
			elText.font = fnt;

		return v;
	}

	function set_text(v)
	{
		if( elText == null )
			elText = new AdvancedText( DefaultFont.get(), this );

		elText.text = v;
		return v;
	}

	function get_text()
	{
		if( Utils.assert( elText != null, 'Tried to set text on button ${name} but it doesn\'t have an initialized text object!') )
			return null;

		return elText.text;
	}


	function setTile( t: String, c: Int )
	{
		var isValid = t != null && t.length > 0;
		if( !isValid && ( c & 0xFF000000 ) == 0 )
		{
			backgroundTile = null;
			return;
		}
		var t = isValid ? CUIResource.getTile( t ) : h2d.Tile.fromColor( c );


		backgroundTile = t;
		//reflow();
	}

	function set_hidden(v)
	{
		if( v )
		{
			alpha = 0;
			interactive.cursor = Hide;
		}
		else
		{
			alpha = 1;
			interactive.cursor = Button;
		}

		hidden = v;


		return v;
	}

	function set_toggled( v: Bool )
	{
		if( v )
			state = On;
		else
			state = Default;

		toggled = v;
		return v;
	}

	function set_enabled( v: Bool )
	{
		if( v )
			state = Default;
		else
			state = Disabled;

		enabled = v;
		return v;
	}

	function set_state(v: ButtonState)
	{
		switch( v )
		{
			case Default:
				setTints( defaultTile, defaultColor, defaultTextColor );

			case Hover:
				setTints( hoverTile, hoverColor, hoverTextColor );

			case Disabled:
				setTints( disabledTile, disabledColor, disabledTextColor );

			case On:
				setTints( onTile, onColor, onTextColor );
		}

		state = v;
		return v;
	}

	function updateTiles()
	{
		set_state(state);
	}

	function setTints( bitmapTile: String, bitmapColor: Int, textColor: Int )
	{
		setTile(bitmapTile, bitmapColor);


		if( elText != null )
		{
			elText.textColor = textColor;
		}

		for( c in children )
		{
			if( c == this.interactive || c == bitmap || c == elText || c == background )
				continue;

			var drawable = Std.downcast(c, h2d.Drawable);
			if( drawable != null )
				drawable.color.setColor((textColor & 0xFFFFFF) + 0xFF000000);
		}
	}

	public override function onBeforeReflow()
	{
		if( elText != null && maxWidth > 0 )
		{
			elText.maxWidth = maxWidth - paddingLeft - paddingRight;
		}

		for( c in children )
		{
			if( c == this.interactive || c == bitmap || c == elText || c == background )
				continue;

			var props = getProperties(c);
			props.isAbsolute = true;
		}
	}

	public override function contentChanged(s: Object)
	{
		super.contentChanged(s);
		// Force tints to be reset
		set_state( state );
	}


	public function new(?parent)
	{
		super(parent);

		enableInteractive = true;

		interactive.cursor = Button;

		interactive.onOver = function(_) {
			if( !enabled )
				return;

			state = Hover;

			if( !hidden )
			{

				if( onMouseOver != null )
					onMouseOver(_);

				if( hoverSound != null )
				{
					#if hlwwise
					var evt = wwise.Api.Event.make(hoverSound);
					wwise.Api.postEvent(evt);
					#end
				}

			}
		}
		interactive.onOut = function(_) {
			if( !enabled )
				return;

			state = Default;

			if( onMouseOut != null && !hidden )
				onMouseOut(_);
		}

		interactive.onPush = function(_) {

			if( !enabled )
				return;

			//state = Press;

			if( onActivate != null && !hidden )
				onActivate(_);
		}

		interactive.onRelease = function(_) {

			if( !enabled )
				return;


			//state = Default;
		}


	}

}