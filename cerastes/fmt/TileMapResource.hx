package cerastes.fmt;

import h2d.TileGroup;
import cerastes.flow.Flow.FlowContext;
import cerastes.flow.Flow.FlowRunner;
import cerastes.flow.Flow.FlowFile;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import h2d.ScaleGrid;
import h2d.Tile;
import haxe.EnumTools;
import h3d.Vector;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;
import h2d.Bitmap;
import hxd.res.BitmapFont;
import h2d.Font;
import hxd.res.Loader;
import h2d.Object;
import haxe.Json;
import hxd.res.Resource;

enum abstract TileMapTileFlags(Int) from Int to Int
{
	var None		 		= 0;
	var FlipVertical 		= 1 << 1; // Flip Horizontally
	var FlipHorizontal 		= 1 << 2; // Flip Vertically
	var FlipDiagonal 		= 1 << 3; // Flip diagonally


	//
	var FlipFlags = TileMapTileFlags.FlipVertical | TileMapTileFlags.FlipHorizontal | TileMapTileFlags.FlipDiagonal;
}

@:structInit class TileMapLayerDataDef
{
	public var tileSheet: String = "";
	public var dataPacked: String = "";

	public var width: Int = 0;
	public var height: Int = 0;

	public var tileWidth: Int = 16;
	public var tileHeight: Int = 16;

	@noSerialize public var data: haxe.ds.Vector<Int> = null;

	public function pack()
	{
		var b = new hl.Bytes( data.length * 8 );

		for( i in 0 ... data.length )
			b.setI32(i * 4, data[i]);


		dataPacked = haxe.crypto.Base64.encode( b.toBytes( data.length ) );

	}

	public function unpack()
	{
		var decoded = haxe.crypto.Base64.decode( dataPacked );

		var len: Int = cast decoded.length / 8;
		data = new haxe.ds.Vector<Int>(len);

		for( i in 0 ... len )
		{
			data[i] = decoded.getInt32( i * 8 );
		}
	}

	public function resize(w: Int, h: Int )
	{
		if( width == w && height == h )
			return;

		var oldData = data;
		data = new haxe.ds.Vector<Int>(w * h * 2);
		for( x in 0 ... w )
		{
			for( y in 0 ... h )
			{
				if( x < width && y < height )
				{
					data[x + y * w * 2] = oldData[x + y * width];
					data[x + y * w * 2 + 1] = oldData[x + y * width + 1];
				}
				else
				{
					data[x + y * w * 2] = -1;
					data[x + y * w * 2 + 1] = 0;
				}
			}
		}

		width = w;
		height = h;
	}

	public inline function setIdx( x: Int, y: Int, v: Int, f: Int = 0 )
	{
		data[( x + y * width ) * 2] = v;
		data[( x + y * width ) * 2 + 1] = f;
	}

	public inline function getIdx(x, y)
	{
		return data[(x + y * width ) * 2];
	}

	public inline function getTile( src: Tile, t: Int )
	{
		// @todo: Cache??
		var tsw: Int = cast src.width / tileWidth;
		var tx: Int = t % tsw;
		var ty: Int = cast t / tsw;
		return src.sub( tx * tileWidth, ty * tileHeight, tileWidth, tileHeight );
	}

	public inline function getFlags( x, y )
	{
		return data[(x + y * width ) * 2 + 1];
	}
}

@:structInit class TileMapLayerDef
{
	@serializeType("cerastes.fmt.TileMapLayerData")
	public var tileData: TileMapLayerDataDef = {};

	public function resize(w: Int, h: Int )
	{
		tileData.resize(w, h);
	}
}

@:structInit class TileMapDef
{
	@serializeType("cerastes.fmt.TileMapLayer")
	public var layers: Array<TileMapLayerDef> = [];

	public var width: Int = 0;
	public var height: Int = 0;

	public function resize(w: Int, h: Int )
	{
		for( l in layers )
			l.resize(w, h);

		width = w;
		height = h;
	}

	public function create()
	{
		var out: TileMap;

		out = new TileMap( this );

		return out;
	}
}

@:structInit class TileMapFile
{
	public var version: Int = 1;

	public var tilemap: TileMapDef;


}

class TileMap extends h2d.Object
{
	var def: TileMapDef;
	public function new( map: TileMapDef, ?parent: h2d.Object )
	{
		super( parent );
		def = map;
	}

	public function rebuild()
	{
		removeChildren();

		for( l in def.layers )
		{
			if( l.tileData.tileSheet == null || l.tileData.tileSheet.length == 0 )
				continue;

			var tg = new TileGroup( Utils.getTile( l.tileData.tileSheet ), this );

			for( x in 0 ... def.width )
			{
				for( y in 0 ... def.height )
				{
					// @todo: We could cache this....
					var i = x + y * def.width;
					var t = l.tileData.getIdx( x, y );
					if( t >= 0 )
					{
						var tile = l.tileData.getTile( tg.tile, t );
						var flags = l.tileData.getFlags( x, y );

						var flipX = flags & TileMapTileFlags.FlipHorizontal != 0;
						var flipY = flags & TileMapTileFlags.FlipVertical != 0;
						var flipDiag = flags & TileMapTileFlags.FlipDiagonal != 0;

						var fx = flipX ? -1 : 1;
						var fy = flipY ? -1 : 1;
						var rot = 0.;

						var xo = fx == -1 ? l.tileData.tileWidth : 0;
						var yo = fy == -1 ? l.tileData.tileHeight : 0;

						if( flipDiag )
						{
							fy = -fy;

							if( flipX  != flipY )
							{
								rot = -Math.PI / 2;
							}
							else
							{
								rot = Math.PI / 2;

							}
						}


						tg.addTransform( x * l.tileData.tileWidth + xo, y * l.tileData.tileHeight + yo, fx, fy, rot, tile );

					}
				}
			}
		}
	}
}


class TileMapResource extends Resource
{
	var data: TileMapFile;

	static var minVersion = 1;
	static var version = 1;


	public function toObject( ?pos:haxe.PosInfos )
	{
		var data = getData();


	}


	public static function write( obj: TileMapFile, file: String )
	{


	}


	public function getData( ?cache: Bool = true ) : TileMapFile
	{
		if (data != null && cache) return data;

		//var u = new hxbit.Serializer();
		//data = u.unserialize(entry.getBytes(), CSDFile);
		//data = cast Json.parse( "cerastes.fmt.SpriteResource.CSDFile", entry.getText()  );
		var d : TileMapFile = CDParser.parse( entry.getText(), TileMapFile );
		if( cache )
			data = d;

		Utils.assert( d.version <= version, 'Warning: TileMap file generated with newer version than this parser supports (Have: ${d.version}, known: ${version})' );
		Utils.assert( d.version >= minVersion, 'Warning: TileMap file version newer than parser understands; parsing will probably fail!  (Have: ${d.version}, known: ${version})' );


		return d;
	}
}