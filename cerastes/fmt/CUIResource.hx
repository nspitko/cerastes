package cerastes.fmt;

import cerastes.ui.UIEntity;
import haxe.display.Display.CompletionItemResolveParams;
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


// Cerastes UI
@:keepSub
@:structInit class CUIObject {

	public var type: String = null;
	public var name: String = null;
	public var children: Array<CUIObject> = null;

	public var x: Float = 0;
	public var y: Float = 0;
	public var rotation: Float = 0;
	public var scaleX: Float = 1;
	public var scaleY: Float = 1;

	public var visible: Bool = true;

	#if hlimgui
	@noSerialize
	public var handle: h2d.Object = null;

	public function clone( fnRename: (String) -> String )
	{
		var cls = Type.getClass(this);
		var inst = Type.createEmptyInstance(cls);
		var fields = Type.getInstanceFields(cls);
		for (field in fields)
		{
			if( field == "children")
			{
				continue;
			}
			else
			{
				// generic copy
				var val:Dynamic = Reflect.field(this,field);
				if ( !Reflect.isFunction(val) )
				{
					Reflect.setField(inst,field,val);
				}
			}
		}

		inst.name = fnRename( inst.name );
		inst.children = [];
		inst.handle = null; // fixup
		// Now clone children
		for( c in children )
		{
			inst.children.push( c.clone( fnRename ) );
		}
		return inst;
	}
	#end

}

@:structInit class CUIEntity extends CUIObject {
	public var cls: String = null;
}

@:structInit class CUIDrawable extends CUIObject {
	public var color: Int = 0xFFFFFFFF;
}

@:structInit class CUIReference extends CUIObject {
	public var file: String = null;
}

@:structInit class CUIInteractive extends CUIDrawable {
	public var cursor: hxd.Cursor = hxd.Cursor.Default;
	public var isEllipse: Bool = false ;
	//public var backgroundColor: Int = 0xFFFFFFFF;

	public var width: Float = 0;
	public var height: Float = 0;
}

@:structInit class CUIText extends CUIDrawable {
	public var text: String = "";
	public var font: String = "fnt/kodenmanhou16.fnt";
	// sdf
	public var sdfSize: Int = 12;
	public var sdfAlpha: Float = 0.5;
	public var sdfSmoothing: Float = 10;

	public var textAlign: h2d.Text.Align = Left;

	public var maxWidth: Float = -1;
}

@:structInit class CUIAdvancedText extends CUIText {
	public var ellipsis: Bool = false;
}


@:structInit class CUIBitmap extends CUIDrawable {
	public var tile: String = "#FF00FF";
	public var width: Float = -1;
	public var height: Float = -1;
}

@:structInit class CUIAnim extends CUIDrawable {
	public var entry: String = "#FF00FF";
	public var speed: Float = 15;
	public var loop: Bool = true;
}


@:structInit class CUISGButton extends CUIFlow {
	public var hoverTile: String = "";
	public var pressTile: String = "";
	public var defaultTile: String = "";
	public var disabledTile: String = "";

	public var defaultColor: Vector = new Vector(1,1,1,1);
	public var hoverColor: Vector = new Vector(1,1,1,1);
	public var pressColor: Vector = new Vector(1,1,1,1);

	public var visitedColor: Vector = new Vector(1,1,1,1);
	public var disabledColor: Vector = new Vector(1,1,1,1);


	public var orientation: cerastes.ui.ScaleGridButton.Orientation = None;
}

@:structInit class CUIBButton extends CUIInteractive {
	public var hoverTile: String = "";
	public var pressTile: String = "";
	public var defaultTile: String = "";
	public var disabledTile: String = "";

	public var defaultColor: Vector = new Vector(1,1,1,1);
	public var hoverColor: Vector = new Vector(1,1,1,1);
	public var pressColor: Vector = new Vector(1,1,1,1);
	public var disabledColor: Vector = new Vector(1,1,1,1);

	public var orientation: cerastes.ui.ScaleGridButton.Orientation = None;
}

