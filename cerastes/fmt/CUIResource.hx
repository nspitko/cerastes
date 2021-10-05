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

	public function toObject(?parent = null)
	{
		var data = getData();
		Utils.assert( data.version <= version, "Warning: CUI generated with newer version than this parser supports" );
		Utils.assert( data.version >= minVersion, "Warning: CUI version newer than parser understands; parsing will probably fail!" );

		var root = new Object(parent);

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

				switch( props.get("font") )
				{
					case "fnt/ui_numerics.fnt":
						obj = new h2d.Text( hxd.Res.fnt.dialogue.toSdfFont(14,4,0.475,1/10) );
					case "fnt/speaker.fnt":
						obj = new h2d.Text( hxd.Res.fnt.dialogue.toSdfFont(50,4,0.475,1/10) );
					default:
						obj = new h2d.Text( res.toSdfFont(24,4,0.475,1/10) );
				}

				//obj = new h2d.Text( res.toSdfFont(24,4,0.475,1/10) );

			case "h2d.Bitmap":
				var tile = hxd.Res.loader.load( props.get("tile") ).toTile();
				obj = new Bitmap( tile );

			case "h2d.Mask":
				obj = new h2d.Mask(props.get("width"),props.get("height"));

			case "h2d.Interactive":
				obj = new h2d.Interactive(props.get("width"),props.get("height"));

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
				obj.rotation = props["rotation"];
				if( props.exists("scale_x") )
					obj.scaleX = props["scale_x"];
				if( props.exists("scale_y") )
					obj.scaleY = props["scale_y"];


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

				if( props.exists("overflow") )
					o.overflow = EnumTools.createByIndex( h2d.Flow.FlowOverflow, props["overflow"] );

				o.minWidth = props["min_width"];
				o.minHeight = props["min_height"];

				o.verticalSpacing = props["vertical_spacing"];
				o.horizontalSpacing = props["horizontal_spacing"];

			case "h2d.Mask":
				var o = cast(obj, h2d.Mask);
				o.scrollX = props["scroll_x"];
				o.scrollY = props["scroll_y"];

			case "h2d.Interactive":
				var o = cast(obj, h2d.Interactive);

				if( props.exists("is_ellipse") )
					o.isEllipse = props["is_ellipse"];
				if( props.exists("background_color") )
					o.backgroundColor = props["background_color"];
				if( props.exists("cursor") )
					o.cursor = EnumTools.createByIndex( hxd.Cursor, props["cursor"] );



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

	public static function writeObject( def: CUIElementDef, obj: Object, file: String )
	{

		updateDefs([def], obj );

		var cui: CUIFile = {
			version: version,
			root: def
		};

		var s = new hxbit.Serializer();
		var bytes = s.serialize(cui);

		#if hl
		sys.io.File.saveBytes('res/${file}',bytes);
		#end
	}

	static function updateDefs( defs: Array<CUIElementDef>, root: Object )
	{
		for( def in defs )
		{
			var obj: Object = root.getObjectByName(def.name);
			var type = Type.getClass( obj );
			do
			{
				getProps(obj, def.props, Type.getClassName(type) );
				type = cast Type.getSuperClass( type );
			}
			while( type != null );

			updateDefs(def.children, root);
		}

	}

	static function getProps( obj: Object, props: Map<String,Dynamic>, type: String )
	{
		switch( type )
		{
			case "h2d.Object":
				props["x"] = obj.x;
				props["y"] = obj.y;
				props["rotation"] = obj.rotation;
				props["scale_x"] = obj.scaleX;
				props["scale_y"] = obj.scaleY;

			case "h2d.Text":
				var o = cast(obj, h2d.Text);
				props["text"] = o.text;
				props["text_align"] = EnumValueTools.getIndex(o.textAlign);
				props["max_width"] = o.maxWidth;
				//props["font"] = o.font.name

			case "h2d.Bitmap":
				var o = cast(obj, h2d.Bitmap);
				props["tile"] = o.tile.getTexture().name;

				if( o.width > 0 ) props["width"] = o.width;
				if( o.height > 0 ) props["height"] = o.height;

			case "h2d.Drawable":
				var o = cast(obj, h2d.Drawable);
				props["color"] = o.color.toColor();

			case "h2d.Flow":
				var o = cast(obj, h2d.Flow);

				props["layout"] = EnumValueTools.getIndex(o.layout);
				props["vertical_align"] = EnumValueTools.getIndex(o.verticalAlign);
				props["horizontal_align"] = EnumValueTools.getIndex(o.horizontalAlign);
				props["overflow"] = EnumValueTools.getIndex(o.overflow);

				props["min_width"] = o.minHeight;
				props["min_height"] = o.minWidth;

				props["vertical_spacing"] = o.verticalSpacing;
				props["horizontal_spacing"] = o.horizontalSpacing;

			case "h2d.Mask":
				var o = cast(obj, h2d.Mask);

				props["width"] = o.width;
				props["height"] = o.height;

				props["scroll_x"] = o.scrollX;
				props["scroll_y"] = o.scrollY;

			case "h2d.Interactive":
				var o = cast(obj, h2d.Interactive);

				props["width"] = o.width;
				props["height"] = o.height;
				props["is_ellipse"] = o.isEllipse;
				props["background_color"] = o.backgroundColor;
				//props["cursor"] = EnumValueTools.getIndex(o.cursor);


			default:


		}

	}

	public function getData() : CUIFile
	{
		if (data != null) return data;

		var u = new hxbit.Serializer();
		data = u.unserialize(entry.getBytes(), CUIFile);

		return data;
	}
}