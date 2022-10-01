package cerastes.ui;

import h3d.Vector;
import hxd.res.DefaultFont;
import h2d.Object;

enum ButtonState
{
	Default;
	Hover;
	Press;
	Disabled;
}

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

@:keep
class Button extends h2d.Flow
{

	public var defaultTile(default, set): h2d.Tile = null;
	public var hoverTile: h2d.Tile = null;
	public var pressTile: h2d.Tile = null;

	public var defaultColor: Vector = new Vector(1,1,1,1);
	public var hoverColor: Vector = new Vector(1,1,1,1);
	public var pressColor: Vector = new Vector(1,1,1,1);

	public var visitedColor: Vector = new Vector(1,1,1,1); // Replaces defaultColor if visited = true
	public var disabledColor: Vector = new Vector(1,1,1,1); // Replaces defaultColor if disabled = true

	public var onActivate : (hxd.Event) -> Void;
	public var onMouseOver : (hxd.Event) -> Void;
	public var onMouseOut : (hxd.Event) -> Void;

	public var orientation(default, set): Orientation = None;

	//
	public var visited(default, set) = false;

	// similar to visible but when hidden we still reserve space
	public var hidden(default, set): Bool = false;

	var state(default,set): ButtonState = Default;

	function set_hidden(v)
	{
		if( v )
		{
			alpha = 0;
			this.interactive.cursor = Hide;
		}
		else
		{
			alpha = 1;
			this.interactive.cursor = Button;
		}


		return v;
	}
	function set_visited(v)
	{
		visited = v;
		state = state;
		return v;
	}

	function set_state(v: ButtonState)
	{
		if( this.background  == null || this.backgroundTile == null )
		{
			state = v;
			return v;
		}

		switch( v )
		{
			case Hover:
				if( hoverTile != null )
					this.backgroundTile = hoverTile;

				if( hoverColor != null )
					this.background.color = hoverColor;

			case Default:
				this.backgroundTile = defaultTile;

				if( visited && visitedColor != null )
					this.background.color = visitedColor;
				else if( defaultColor != null )
					this.background.color = defaultColor;

			case Press:
				if( pressTile != null )
					this.backgroundTile = pressTile;

				if( pressColor != null )
					this.background.color = pressColor;

			case Disabled:
				this.backgroundTile = defaultTile;

				if( disabledColor != null )
					this.background.color = disabledColor;

		}

		state = v;
		return v;
	}

	function set_orientation(v)
	{
		needReflow = true;
		orientation = v;
		return orientation;
	}

	override function reflow()
	{
		super.reflow();
		if( background == null ) return;
		switch( orientation )
		{
			case None:
			case CW:
				background.rotation = Math.PI / 2;
				background.x = background.height;
			case CW180:
				background.rotation = Math.PI;
				background.x = background.width;
				background.y = background.height;
			case CCW:
				background.rotation = -Math.PI / 2;
				background.y = background.width;
			case FlipX:
				background.scaleX = -1;
				background.x = background.width;
			case FlipY:
				background.scaleY = -1;
				background.y = background.height;
			case FlipXY:
				background.scaleX = -1;
				background.scaleY = -1;
				background.x = background.width;
				background.y = background.height;
		}

		state = state;
	}

	function set_defaultTile(v)
	{
		defaultTile = v;
		backgroundTile = v;

		//background.y = background.width;

		return v;
	}


	public function new(?parent) {
		super(parent);

		//label.textAlign = Right;


		this.enableInteractive = true;
		this.interactive.cursor = Button;
		//this.interactive.onClick = function(_) onClick();
		this.interactive.onOver = function(_) {
			state = Hover;

			if( onMouseOver != null && alpha > 0 )
				onMouseOver(_);
		}
		this.interactive.onOut = function(_) {
			state = Default;

			if( onMouseOut != null && alpha > 0 )
				onMouseOut(_);
		}
		this.interactive.onPush = function(_) {
			state = Press;

			if( onActivate != null && alpha > 0 )
				onActivate(_);
		}

		this.interactive.onRelease = function(_) {
			state = Default;
		}

		this.reflow();
	}

}

