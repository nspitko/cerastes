package cerastes;

import h2d.Bitmap;
import h3d.mat.Data.TextureFormat;
import hxd.Pixels;
import h3d.mat.Data.TextureFlags;
import hxd.PixelFormat;
import h3d.mat.Texture;
import h2d.col.Point;
import cerastes.Utils.*;
import h2d.col.Bounds;


interface PixelPerfectCollidable
{
	public var position: h2d.col.Point;
	
	public var active: Bool;
	public var layer: Int;

	public var bitmapCollision : h2d.Bitmap;
}

interface PixelPerfectCollidableDetector
{
	public var position: h2d.col.Point;
	public var layer: Int;

	public var collisionPixels: Pixels;
}


class PixelCollisionManager
{
	public static var instance(default, null):PixelCollisionManager = new PixelCollisionManager();

	var objects = new Array<PixelPerfectCollidable>();
	public var layers = new Map<Int,Texture>();
	var pixels = new Map<Int,Pixels>();
	public var scenes = new Map<Int,h2d.Scene>();

	public var width: Int;
	public var height: Int;

	var dirty = true;

	public function new()
	{
	}

	public function register( other: PixelPerfectCollidable )
	{
		assert(width > 0 && height > 0, "Dimensions must be set before registering colldables");
		
		objects.push( other );
		if( !layers.exists( other.layer ) )
		{
			layers.set(other.layer,new Texture(width, height,[ TextureFlags.Target] ));
			var s = new h2d.Scene();
			//s.setFixedSize(640,480);
			scenes.set(other.layer, s);
		}
		scenes.get(other.layer).addChild(other.bitmapCollision);
	}

	public function unregister( other: PixelPerfectCollidable )
	{
		assert( objects.remove( other ), "Tried to unregister a collidable but it couldn't be found.");
	}

	public function tick( delta: Float )
	{
		dirty = true;
	}

	public function updateLayers( ?force: Bool )
	{
		if( !dirty && !force )
			return;


		for( idx in scenes.keys())
		{
			var scene = scenes.get(idx);
			var b : Bitmap;
			if( !pixels.exists(idx))
			{
				b = scene.captureBitmap( );
			
				pixels.set(idx, b.tile.getTexture().capturePixels());
			}
		}

		dirty = false;

		return;
		// this method also works but is much slower.
		for( idx in layers.keys())
		{
			var layer = layers.get(idx);
			layer.clear(0);

			for( object in objects )
			{
				if( object.layer != idx)
					continue;

				object.bitmapCollision.drawTo(layer);
			}

			pixels.set(idx, layer.capturePixels() );
		}

		

	
	}

	public function checkCollision( other: PixelPerfectCollidableDetector): Bool
	{
		updateLayers();
		// Hokay here we go. SHITS GONNA BE SLOW SON.
		// @todo cache me
		//var otherPixels = other.bitmapCollision.tile.getTexture().capturePixels();
		//var croppedPixels = otherPixels.sub( other.bitmapCollision.tile.x, other.bitmapCollision.tile.y, other.bitmapCollision.tile.width, other.bitmapCollision.tile.height );
		for( x in 0...other.collisionPixels.width )
		{
			for(y in 0...other.collisionPixels.height)
			{
				var otherColor = other.collisionPixels.getPixel(x,y);
				if( otherColor != 0 && otherColor != -16777216 ) // Alpha channel fuckery
				{
					var lx : Int = Math.floor( other.position.x + x );
					var ly : Int = Math.floor( other.position.y + y );
					assert(pixels.exists(other.layer), "Tried to check against invalid layer "+other.layer+"??");
					var color = pixels.get(other.layer).getPixel(lx, ly);
					if( color != 0 && color != -16777216 ) 
					{
						
						return true;
					}
				}
				
			}
		}

		return false;
	}
}