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

	var bitmap: Bitmap;

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

					if( hoverColor != null )
						bitmap.color = hoverColor;

				case Default:
					bitmap.tile = defaultTile;

					if( visited && visitedColor != null )
						bitmap.color = visitedColor;
					else if( defaultColor != null )
						bitmap.color = defaultColor;

				case Press:
					if( pressTile != null )
						bitmap.tile = pressTile;
					else
						bitmap.tile = defaultTile;

					if( pressColor != null )
						bitmap.color = pressColor;

				case Disabled:
					if( disabledTile != null )
						bitmap.tile = disabledTile;
					else
						bitmap.tile = defaultTile;


					if( disabledColor != null )
						bitmap.color = disabledColor;

			}

			state = v;
			return v;
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
					bitmap.x = bitmap.height;
				case CW180:
					bitmap.rotation = Math.PI;
					bitmap.x = bitmap.width;
					bitmap.y = bitmap.height;
				case CCW:
					bitmap.rotation = -Math.PI / 2;
					bitmap.y = bitmap.width;
				case FlipX:
					bitmap.scaleX = -1;
					bitmap.x = bitmap.width;
				case FlipY:
					bitmap.scaleY = -1;
					bitmap.y = bitmap.height;
				case FlipXY:
					bitmap.scaleX = -1;
					bitmap.scaleY = -1;
					bitmap.x = bitmap.width;
					bitmap.y = bitmap.height;
			}

			state = state;
		}

		function set_defaultTile(v)
		{
			defaultTile = v;
			bitmap.tile = v;

			if( width == 0 && height == 0 && v != null )
			{
				width = v.width;
				height = v.height;
			}

			return v;
		}


		public function new(width: Float, height: Float, ?parent) {
			super(width,height,parent);

			//label.textAlign = Right;
			cursor = Button;
			//this.interactive.onClick = function(_) onClick();
			onOver = function(_) {
				state = Hover;

				if( onMouseOver != null && alpha > 0 )
					onMouseOver(_);
			}
			onOut = function(_) {
				state = Default;

				if( onMouseOut != null && alpha > 0 )
					onMouseOut(_);
			}
			onPush = function(_) {
				state = Press;

				if( onActivate != null && alpha > 0 )
					onActivate(_);
			}

			onRelease = function(_) {
				state = Default;
			}

			bitmap = new Bitmap(null, this);

			this.reflow();
		}

}