package cerastes.ui;

import h2d.RenderContext;
import h2d.Tile;

@:keep
class AdvancedBitmap extends h2d.Bitmap {

	public var clipX(default,set) : Int = 0;
	public var clipY(default,set) : Int = 0;

	public var scrollX(default,set) : Int = 0;
	public var scrollY(default,set) : Int = 0;

	public function new( ?tile : Tile, ?parent : h2d.Object ) {
		super(parent);
	}


	function set_clipX(w) {
		if( clipX == w ) return w;
		clipX = w;
		onContentChanged();
		return w;
	}

	function set_clipY(h) {
		if( clipY == h ) return h;
		clipY = h;
		onContentChanged();
		return h;
	}

	function set_scrollX(w) {
		if( scrollX == w ) return w;
		scrollX = w;
		onContentChanged();
		return w;
	}

	function set_scrollY(h) {
		if( scrollY == h ) return h;
		scrollY = h;
		onContentChanged();
		return h;
	}


	override function draw( ctx : RenderContext ) {
		if( clipX == 0 && clipY == 0 ) {
			emitTile(ctx,tile);
			return;
		}
		if( tile == null ) tile = h2d.Tile.fromColor(0xFF00FF);

		var ow = tile.width;
		var oh = tile.height;

		var osx = tile.x;
		var osy = tile.y;

		var newx = clipX > 0 ? clipX : tile.width;
		var newy = clipY > 0 ? clipY : tile.height;

		@:privateAccess {

			tile.setSize( newx, newy );

			tile.setPosition(osx + scrollX, osy + scrollY );


		}
		emitTile(ctx,tile);
		@:privateAccess {
			tile.setSize( ow, oh);
			tile.setPosition(osx, osy);
		}
	}

}