@:structInit class CUIFlow extends CUIDrawable {
	public var layout: h2d.Flow.FlowLayout = Horizontal;
	public var verticalAlign: h2d.Flow.FlowAlign = Top;
	public var horizontalAlign: h2d.Flow.FlowAlign = Left;
	public var overflow: h2d.Flow.FlowOverflow = Limit;

	public var minWidth: Int = -1;
	public var minHeight: Int = -1;
	public var maxWidth: Int = -1;
	public var maxHeight: Int = -1;

	public var paddingTop: Int = 0;
	public var paddingRight: Int = 0;
	public var paddingBottom: Int = 0;
	public var paddingLeft: Int = 0;

	public var horizontalSpacing: Int = 0;
	public var verticalSpacing: Int = 0;

	public var backgroundTile: String = "";

	public var borderWidth: Int = 0;
	public var borderHeight: Int = 0;

	public var multiline: Bool = true;
}



@:structInit class CUIMask extends CUIObject {

	public var width: Int = 10;
	public var height: Int = 10;

	public var scrollX: Float = 0;
	public var scrollY: Float = 0;
}

@:structInit class CUIScaleGrid extends CUIDrawable {

	public var borderLeft: Int = 1;
	public var borderRight: Int = 1;
	public var borderTop: Int = 1;
	public var borderBottom: Int = 1;
	public var borderWidth: Int = 1;
	public var borderHeight: Int = 1;

	public var width: Float = 10;
	public var height: Float = 10;

	public var tileBorders: Bool = true;
	public var ignoreScale: Bool = true;

	public var contentTile: String = "#FF00FF";
}


@:structInit class CUIFile {
	public var version: Int;
	public var root: CUIObject;
}

class CUIResource extends Resource
{
	var data: CUIFile;

	static var minVersion = 1;
	static var version = 2;

	var entsToInitialize: Array<UIEntity> = [];

	public function toObject(?parent: h2d.Object = null)
	{

		var data = getData();
		Utils.assert( data.version <= version, "CUI generated with newer version than this parser supports" );
		Utils.assert( data.version >= minVersion, "CUI version newer than parser understands; parsing will probably fail!" );
		if( data.version < version )
			Utils.warning( '${entry.name} was generated using a different code version. Open and save to upgrade.' );

		#if debug
		recursiveUpgradeObjects( data.root, data.version );
		#end


		return defToObject( data.root, parent );
	}

	public function defToObject(def: CUIObject, ?parent: h2d.Object )
	{
		entsToInitialize = [];

		var root = new Object();

		recursiveCreateObjects(def, root, root);

		root = root.getChildAt(0);

		if( parent != null )
			parent.addChild(root);

		for( e in entsToInitialize )
			e.initialize(root);

		return root;

	}

	public static function recursiveUpgradeObjects( object: CUIObject, version: Int)
	{
		upgradeObject(object, version);

		for( c in object.children )
			recursiveUpgradeObjects( c, version );
	}

	static function upgradeObject(object: CUIObject, version: Int )
	{
		var s: Class<Dynamic> = Type.getClass( object );
		while( s != null )
		{
			switch( Type.getClassName( s ) )
			{
				case "cerastes.fmt.CUIObject":
					var o: CUIObject = cast object;
					if( version < 2 )
					{
						o.visible = true;
					}
			}

			s = Type.getSuperClass( s );
		}
	}

	public function recursiveCreateObjects( entry: CUIObject, parent: Object, root: Object )
	{
		var e = createObject(entry);
		parent.addChild(e);

		if( entry.children != null )
			for( c in entry.children )
				recursiveCreateObjects( c, e, root );

		// Fuck this but I don't wanna rewrite everything.
		var ent: UIEntity = Std.downcast( e, UIEntity );
		if( ent != null )
			entsToInitialize.push(ent);
	}

