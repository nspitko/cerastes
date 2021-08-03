package cerastes.fmt;

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

@:structInit class CUIElementDef implements hxbit.Serializable {
	@:s public var type: String;
	@:s public var name: String;
	@:s public var props: Map<String,Dynamic>;
	@:s public var children: Array<CUIElementDef>;

}

@:structInit class CUIFile implements hxbit.Serializable {
	@:s public var version: Int;
	@:s public var root: CUIElementDef;
}

class CUIResource extends Resource
{
	var data: CUIFile;

	static var minVersion = 1;
	static var version = 1;

	public function toObject()
	{
		var data = getData();
		Utils.assert( data.version <= version, "Warning: CUI generated with newer version than this parser supports" );
		Utils.assert( data.version >= minVersion, "Warning: CUI version newer than parser understands; parsing will probably fail!" );

		var root = new Object();

		recursiveCreateObjects(data.root, root);

		return root;
	}

	public static function recursiveCreateObjects( entry: CUIElementDef, parent: Object )
	{
		var e = createObject(entry);
		parent.addChild(e);

		if( entry.children != null )
			for( c in entry.children )
				recursiveCreateObjects( c, e );
	}

	static function createObject( entry: CUIElementDef ) : h2d.Object
	{
		var obj: Object = null;

		var props = entry.props;

		switch( entry.type )
		{
			case "h2d.Object":
				obj = new h2d.Object();
			case "h2d.Flow":
				obj = new h2d.Flow();
				var flow : h2d.Flow = cast obj;
				flow.verticalAlign = Bottom;
				flow.horizontalAlign = Left;
			case "h2d.Text":
				var fe = hxd.Res.loader.load( props.get("font") );
				var res = new BitmapFont( fe.entry );

				obj = new h2d.Text( res.toFont() );

			case "h2d.Bitmap":
				var tile = hxd.Res.loader.load( props.get("tile") ).toTile();
				obj = new Bitmap( tile );

			default:
				Utils.error('CUI: Cannot create unknown type ${entry.type}; ignoring!!');

		}

		obj.name = entry.name;

		setProperties(obj, entry.type, entry);

		var s =  Type.getSuperClass( Type.getClass( obj ) );
		while( s != null )
		{
			setProperties( obj, Type.getClassName(s), entry );

			s = Type.getSuperClass( s );
		}

		return obj;
	}

	static function setProperties( obj: Object, type: String, entry: CUIElementDef )
	{
		var props = entry.props;

		switch( type )
		{
			case "h2d.Object":
				obj.x = props["x"];
				obj.y = props["y"];


			case "h2d.Text":
				var o = cast(obj, h2d.Text);
				o.text = props["text"];
				if( props.exists("text_align") )
					o.textAlign = EnumTools.createByIndex(h2d.Text.Align, props["text_align"] );
				if( props.exists("max_width") )
					o.maxWidth = props["max_width"];

			case "h2d.Bitmap":
				var o = cast(obj, h2d.Bitmap);
				o.tile = hxd.Res.loader.load( props["tile"] ).toTile();

				if( props.exists("width") && props["width"] > 0)
					o.width = props["width"];

				if( props.exists("height") && props["height"] > 0)
					o.height = props["height"];

			case "h2d.Drawable":
				var o = cast(obj, h2d.Drawable);
				if( props.exists("color"))
					o.color.setColor(props["color"]);

			case "h2d.Flow":
				var o = cast(obj, h2d.Flow);
				if( props.exists("layout") )
					o.layout = EnumTools.createByIndex( h2d.Flow.FlowLayout, props["layout"] );

				if( props.exists("vertical_align") )
					o.verticalAlign = EnumTools.createByIndex( h2d.Flow.FlowAlign, props["vertical_align"] );

				if( props.exists("horizontal_align") )
					o.horizontalAlign = EnumTools.createByIndex( h2d.Flow.FlowAlign, props["horizontal_align"] );


			default:


		}
	}

	public static function write( def: CUIElementDef, file: String )
	{
		var cui: CUIFile = {
			version: version,
			root: def
		};

		var s = new hxbit.Serializer();
		var bytes = s.serialize(cui);

		#if hl
		// @todo We should peek the config to find out where res is; don't just assume
		sys.io.File.saveBytes('res/${file}',bytes);
		#end
	}

	public function getData() : CUIFile
	{
		if (data != null) return data;

		var u = new hxbit.Serializer();
		data = u.unserialize(entry.getBytes(), CUIFile);

		return data;
	}
}