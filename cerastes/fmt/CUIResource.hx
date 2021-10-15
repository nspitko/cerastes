package cerastes.fmt;

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

// Cerastes UI
@:structInit class CUIObject {

	public var type: String;
	public var name: String;
	public var children: Array<CUIObject>;

	public var x: Float = 0;
	public var y: Float = 0;
	public var rotation: Float = 0;
	public var scaleX: Float = 1;
	public var scaleY: Float = 1;
}

@:structInit class CUIDrawable extends CUIObject {
	public var color: Int = 0xFFFFFFFF;
}

@:structInit class CUIInteractive extends CUIDrawable {
	public var cursor: hxd.Cursor = hxd.Cursor.Default;
	public var isEllipse: Bool = false ;
	public var backgroundColor: Int = 0xFFFFFFFF;

	public var width: Float;
	public var height: Float;
}

@:structInit class CUIText extends CUIDrawable {
	public var text: String = "";
	public var font: String = "";
	// sdf
	public var sdfSize: Float;
	public var sdfAlpha: Float;
	public var sdfSmoothing: Float;

	public var textAlign: h2d.Text.Align;

	public var maxWidth: Null<Float>;
}


@:structInit class CUIBitmap extends CUIDrawable {
	public var tile: String;
	public var width: Float;
	public var height: Float;
}

@:structInit class CUIFlow extends CUIDrawable {
	public var layout: h2d.Flow.FlowLayout = Horizontal;
	public var verticalAlign: h2d.Flow.FlowAlign = Top;
	public var horizontalAlign: h2d.Flow.FlowAlign = Left;
	public var overflow: h2d.Flow.FlowOverflow = Limit;

	public var minWidth: Int;
	public var minHeight: Int;
	public var maxWidth: Int;
	public var maxHeight: Int;

	public var horizontalSpacing: Int;
	public var verticalSpacing: Int;

}

@:structInit class CUIFile {
	public var version: Int;
	public var root: CUIObject;
}

class CUIResource extends Resource
{
	var data: CUIFile;

	static var minVersion = 1;
	static var version = 1;

	public function toObject(?parent = null)
	{
		var data = getData();
		Utils.assert( data.version <= version, "Warning: CUI generated with newer version than this parser supports" );
		Utils.assert( data.version >= minVersion, "Warning: CUI version newer than parser understands; parsing will probably fail!" );

		var root = new Object(parent);

		recursiveCreateObjects(data.root, root);

		return root;
	}

	public static function recursiveCreateObjects( entry: CUIObject, parent: Object )
	{
		var e = createObject(entry);
		parent.addChild(e);

		if( entry.children != null )
			for( c in entry.children )
				recursiveCreateObjects( c, e );
	}

	public static function updateObject( entry: CUIObject, target: Object )
	{
		recursiveSetProperties(target, entry);
	}

	static function createObject( entry: CUIObject ) : h2d.Object
	{
		var obj: Object = null;

		switch( entry.type )
		{
			case "h2d.Object":
				obj = new h2d.Object();

			case "h2d.Flow":
				obj = new h2d.Flow();
			case "h2d.Text":
				obj = new h2d.Text( null );

			case "h2d.Bitmap":
				obj = new Bitmap( );

			case "h2d.Mask":
				Utils.error("STUB");
				//var props : CUIM
				//obj = new h2d.Mask(props.get("width"),props.get("height"));

			case "h2d.Interactive":
				var props: CUIInteractive = cast entry;
				obj = new h2d.Interactive(props.width,props.height);

			default:
				Utils.error('CUI: Cannot create unknown type ${entry.type}; ignoring!!');

		}

		obj.name = entry.name;

		recursiveSetProperties(obj, entry);


		return obj;
	}

	static function recursiveSetProperties(obj: Object, entry: CUIObject)
	{
		setProperties(obj, entry.type, entry);

		var s =  Type.getSuperClass( Type.getClass( obj ) );
		while( s != null )
		{
			setProperties( obj, Type.getClassName(s), entry );

			s = Type.getSuperClass( s );
		}
	}

	static function setProperties( obj: Object, type: String, entry: CUIObject )
	{
		//var props = entry.props;

		switch( type )
		{
			case "h2d.Object":
				obj.x = entry.x;
				obj.y = entry.y;
				obj.rotation = entry.rotation;

				obj.scaleX = entry.scaleX;
				obj.scaleY = entry.scaleY;

			case "h2d.Drawable":
				var e: CUIDrawable = cast entry;
				var o: h2d.Drawable = cast obj;

				o.color.setColor( e.color );


			case "h2d.Text":
				var o = cast(obj, h2d.Text);
				var e: CUIText = cast entry;
				o.text = e.text;

				o.textAlign = e.textAlign;
				o.maxWidth = e.maxWidth;


			case "h2d.Bitmap":
				var o = cast(obj, h2d.Bitmap);
				var e: CUIBitmap = cast entry;


				if(e.tile.charAt(0) == "#" )
					o.tile = Tile.fromColor( Std.parseInt( e.tile.substr(1) ) );
				else if ( e.tile.indexOf(".atlas") != -1 )
				{

					var atlasPos = e.tile.indexOf(".atlas") + 6;
					var atlasName = e.tile.substr( 0,  atlasPos );
					var tileName = e.tile.substr(atlasPos + 1);

					o.tile = hxd.Res.loader.loadCache(atlasName, hxd.res.Atlas ).get( tileName );
				}
				else
					o.tile = hxd.Res.loader.loadCache( e.tile, hxd.res.Image ).toTile();

				o.width = e.width;
				o.height = e.height;

			case "h2d.Flow":
				var o = cast(obj, h2d.Flow);
				var e: CUIFlow = cast entry;

				o.layout = e.layout;

				o.verticalAlign = e.verticalAlign;
				o.horizontalAlign = e.horizontalAlign;

				o.overflow = e.overflow;

				o.minWidth = e.minWidth;
				o.minHeight = e.minHeight;

				o.verticalSpacing = e.verticalSpacing;
				o.horizontalSpacing = e.horizontalSpacing;
/*
			case "h2d.Mask":
				var o = cast(obj, h2d.Mask);
				o.scrollX = props["scroll_x"];
				o.scrollY = props["scroll_y"];
*/
			case "h2d.Interactive":
				var o = cast(obj, h2d.Interactive);
				var e: CUIInteractive = cast entry;

				o.isEllipse = e.isEllipse;
				o.backgroundColor = e.backgroundColor;
				o.cursor = e.cursor;


			default:


		}
	}



	public static function writeObject( def: CUIObject, obj: Object, file: String )
	{

		var cui: CUIFile = {
			version: version,
			root: def
		};

		var s = new haxe.Serializer();
		s.serialize(cui);

		#if hl
		sys.io.File.saveContent( Utils.fixWritePath(file,"cui"),s.toString());
		#end
	}


	public function getData() : CUIFile
	{
		if (data != null) return data;



		var u = new haxe.Unserializer(entry.getText());
		data = u.unserialize();


		return data;
	}
}