	public static function updateObject( entry: CUIObject, target: Object )
	{
		recursiveSetProperties(target, entry);

		var ent: UIEntity = Std.downcast( target, UIEntity );
		if( ent != null )
			ent.initialize( ent.getScene() );

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
				var d : CUIText = cast entry;
				obj = new h2d.Text( getFont( d.font, d ) );

			case "h2d.Bitmap":
				obj = new Bitmap( );

			case "h2d.Anim":
				obj = new h2d.Anim();

			case "h2d.Mask":
				var d : CUIMask = cast entry;
				obj = new h2d.Mask(d.width,d.height);

			case "h2d.Interactive":
				var d: CUIInteractive = cast entry;
				obj = new h2d.Interactive(d.width, d.height);

			case "h2d.ScaleGrid":
				var d : CUIScaleGrid = cast entry;
				obj = new h2d.ScaleGrid(getTile(d.contentTile),d.borderLeft, d.borderTop);

			case "cerastes.ui.ScaleGridButton":
				//var props: CUISGButton = cast entry;
				obj = new cerastes.ui.ScaleGridButton();

			case "cerastes.ui.BitmapButton":
				var d: CUIBButton = cast entry;
				obj = new cerastes.ui.BitmapButton(d.width, d.height);

			case "cerastes.ui.AdvancedText":
				var d : CUIAdvancedText = cast entry;
				obj = new cerastes.ui.AdvancedText( getFont( d.font, d )  );

			case "cerastes.ui.Reference":
				var d : CUIReference = cast entry;
				obj = new cerastes.ui.Reference( d.file );

			default:

				var opts = CompileTime.getAllClasses(UIEntity);

				for( c in opts )
				{
					if( Type.getClassName(c) == entry.type )
					{
						var t = Type.resolveClass( entry.type );
						obj = Type.createInstance(t, [entry]);
						break;
					}
				}

				if( obj == null )
				{
					Utils.error('CUI: Cannot create unknown type ${entry.type}; ignoring!!');
					obj = new h2d.Object();
				}



		}

		obj.name = entry.name;
		#if tools
		entry.handle = obj;
		#end

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

				obj.visible = entry.visible;

			case "h2d.Drawable":
				var e: CUIDrawable = cast entry;
				var o: h2d.Drawable = cast obj;

				o.color.setColor( e.color );


			case "h2d.Text":
				var o = cast(obj, h2d.Text);
				var e: CUIText = cast entry;
				if( e.text.charAt(0) == "#" )
					o.text = LocalizationManager.localize( e.text.substr(1) );
				else
					o.text = e.text;

				o.font = getFont( e.font, e );

				o.textAlign = e.textAlign;
				o.maxWidth = e.maxWidth;

			case "cerastes.ui.AdvancedText":
				var o = cast( obj, cerastes.ui.AdvancedText );
				var e: CUIAdvancedText = cast entry;

				o.ellipsis = e.ellipsis;


			case "h2d.Bitmap":
				var o = cast(obj, h2d.Bitmap);
				var e: CUIBitmap = cast entry;


				o.tile = getTile( e.tile );

				o.width = e.width > 0 ? e.width : null;
				o.height = e.height > 0 ? e.height : null;

			case "h2d.Anim":
				var o = cast(obj, h2d.Anim);
				var e: CUIAnim = cast entry;

				@:privateAccess o.frames = getTiles( e.entry );
				o.speed = e.speed;
				o.loop = e.loop;

			case "h2d.Flow":
				var o = cast(obj, h2d.Flow);
				var e: CUIFlow = cast entry;

				o.layout = e.layout;

				o.verticalAlign = e.verticalAlign;
				o.horizontalAlign = e.horizontalAlign;

				o.overflow = e.overflow;

