package cerastes.ui;

import hxd.res.DefaultFont;
import h2d.Object;

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

	public var onActivate : (hxd.Event) -> Void;

	public var orientation(default, set): Orientation = None;

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
			if( hoverTile != null )
				this.backgroundTile = hoverTile;
		}
		this.interactive.onOut = function(_) {
			this.backgroundTile = defaultTile;
		}
		this.interactive.onPush = function(_) {
			if( pressTile != null )
				this.backgroundTile = pressTile;

			if( onActivate != null && alpha > 0 )
				onActivate(_);

		}

		this.interactive.onRelease = function(_) {
			if( hoverTile != null )
				this.backgroundTile = defaultTile;
		}

		this.reflow();
	}

}

