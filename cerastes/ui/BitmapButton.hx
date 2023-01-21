package cerastes.ui;

import h3d.Vector;
import h2d.Bitmap;
import cerastes.ui.ScaleGridButton.Orientation;
import cerastes.ui.ScaleGridButton.ButtonState;


@:keep
class BitmapButton extends h2d.Interactive
{
	public var defaultTile(default, set): h2d.Tile = null;
	public var hoverTile: h2d.Tile = null;
	public var pressTile: h2d.Tile = null;
	public var disabledTile: h2d.Tile = null;

	public var defaultColor: Vector = new Vector(1,1,1,1);
	public var hoverColor: Vector = new Vector(1,1,1,1);
	public var pressColor: Vector = new Vector(1,1,1,1);

	public var disabledColor: Vector = new Vector(1,1,1,1); // Replaces defaultColor if disabled = true

	public var onActivate : (hxd.Event) -> Void;
	public var onMouseOver : (hxd.Event) -> Void;
	public var onMouseOut : (hxd.Event) -> Void;

	public var orientation(default, set): Orientation = None;
	public var enabled(default, set): Bool = true;


	// similar to visible but when hidden we still reserve space
	public var hidden(default, set): Bool = false;

	var state(default,set): ButtonState = Default;

	var bitmap: Bitmap;

	var colorFilter: h2d.filter.ColorMatrix;

	function set_hidden(v)
	{
		if( v )
		{
			alpha = 0;
			cursor = Hide;
		}
		else
		{
			alpha = 1;
			cursor = Button;
		}

		hidden = v;


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
		if( bitmap == null )
		{
			state = v;
			return v;
		}

		switch( v )
		{
			case Hover:
				if( hoverTile != null )
					bitmap.tile = hoverTile;
				else
					bitmap.tile = defaultTile;

				setTint( hoverColor );

			case Default:
				bitmap.tile = defaultTile;

				setTint( defaultColor );

			case Press:
				if( pressTile != null )
					bitmap.tile = pressTile;
				else
					bitmap.tile = defaultTile;

				if( pressColor != null )
					setTint( pressColor );

			case Disabled:
				if( disabledTile != null )
					bitmap.tile = disabledTile;
				else
					bitmap.tile = defaultTile;

				if( disabledColor != null )
					setTint( disabledColor );


		}

		state = v;
		return v;
	}

	function setTint( color: Vector )
	{
		if( color.r == 1 && color.g == 1 && color.b == 1 && color.a == 1)
		{
			alpha = 1;
			filter = null;
			return;
		}

		colorFilter.matrix._11 = color.r;
		colorFilter.matrix._22 = color.g;
		colorFilter.matrix._33 = color.b;
		alpha = color.a;

		filter = colorFilter;
	}

	function set_orientation(v)
	{

		orientation = v;
		reflow();
		return orientation;
	}

	public function reflow()
	{

		switch( orientation )
		{
			case None:
			case CW:
				bitmap.rotation = Math.PI / 2;
				bitmap.x = bitmap.tile.height;
			case CW180:
				bitmap.rotation = Math.PI;
				bitmap.x = bitmap.tile.width;
				bitmap.y = bitmap.tile.height;
			case CCW:
				bitmap.rotation = -Math.PI / 2;
				bitmap.y = bitmap.tile.width;
			case FlipX:
				bitmap.scaleX = -1;
				bitmap.x = bitmap.tile.width;
			case FlipY:
				bitmap.scaleY = -1;
				bitmap.y = bitmap.tile.height;
			case FlipXY:
				bitmap.scaleX = -1;
				bitmap.scaleY = -1;
				bitmap.x = bitmap.tile.width;
				bitmap.y = bitmap.tile.height;
		}

		state = state;
	}

	function set_defaultTile(v)
	{
		defaultTile = v;
		bitmap.tile = v;

		if( width == 0 && height == 0 && v != null )
		{
			width = v.width + v.dx;
			height = v.height + v.dy;
		}

		return v;
	}


	public function new(width: Float, height: Float, ?parent) {
		super(width,height,parent);

		colorFilter = new h2d.filter.ColorMatrix();

		//label.textAlign = Right;
		cursor = Button;
		//this.interactive.onClick = function(_) onClick();
		onOver = function(_) {
			if( !enabled )
				return;

			state = Hover;

			if( onMouseOver != null && !hidden )
				onMouseOver(_);
		}
		onOut = function(_) {
			if( !enabled )
				return;

			state = Default;

			if( onMouseOut != null && !hidden )
				onMouseOut(_);
		}
		onPush = function(_) {

			if( !enabled )
				return;

			state = Press;

			if( onActivate != null && !hidden )
				onActivate(_);
		}

		onRelease = function(_) {

			if( !enabled )
				return;

			state = Default;
		}

		bitmap = new Bitmap(null, this);

		this.reflow();
	}

}