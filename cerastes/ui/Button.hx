package cerastes.ui;

import cerastes.Tween.ColorTween;
import tweenxcore.color.RgbColor;
import tweenxcore.Tools.Easing;
import h2d.Object;
import hxd.res.BitmapFont;
import hxd.res.DefaultFont;
import cerastes.fmt.CUIResource;
import h3d.Vector;
import h2d.Bitmap;

enum Orientation
{
	None;
	CW;
	CW180;
	CCW;
	FlipX;
	FlipY;
	FlipXY;
}


enum ButtonState
{
	Default; // Can also be seen as an "off" state.
	On;
	Hover;
	UnHover;
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

enum ButtonHoverTween
{
	None;
	Linear;
	CircIn;
	CircOut;
	CircInOut;
	ExpoIn;
	ExpoOut;
	ExpoInOut;
	BounceIn;
	BounceOut;
	BounceInOut;
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
	public var font(default, set): String;
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

	// Tweens
	public var tweenHoverStartMode: ButtonHoverTween = None;
	public var tweenHoverEndMode: ButtonHoverTween = None;
	public var tweenDuration: Float = 0.3;
	// Sounds
	public var hoverSound: String;
	public var activateSound: String;
	public var deactivateSound: String;

	public var enabled(default, set): Bool = true;
	public var toggled(default, set): Bool = false;

	// similar to visible but when hidden we still reserve space
	public var hidden(default, set): Bool = false;

	public var state(default,set): ButtonState = Default;

	public var ellipsis(default, set): Bool;

	var elText: cerastes.ui.AdvancedText = null;
	var bitmap: h2d.Bitmap = null;

	var tweenTimers: Array<Tween> = [];

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
		ellipsis = v;

		return v;
	}

	function set_font(v)
	{
		var fnt = hxd.Res.loader.loadCache(v, BitmapFont ).toFont();
		if( elText == null )
			elText = new AdvancedText( fnt, this );
		else
			elText.font = fnt;

		font = v;

		return v;
	}

	function set_text(v)
	{
		if( v == null )
		{
			if( elText != null )
			{
				elText.remove();
				elText = null;
			}
		}
		else
		{
			if( elText == null )
				elText = new AdvancedText( DefaultFont.get(), this );

			elText.text = v;
		}
		return v;
	}

	function get_text()
	{
		if( elText == null )
			return null;

		return elText.text;
	}


	function setTile( t: String, c: Int, expoFunc: Float->Float )
	{
		var isValid = t != null && t.length > 0;
		// @todo: There's probably a less dumb way to do this?
		if( !isValid && ( c & 0xFF000000 ) == 0 && tweenDuration == 0 )
		{
			backgroundTile = null;
			return;
		}

		var t = isValid ? CUIResource.getTile( t ) : h2d.Tile.fromColor( 0xFFFFFF );

		backgroundTile = t;


		if( expoFunc != null && tweenDuration > 0 )
			tweenTimers.push( new ColorTween(tweenDuration, background.color.toColor(), c, (v) -> {
				background.color.setColor( Std.int( v ) );
				var a = ( Std.int(v) & 0xFF000000 ) >> 24;
			}, expoFunc ) );
		else
			background.color.setColor( c );


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
			set_state( On );
		else
			set_state( Default );

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
				setTints( defaultTile, defaultColor, defaultTextColor, None );

			case UnHover:
				if( toggled )
				{
					setTints( onTile, onColor, onTextColor, None );
					v = On;
				}
				else
				{
					setTints( defaultTile, defaultColor, defaultTextColor, tweenHoverEndMode );
					v = Default;
				}


			case Hover:
				setTints( hoverTile, hoverColor, hoverTextColor, tweenHoverStartMode );


			case Disabled:
				setTints( disabledTile, disabledColor, disabledTextColor, None );

			case On:
				setTints( onTile, onColor, onTextColor, None );
		}