				// downstream items might set our mins for us
				o.minWidth = e.minWidth > 0 ? e.minWidth : o.minWidth;
				o.minHeight = e.minHeight > 0 ? e.minHeight : o.minHeight;

				o.maxWidth = e.maxWidth;
				o.maxHeight = e.maxHeight;

				o.verticalSpacing = e.verticalSpacing;
				o.horizontalSpacing = e.horizontalSpacing;

				o.borderWidth = e.borderWidth;
				o.borderHeight = e.borderHeight;

				o.paddingLeft = e.paddingLeft;
				o.paddingRight = e.paddingRight;
				o.paddingTop = e.paddingTop;
				o.paddingBottom = e.paddingBottom;

				o.multiline = e.multiline;

				o.backgroundTile = e.backgroundTile.length > 0 ? getTile(e.backgroundTile) : null;

			case "h2d.Mask":
				var o = cast(obj, h2d.Mask);
				var e: CUIMask = cast entry;
				o.width = e.width;
				o.height = e.height;

				o.scrollY = e.scrollY;
				o.scrollY = e.scrollY;

			case "h2d.Interactive":
				var o = cast(obj, h2d.Interactive);
				var e: CUIInteractive = cast entry;

				o.isEllipse = e.isEllipse;
				//o.backgroundColor = e.backgroundColor;
				o.cursor = e.cursor;

			case "h2d.ScaleGrid":
				var o = cast(obj, h2d.ScaleGrid);
				var e: CUIScaleGrid = cast entry;

				@:privateAccess o.contentTile = getTile( e.contentTile );

				o.borderTop = e.borderTop;
				o.borderBottom = e.borderBottom;
				o.borderLeft = e.borderLeft;
				o.borderRight = e.borderRight;

				o.borderWidth = e.borderWidth;
				o.borderHeight = e.borderHeight;

				o.tileBorders = e.tileBorders;
				o.ignoreScale = e.ignoreScale;

				o.width = e.width;
				o.height = e.height;

			case "cerastes.ui.ScaleGridButton":
				var o = cast(obj, cerastes.ui.ScaleGridButton);
				var e: CUISGButton = cast entry;

				o.hoverTile = getTile( e.hoverTile );
				o.pressTile = getTile( e.pressTile );
				o.disabledTile = getTile( e.disabledTile );
				o.defaultTile = getTile( e.defaultTile );

				if( e.defaultColor != null )
				{
					o.defaultColor = e.defaultColor;
					o.pressColor = e.pressColor;
					o.hoverColor = e.hoverColor;

					o.visitedColor = e.visitedColor;
					o.disabledColor = e.disabledColor;
				}

				if( e.orientation == null ) e.orientation = None;

				o.orientation = e.orientation;


				if( o.defaultTile != null )
				{
					o.minWidth = Math.ceil(o.defaultTile.width);
					o.minHeight = Math.ceil(o.defaultTile.height);
				}

				o.reflow();

			case "cerastes.ui.BitmapButton":
				var o = cast(obj, cerastes.ui.BitmapButton);
				var e: CUIBButton = cast entry;

				o.hoverTile = getTile( e.hoverTile );
				o.pressTile = getTile( e.pressTile );
				o.disabledTile = getTile( e.disabledTile );
				o.defaultTile = getTile( e.defaultTile );

				if( e.defaultColor != null )
				{
					o.defaultColor = e.defaultColor;
					o.pressColor = e.pressColor;
					o.hoverColor = e.hoverColor;

					o.disabledColor = e.disabledColor;
				}

				if( e.orientation == null ) e.orientation = None;

				o.orientation = e.orientation;

				if( e.width > 0 ) o.width = e.width;
				if( e.height > 0 ) o.height = e.height;



				o.reflow();

			case "cerastes.ui.Reference":
				var o = cast(obj, cerastes.ui.Reference);
				var e: CUIReference = cast entry;

				if( e.file != null && hxd.Res.loader.exists( e.file ) )
					o.load( e.file );


