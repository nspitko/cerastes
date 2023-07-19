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
	public var orientation(default, set): Orientation = None;

	public var defaultColor: Int = 0xFFFFFFFF;
	public var defaultTextColor: Int = 0xFFFFFFFF;
	public var defaultTile(default, set): String;

	public var hoverColor: Int = 0xFFFFFFFF;
	public var hoverTextColor: Int = 0xFFFFFFFF;
	public var hoverTile: String;

	public var onColor: Int = 0xFFFFFFFF;
	public var onTextColor: Int = 0xFFFFFFFF;
	public var onTile: String;

	public var onHoverColor: Int = 0xFFFFFFFF;

	public var disabledColor: Int = 0xFFFFFFFF;
	public var disabledTextColor: Int = 0xFFFFFFFF;
	public var disabledTile: String;

	public var colorChildren: Bool = true;

	public var onActivate : (hxd.Event) -> Void;
	public var onRelease : (hxd.Event) -> Void;
	public var onMouseOver : (hxd.Event) -> Void;
	public var onMouseOut : (hxd.Event) -> Void;

	public var sdfSize: Int = 12;
	public var sdfAlpha: Float = 0.5;
	public var sdfSmoothing: Float = 10;

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

	function set_orientation(v)
	{
		orientation = v;
		needReflow = true;
		return orientation;
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
		var fnt = CUIResource.getFont(v, {sdfSize: sdfSize, sdfAlpha: sdfAlpha, sdfSmoothing: sdfSmoothing});
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

		// We probably don't ever want to hover/disable to a solid color from a valid tile.
		// But if we do, we should figure out a better way to solve this, as we may want to
		// simple not react to hover, for example, and specifying a tile would override
		// the disabled tile state.
		//
		// 6/4/23: Adding a really shitty workaround for non-tile buttons by just null checking
		// default tile. This needs redesigned...
		if( backgroundTile != null && !isValid && defaultTile != "" )
			return;

		// @todo: There's probably a less dumb way to do this?
		if( !isValid && ( c & 0xFF000000 ) == 0 && tweenDuration == 0 )
		{
			backgroundTile = null;
			return;
		}

		var t = isValid ? CUIResource.getTile( t ) : h2d.Tile.fromColor( 0xFFFFFF );

		backgroundTile = t;


		if( expoFunc == null && calculatedWidth == 0 && calculatedHeight == 0 && minWidth == 0 && minHeight == 0  )
		{
			// Inherit our dimensions from initial sprite if we didn't have anything set already
			minWidth = Std.int( t.width );
			minHeight = Std.int( t.height );
		}


		if( expoFunc != null && tweenDuration > 0 )
			tweenTimers.push( new ColorTween(tweenDuration, background.color.toColor(), c, (v) -> {
				background.color.setColor( Std.int( v ) );
				var a = ( Std.int(v) & 0xFF000000 ) >>> 24;
			}, expoFunc ) );
		else
		{
			background.color.setColor( c );
			var a = ( Std.int(c) & 0xFF000000 ) >>> 24;
			background.alpha = a/255;
		}


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
		// This is questionable; it prevents us from ever tracking state while the button
		// is disabled. However, the converse requires us to track the enable state of
		// buttons at the logic layer when toggling them from upstream actions (such as
		// ganged button rows). I THINK this is the better option, but when i revert
		// this later, WELP.
		if( !enabled )
			return false;

		if( v )
			set_state( On );
		else
			set_state( Default );

		toggled = v;
		return v;
	}

	function set_enabled( v: Bool )
	{
		if( v == enabled )
			return v ;

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
				if( toggled )
					setTints( hoverTile, onHoverColor, hoverTextColor, tweenHoverStartMode );
				else
					setTints( hoverTile, hoverColor, hoverTextColor, tweenHoverStartMode );


			case Disabled:
				setTints( disabledTile, disabledColor, disabledTextColor, None );

			case On:
				setTints( onTile, onColor, onTextColor, None );
		}

		needReflow = true;
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

		if( colorChildren )
		{
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

		// If we aren't specifying min dimensions and have no text, infer from our base tile
		if(  minWidth == null && minHeight == null && elText == null && backgroundTile != null )
		{
			minWidth = Math.floor( backgroundTile.width );
			minHeight = Math.floor( backgroundTile.height );
		}

		if( background != null )
		{
			switch( orientation )
			{
				case None:
				case CW:
					background.rotation = Math.PI / 2;
					background.x = background.tile.height;
				case CW180:
					background.rotation = Math.PI;
					background.x = background.tile.width;
					background.y = background.tile.height;
				case CCW:
					background.rotation = -Math.PI / 2;
					background.y = background.tile.width;
				case FlipX:
					background.scaleX = -1;
					background.x = background.tile.width;
				case FlipY:
					background.scaleY = -1;
					background.y = background.tile.height;
				case FlipXY:
					background.scaleX = -1;
					background.scaleY = -1;
					background.x = background.tile.width;
					background.y = background.tile.height;
			}
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


			if( onRelease != null && !hidden )
				onRelease(_);
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