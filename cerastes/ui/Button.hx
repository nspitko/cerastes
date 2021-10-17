package cerastes.ui;

import hxd.res.DefaultFont;
import h2d.Object;

@:keep
class Button extends h2d.Flow
{

	public var defaultTile(default, set): h2d.Tile = null;
	public var hoverTile: h2d.Tile = null;
	public var pressTile: h2d.Tile = null;

	public var onActivate : (hxd.Event) -> Void;

	function set_defaultTile(v)
	{
		defaultTile = v;
		backgroundTile = v;

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

			if( onActivate != null )
				onActivate(_);

		}

		this.interactive.onRelease = function(_) {
			if( hoverTile != null )
				this.backgroundTile = defaultTile;
		}

		this.reflow();
	}

}