			default:


		}
	}

	static function getFont( file: String, e: { sdfSize: Int, sdfAlpha: Float, sdfSmoothing: Float } )
	{
		// Font shenanigans
		var isSDF = StringTools.endsWith( file, ".msdf.fnt" );

		if( !isSDF )
		{
			return hxd.Res.loader.loadCache( file, hxd.res.BitmapFont).toFont();
		}
		else
		{
			return hxd.Res.loader.loadCache( file, hxd.res.BitmapFont).toSdfFont(e.sdfSize,4,e.sdfAlpha,1/e.sdfSmoothing);
		}
	}

	public static function getTile( file: String )
	{
		if( file == null || file == "")
			return null;

		if(file.charAt(0) == "#" )
			return Tile.fromColor( Std.parseInt( '0x${file.substr(1)}' ) );
		else if ( file.indexOf(".catlas") != -1 )
		{
			var atlasPos = file.indexOf(".catlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, AtlasResource );
			if( res != null )
			{
				var entry = res.getData().entries[tileName];
				if( entry == null )
					return Utils.invalidTile();

				return entry.tile;
			}
		}
		else if ( file.indexOf(".atlas") != -1 )
		{
			var atlasPos = file.indexOf(".atlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, hxd.res.Atlas );
			if( res != null )
				return res.get( tileName );
		}
		else
		{
			var res = hxd.Res.loader.loadCache( file, hxd.res.Image );
			if( res == null || res.entry.isDirectory )
				return null;

			return res.toTile();
		}

		return null;

	}

	public static function getTiles( file: String ): Array<Tile>
	{
		if( file == null || file == "")
			return [ Utils.invalidTile() ];

		if(file.charAt(0) == "#" )
			return [ Tile.fromColor( Std.parseInt( '0x${file.substr(1)}' ) ) ];
		else if ( file.indexOf(".catlas") != -1 )
		{
			var atlasPos = file.indexOf(".catlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, AtlasResource );
			if( res != null )
			{
				var entry = res.getData().entries[tileName];
				if( entry == null )
					return [ Utils.invalidTile() ];

				return entry.tiles;
			}
		}
		else if ( file.indexOf(".atlas") != -1 )
		{
			var atlasPos = file.indexOf(".atlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, hxd.res.Atlas );
			if( res != null )
				return res.getAnim( tileName );
		}
		else
		{
			var res = hxd.Res.loader.loadCache( file, hxd.res.Image );
			if( res == null || res.entry.isDirectory )
				return null;

			return [ res.toTile() ];
		}

		return [ Utils.invalidTile() ];

	}



	public static function writeObject( def: CUIObject, obj: Object, file: String )
	{

		#if hl
		var cui: CUIFile = {
			version: version,
			root: def
		};

		//var s = new haxe.Serializer();
		//s.serialize(cui);

		//sys.io.File.saveContent( Utils.fixWritePath(file,"cui"),s.toString());
		sys.io.File.saveContent( Utils.fixWritePath(file,"ui"), CDPrinter.print( cui ) );



		//var json = Json.stringify(cui,null, "\t");

		//sys.io.File.saveContent( Utils.fixWritePath(file,"cuij"), json);
		#end
	}


	public function getData() : CUIFile
	{
		if (data != null) return data;



		//var u = new haxe.Unserializer(entry.getText());
		//data = u.unserialize();

		data = CDParser.parse( entry.getText(), CUIFile );

/*
		var parser = new json2object.JsonParser<CUIFile>(); // Creating a parser for Cls class
		parser.fromJson(entry.getText(), entry.name); // Parsing a string. A filename is specified for errors management
		data = parser.value; // Access the parsed class
		var errors:Array<json2object.Error> = parser.errors;
		for( e in errors )
		{
			Utils.warning(json2object.ErrorUtils.convertError(e) );
		}*/

		return data;
	}
}