		state = v;
		return v;
	}

	function updateTiles()
	{
		set_state(state);
	}

	function setTints( bitmapTile: String, bitmapColor: Int, textColor: Int, tweenMode: ButtonHoverTween )
	{
		var expoFunc = switch( tweenMode )
		{
			case None | null: null;
			case Linear: Easing.linear;
			case CircIn: Easing.circIn;
			case CircOut: Easing.circOut;
			case CircInOut: Easing.circInOut;
			case ExpoInOut: Easing.expoInOut;
			case ExpoIn: Easing.expoIn;
			case ExpoOut: Easing.expoOut;
			case BounceIn: Easing.bounceIn;
			case BounceOut: Easing.bounceOut;
			case BounceInOut: Easing.bounceInOut;
		}

		for( t in tweenTimers )
			t.abort();

		tweenTimers = [];


		setTile(bitmapTile, bitmapColor, expoFunc);



		if( elText != null )
		{
			if( expoFunc == null || tweenDuration == 0 )
				elText.textColor = textColor;
			else
				tweenTimers.push( new ColorTween(tweenDuration, elText.desiredColor.toColor(), textColor, (v) -> { elText.textColor = Std.int( v ); }, expoFunc ) );
		}

		for( c in children )
		{
			if( c == this.interactive || c == bitmap || c == elText || c == background )
				continue;

			var drawable = Std.downcast(c, h2d.Drawable);
			if( drawable != null )
			{
				if( expoFunc == null || tweenDuration == 0 )
					drawable.color.setColor((textColor & 0xFFFFFF) + 0xFF000000);
				else
					tweenTimers.push( new ColorTween(tweenDuration, drawable.color.toColor(), (textColor & 0xFFFFFF) + 0xFF000000, (v) -> {  drawable.color.setColor( Std.int( v )); }, expoFunc ) );
			}
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

			state = UnHover;

			if( onMouseOut != null && !hidden )
				onMouseOut(_);
		}

		interactive.onPush = function(_) {

			if( !enabled )
				return;

			if( buttonType == Toggle )
			{
				toggled = !toggled;
				if( toggled && activateSound != null )
				{
					#if hlwwise
					var evt = wwise.Api.Event.make(activateSound);
					wwise.Api.postEvent(evt);
					#end
				}
				else if( !toggled && deactivateSound != null )
				{
					#if hlwwise
					var evt = wwise.Api.Event.make(deactivateSound);
					wwise.Api.postEvent(evt);
					#end
				}
			}
			else
			{
				if( activateSound != null )
				{
					#if hlwwise
					var evt = wwise.Api.Event.make(activateSound);
					wwise.Api.postEvent(evt);
					#end
				}
			}

			if( onActivate != null && !hidden )
				onActivate(_);
		}

		interactive.onRelease = function(_) {

			if( !enabled )
				return;


			//state = Default;
		}


	}

	public function clone( ?parent: h2d.Object )
	{
		var b = new Button( parent );

		// button
		b.text = text;

		b.bitmapMode = bitmapMode;
		b.font = font;
		b.buttonType = buttonType;

		b.defaultColor = defaultColor;
		b.defaultTextColor = defaultTextColor;
		b.defaultTile = defaultTile;

		b.hoverColor = hoverColor;
		b.hoverTextColor = hoverTextColor;
		b.hoverTile = hoverTile;

		b.onColor = onColor;
		b.onTextColor = onTextColor;
		b.onTile = onTile;

		b.disabledColor = disabledColor;
		b.disabledTextColor = disabledTextColor;
		b.disabledTile = disabledTile;

		b.colorChildren = colorChildren;

		b.tweenHoverStartMode = tweenHoverStartMode;
		b.tweenHoverEndMode = tweenHoverEndMode;
		b.tweenDuration = tweenDuration;

		b.hoverSound = hoverSound;
		b.activateSound = activateSound;
		b.deactivateSound = deactivateSound;

		b.enabled = enabled;
		b.state = state;
		b.ellipsis = ellipsis;

		// flow
		b.minWidth = minWidth;
		b.minHeight = minHeight;
		b.maxWidth = maxWidth;
		b.maxHeight = maxHeight;
		b.multiline = multiline;
		b.visible = visible;
		b.layout = layout;
		b.overflow = overflow;
		b.verticalAlign = verticalAlign;
		b.horizontalAlign = horizontalAlign;

		b.paddingLeft = paddingLeft;
		b.paddingRight = paddingRight;
		b.paddingTop = paddingTop;
		b.paddingBottom = paddingBottom;



		return b;

	}

}