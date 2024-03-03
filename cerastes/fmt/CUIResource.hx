package cerastes.fmt;

import h3d.Engine;
import cerastes.fmt.AtlasResource.AtlasFrame;
import cerastes.fmt.AtlasResource.AtlasEntry;
import cerastes.ui.Button.ButtonHoverTween;
import haxe.rtti.Meta;
import cerastes.ui.Timeline;
import cerastes.ui.Timeline.TimelineOperation;
import cerastes.ui.Button.ButtonType;
import cerastes.ui.Button.BitmapMode;
import cerastes.ui.AdvancedText;
import cerastes.ui.UIEntity;
import haxe.display.Display.CompletionItemResolveParams;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import h2d.ScaleGrid;
import h2d.Tile;
import haxe.EnumTools;
import cerastes.c3d.Vec4;
import haxe.io.BytesBuffer;
import haxe.io.Bytes;
import h2d.Bitmap;
import hxd.res.BitmapFont;
import h2d.Font;
import hxd.res.Loader;
import h2d.Object;
import haxe.Json;
import hxd.res.Resource;

@:keepSub
@:structInit class CUIFilterDef {
	public var type: String = null;
}

enum abstract CUIScriptId(Int) {
	var Invalid;
	// Object
	var OnAdd;
	var OnRemove;

	// Alarms
	var Timer1;
	var Timer2;
	var Timer3;
	var Timer4;

	// Button
	var OnPress;
	var OnRelease;
	var OnStartHover;
	var OnEndHover;


	// If you need to extend, create a new compatible enum that starts here:
	var Last = 1000;
}

enum abstract CUITristateBool(Int) from Int to Int {
	var True = 1;
	var False = 0;
	var Null = -1;
}

// Cerastes UI
@:keepSub
@:structInit class CUIObject implements CDObject {

	public var type: String = null;
	public var name: String = null;
	// Hack
	@default([]) public var children: Array<CUIObject> = null;

	public var x: Float = 0;
	public var y: Float = 0;
	public var rotation: Float = 0;
	public var scaleX: Float = 1;
	public var scaleY: Float = 1;
	public var alpha: Float = 1;
	public var blendMode: h2d.BlendMode = h2d.BlendMode.Alpha;

	public var visible: Bool = true;

	public var filter: CUIFilterDef = null;

	public var onAdd: UIScript = null;
	public var onRemove: UIScript = null;

	public var onTimer1: UIScript = null;
	public var onTimer2: UIScript = null;
	public var onTimer3: UIScript = null;
	public var onTimer4: UIScript = null;

	#if hlimgui
	@noSerialize public var handle: h2d.Object = null;
	@noSerialize public var parent: CUIObject = null;

	public function clone( fnRename: (String) -> String )
	{
		var cls = Type.getClass(this);
		var inst = Type.createEmptyInstance(cls);
		var fields = Type.getInstanceFields(cls);
		for (field in fields)
		{
			if( field == "children" || field.length == 0) // Fixes a bug in HL when inheriting interfaces
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

	public static function getMetaForField( f: String, m: String, cls: Class<Dynamic> ) : Any
	{
		var meta: haxe.DynamicAccess<Dynamic> = null;
		if( cls != null )
			meta = Meta.getFields( cls );

		if( meta != null && meta.exists( f ) )
		{
			var metadata: haxe.DynamicAccess<Dynamic> = meta.get(f);

			if( metadata.exists(m) )
			{
				var val = metadata.get(m);
				if( val == null )
					return true;
				else
					return val[0];
			}

		}

		if( cls == null )
			return null;

		cls = Type.getSuperClass( cls );
		if( cls != null )
			return getMetaForField(f, m, cls );

		return null;

	}

	public function initChildren()
	{
		for( c in children )
		{
			c.parent = this;
			c.initChildren();
		}
	}

	public static final pathChar = '/';

	public function getObjectByPath( path: String )
	{
		if( name == path )
			return this;

		var pb = path.split(pathChar);
		var t = this;
		var id = pb.shift();

		for( c in children )
		{
			if( c.name == id )
				return c.getObjectByPath( pb.join("/") );
		}

		return null;
	}

	public function getObjectByName( id: String )
	{
		if( name == id )
			return this;

		for( c in children )
		{
			var ret = c.getObjectByName( id );
			if( ret != null  )
				return ret;
		}

		return null;
	}


	public function getPath()
	{
		var p = name;
		// Hack: Never store the root object's name in our path.
		while( parent != null && parent.parent != null )
		{
			p = '${parent.name}${pathChar}${p}';
			parent = parent.parent;
		}

		return p;
	}
	#end

}

@:structInit class CUISound extends CUIObject {
	public var cue: String = null;
	public var volume: Float = 1;
	public var loop: Bool = false;
}

@:structInit class CUIEntity extends CUIObject {
	public var cls: String = null;
}

@:structInit class CUIDrawable extends CUIObject {
	public var color: Int = 0xFFFFFFFF;
	public var smooth: CUITristateBool = CUITristateBool.Null;
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

	public var textAlign: h2d.Text.Align = h2d.Text.Align.Left;

	public var maxWidth: Float = -1;
}

@:structInit class CUIAdvancedText extends CUIText {
	public var ellipsis: Bool = false;
	public var maxLines: Int = 0;
	public var boldFont: String = null;
}


@:structInit class CUIBitmap extends CUIDrawable {
	public var tile: String = "#FF00FF";
	public var width: Float = -1;
	public var height: Float = -1;
}

@:structInit class CUIAdvancedBitmap extends CUIBitmap {
	public var scrollX: Int = 0;
	public var scrollY: Int = 0;
	public var clipX: Int = 0;
	public var clipY: Int = 0;
}

@:structInit class CUIAnim extends CUIDrawable {
	public var entry: String = "#FF00FF";
	public var speed: Float = 15;
	public var loop: Bool = true;
	public var autoplay: Bool = true;
	public var bidirectional: Bool = false;
}

@:structInit class CUICAnim extends CUIDrawable {
	public var entry: String = "#FF00FF";
	public var loop: Bool = true;
	public var autoplay: Bool = true;
}

@:structInit class CUIButton extends CUIFlow {
	public var defaultTile: String = "";
	public var hoverTile: String = "";
	public var onTile: String = "";
	public var disabledTile: String = "";
	public var pressTile: String = "";

	public var defaultColor: Int = 0xFFFFFFFF;
	public var hoverColor: Int = 0xFFFFFFFF;
	public var onColor: Int = 0xFFFFFFFF;
	public var onHoverColor: Int = 0xFFFFFFFF;
	public var disabledColor: Int = 0xFFFFFFFF;
	public var pressColor: Int = 0xFFFFFFFF;

	public var defaultTextColor: Int = 0x00000000;
	public var hoverTextColor: Int = 0x00000000;
	public var onTextColor: Int = 0x00000000;
	public var disabledTextColor: Int = 0x00000000;
	public var pressTextColor: Int = 0x00000000;

	public var text: String = null;
	public var font: String = null;

	// sdf
	public var sdfSize: Int = 12;
	public var sdfAlpha: Float = 0.5;
	public var sdfSmoothing: Float = 10;

	public var ellipsis: Bool = false;

	public var bitmapMode: BitmapMode = cerastes.ui.Button.BitmapMode.ButtonTile;
	public var buttonMode: ButtonType = cerastes.ui.Button.ButtonType.Momentary;

	public var hoverSound: String = null;
	public var activateSound: String = null;
	public var deactivateSound: String = null;
	public var disabledSound: String = null;

	public var tweenModeHover: ButtonHoverTween = cerastes.ui.Button.ButtonHoverTween.None;
	public var tweenModeUnHover: ButtonHoverTween = cerastes.ui.Button.ButtonHoverTween.None;
	public var tweenDuration: Float = 0;

	public var orientation: cerastes.ui.Button.Orientation = cerastes.ui.Button.Orientation.None;
	@default(true) public var colorChildren: Bool = true;

	public var onPress: UIScript = null;
	public var onRelease: UIScript = null;
}



@:structInit class CUISGButton extends CUIFlow {
	public var hoverTile: String = "";
	public var pressTile: String = "";
	public var defaultTile: String = "";
	public var disabledTile: String = "";

	public var defaultColor: Vec4 = new Vec4(1,1,1,1);
	public var hoverColor: Vec4 = new Vec4(1,1,1,1);
	public var pressColor: Vec4 = new Vec4(1,1,1,1);

	public var visitedColor: Vec4 = new Vec4(1,1,1,1);
	public var disabledColor: Vec4 = new Vec4(1,1,1,1);


	public var orientation: cerastes.ui.Button.Orientation = cerastes.ui.Button.Orientation.None;
}

@:structInit class CUIBButton extends CUIInteractive {
	public var hoverTile: String = "";
	public var pressTile: String = "";
	public var defaultTile: String = "";
	public var disabledTile: String = "";

	public var defaultColor: Vec4 = new Vec4(1,1,1,1);
	public var hoverColor: Vec4 = new Vec4(1,1,1,1);
	public var pressColor: Vec4 = new Vec4(1,1,1,1);
	public var disabledColor: Vec4 = new Vec4(1,1,1,1);

	public var orientation: cerastes.ui.Button.Orientation = cerastes.ui.Button.Orientation.None;
}

@:structInit class CUITButton extends CUIFlow {

	public var defaultColor: Int = 0xFFFFFFFF;
	public var hoverColor: Int = 0xFFFFFFFF;
	public var onColor: Int = 0xFFFFFFFF;
	public var disabledColor: Int = 0xFFFFFFFF;

	public var text: String = "";
}

@:structInit class CUIFlow extends CUIDrawable {
	public var layout: h2d.Flow.FlowLayout = h2d.Flow.FlowLayout.Horizontal;
	public var verticalAlign: h2d.Flow.FlowAlign = h2d.Flow.FlowAlign.Top;
	public var horizontalAlign: h2d.Flow.FlowAlign = h2d.Flow.FlowAlign.Left;
	public var overflow: h2d.Flow.FlowOverflow = h2d.Flow.FlowOverflow.Limit;

	public var minWidth: Int = -1;
	public var minHeight: Int = -1;
	public var maxWidth: Int = -1;
	public var maxHeight: Int = -1;

	public var paddingTop: Int = 0;
	public var paddingRight: Int = 0;
	public var paddingBottom: Int = 0;
	public var paddingLeft: Int = 0;

	public var lineHeight: Int = -1;
	public var colWidth: Int = -1;

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

@:structInit class UIScript
{
	public var script: String = "";
}


@:structInit class CUIFile {
	public var version: Int;
	public var root: CUIObject;
	@serializeType("cerastes.timeline.Timeline")
	public var timelines: Array<Timeline> = [];
}

class CUIResource extends Resource
{
	var data: CUIFile;

	static var minVersion = 1;
	static var version = 3;

	public static var initializeEntities: Bool = true;

	var entsToInitialize: Array<UIEntity> = [];

	public function toTimeline(ui: h2d.Object, name: String )
	{
		var data = getData();

		for( t in data.timelines )
			if( t.name == name )
			{
				var r = new TimelineRunner(t, ui);
				return r;
			}

		return null;
	}

	public function toObject(?parent: h2d.Object = null, isPreview: Bool = false)
	{

		var data = getData();
		Utils.assert( data.version <= version, "CUI generated with newer version than this parser supports" );
		Utils.assert( data.version >= minVersion, "CUI version newer than parser understands; parsing will probably fail!" );
		if( data.version < version )
			Utils.warning( '${entry.name} was generated using a different code version. Open and save to upgrade.' );

		#if debug
		recursiveUpgradeObjects( data.root, data.version );
		#end


		return defToObject( data.root, parent, isPreview );
	}

	public function defToObject(def: CUIObject, ?parent: h2d.Object, isPreview: Bool = false )
	{
		entsToInitialize = [];

		var root = new Object();

		recursiveCreateObjects(def, root, root, isPreview);

		root = root.getChildAt(0);

		// CUI root specific shit
		if( data != null)
			root.timelineDefs = data.timelines;

		if( parent != null )
			parent.addChild(root);

		if( initializeEntities )
		{
			for( e in entsToInitialize )
				e.initialize(root);
		}

		return root;

	}

	public static function recursiveUpgradeObjects( object: CUIObject, version: Int)
	{
		upgradeObject(object, version);

		if( object.children != null)
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

	public function recursiveCreateObjects( entry: CUIObject, parent: Object, root: Object, isPreview: Bool = false )
	{
		var e = createObject(entry);
		parent.addChild(e);

		if( entry.children != null )
			for( c in entry.children )
				recursiveCreateObjects( c, e, root, isPreview );

		// Fuck this but I don't wanna rewrite everything.
		var ent: UIEntity = Std.downcast( e, UIEntity );
		if( ent != null )
		{
			@:privateAccess ent.isPreview = isPreview;
			entsToInitialize.push(ent);
		}
	}

	public static function updateObject( entry: CUIObject, target: Object, ?initialize = true )
	{
		recursiveSetProperties(target, entry);

		var ent: UIEntity = Std.downcast( target, UIEntity );
		if( initialize && ent != null )
			ent.initialize( ent.getTopmostParent() );

	}

	public static function recursiveUpdateObjects( entry: CUIObject, target: Object, ?initialize = true )
	{
		recursiveSetProperties(target, entry);

		var ent: UIEntity = Std.downcast( target, UIEntity );
		if( initialize && ent != null )
			ent.initialize( ent.getTopmostParent() );

		#if hlimgui
		for( c in entry.children )
			recursiveUpdateObjects( c, c.handle, initialize );
		#end

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

			case "cerastes.ui.AdvancedBitmap":
				obj = new cerastes.ui.AdvancedBitmap();

			case "h2d.Anim":
				obj = new h2d.Anim();

			case "cerastes.ui.Anim":
				obj = new cerastes.ui.Anim();

			case "h2d.Mask":
				var d : CUIMask = cast entry;
				obj = new h2d.Mask(d.width,d.height);

			case "h2d.Interactive":
				var d: CUIInteractive = cast entry;
				obj = new cerastes.ui.InteractiveContainer(d.width, d.height);

			case "h2d.ScaleGrid":
				var d : CUIScaleGrid = cast entry;
				obj = new h2d.ScaleGrid(getTile(d.contentTile),d.borderLeft, d.borderTop);

			case "cerastes.ui.Button":
				obj = new cerastes.ui.Button();

			case "cerastes.ui.BitmapButton":
				var d: CUIBButton = cast entry;
				obj = new cerastes.ui.BitmapButton(d.width, d.height);

			case "cerastes.ui.AdvancedText":
				var d : CUIAdvancedText = cast entry;
				obj = new cerastes.ui.AdvancedText( getFont( d.font, d )  );

			case "cerastes.ui.Reference":
				var d : CUIReference = cast entry;
				obj = new cerastes.ui.Reference( d.file );

			case "cerastes.ui.Sound":
				//var d: CUISound = cast entry;
				obj = new cerastes.ui.Sound( );


			default:

				var opts = CompileTime.getAllClasses(UIEntity);
				if( opts != null )
				{

					for( c in opts )
					{
						if( Type.getClassName(c) == entry.type )
						{
							var t = Type.resolveClass( entry.type );
							obj = Type.createInstance(t, [entry]);
							break;
						}
					}
				}

				if( obj == null )
				{
					Utils.error('CUI: Cannot create unknown type ${entry.type}; ignoring!!');
					obj = new h2d.Object();
				}




		}

		obj.name = entry.name;
		#if hlimgui
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
				if( entry.blendMode != null )
					obj.blendMode = entry.blendMode;

				obj.scaleX = entry.scaleX;
				obj.scaleY = entry.scaleY;

				obj.visible = entry.visible;

				obj.alpha = entry.alpha;

				if( entry.onAdd != null )
					obj.registerScript(OnAdd, entry.onAdd);
				if( entry.onRemove != null )
					obj.registerScript(OnRemove, entry.onRemove);


				if( entry.filter != null )
				{
					var t = Type.resolveClass( entry.filter.type );
					var f = Type.createInstance(t, [entry.filter]);
					obj.filter = f;
				}

			case "h2d.Drawable":
				var e: CUIDrawable = cast entry;
				var o: h2d.Drawable = cast obj;


				var text = Std.downcast( obj, AdvancedText );
				if( text != null )
				{
					text.desiredColor.setColor( e.color );
				}
				else
				{
					o.color.setColor( e.color );
				}

				if( e.smooth != Null || o.smooth != null )
				{
					o.smooth = e.smooth == CUITristateBool.True;
				}



			case "h2d.Text":
				var o = cast(obj, h2d.Text);
				var e: CUIText = cast entry;

				o.textAlign = e.textAlign;
				o.maxWidth = e.maxWidth;

				o.font = getFont( e.font, e );

				if( e.text.charAt(0) == "#" )
					o.text = LocalizationManager.localize( e.text.substr(1) );
				else
					o.text = e.text;




			case "cerastes.ui.AdvancedText":
				var o = cast( obj, cerastes.ui.AdvancedText );
				var e: CUIAdvancedText = cast entry;

				o.ellipsis = e.ellipsis;
				if( e.boldFont != null )
					o.boldFont = getFont( e.boldFont, e );

				o.maxLines = e.maxLines;

				if( e.text.charAt(0) == "#" )
					o.locToken = e.text.substr(1);


			case "h2d.Bitmap":
				var o = cast(obj, h2d.Bitmap);
				var e: CUIBitmap = cast entry;


				o.tile = getTile( e.tile );

				o.width = e.width > 0 ? e.width : null;
				o.height = e.height > 0 ? e.height : null;


			case "cerastes.ui.AdvancedBitmap":
				var o = cast(obj, cerastes.ui.AdvancedBitmap);
				var e: CUIAdvancedBitmap = cast entry;

				o.scrollX = e.scrollX;
				o.scrollY = e.scrollY;

				o.clipX = e.clipX;
				o.clipY = e.clipY;

			case "h2d.Anim":
				var o = cast(obj, h2d.Anim);
				var e: CUIAnim = cast entry;

				var frames = getTiles( e.entry );
				if( e.bidirectional )
				{
					var bidiFrames = frames.copy();
					var i = frames.length - 1;
					while ( i >= 0 )
					{
						frames.push( bidiFrames[i] );
						i--;
					}
				}

				@:privateAccess o.frames = frames;

				o.speed = e.speed;
				o.loop = e.loop;
				o.pause = !e.autoplay;

			case "cerastes.ui.Anim":
				var o = cast(obj, cerastes.ui.Anim);
				var e: CUICAnim = cast entry;

				var entry: AtlasEntry = Utils.getAtlasEntry( e.entry );
				if( entry == null )
				{
					entry = {};
					entry.atlas = {};
					var frame: AtlasFrame = {};
					frame.atlas = entry.atlas;
					@:privateAccess entry.atlas.tile = Utils.invalidTile();
					entry.frames.push(frame);
				}

				o.entry = entry;
				o.loop = e.loop;
				o.pause = !e.autoplay;

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

				if( e.maxWidth > 0 ) o.maxWidth = e.maxWidth;
				if( e.maxHeight > 0 ) o.maxHeight = e.maxHeight;

				o.verticalSpacing = e.verticalSpacing;
				o.horizontalSpacing = e.horizontalSpacing;

				o.borderWidth = e.borderWidth;
				o.borderHeight = e.borderHeight;

				o.paddingLeft = e.paddingLeft;
				o.paddingRight = e.paddingRight;
				o.paddingTop = e.paddingTop;
				o.paddingBottom = e.paddingBottom;

				if( e.lineHeight >= 0 ) o.lineHeight = e.lineHeight;
				if( e.colWidth >= 0 ) o.colWidth = e.colWidth;

				o.multiline = e.multiline;

				if( e.backgroundTile.length > 0 )
					o.backgroundTile = getTile(e.backgroundTile);

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

				o.width = e.width;
				o.height = e.height;

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

			case "cerastes.ui.Button":
				var o = cast(obj, cerastes.ui.Button);
				var e: CUIButton = cast entry;

				o.sdfSize = e.sdfSize;
				o.sdfSmoothing = e.sdfSmoothing;
				o.sdfAlpha = e.sdfAlpha;

				o.bitmapMode = e.bitmapMode;
				o.buttonType = e.buttonMode;

				o.defaultColor = e.defaultColor;
				o.defaultTextColor = e.defaultTextColor;
				o.defaultTile = e.defaultTile;

				o.hoverColor = e.hoverColor;
				o.hoverTile = e.hoverTile;
				o.hoverTextColor = e.hoverTextColor;

				o.onColor = e.onColor;
				o.onHoverColor = e.onHoverColor;
				o.onTextColor = e.onTextColor;
				o.onTile = e.onTile;

				o.disabledColor = e.disabledColor;
				o.disabledTextColor = e.disabledTextColor;
				o.disabledTile = e.disabledTile;

				o.pressColor = e.pressColor;
				o.pressTextColor = e.pressTextColor;
				o.pressTile = e.pressTile;


				o.hoverSound = e.hoverSound;
				o.activateSound = e.activateSound;
				o.deactivateSound = e.deactivateSound;
				o.disabledSound = e.disabledSound;

				o.colorChildren = e.colorChildren;

				if( e.ellipsis )
					o.ellipsis = true;

				if( e.text != null && e.text.length > 0 )
				{
					if( e.text.charAt(0) == "#" )
						o.text = LocalizationManager.localize( e.text.substr(1) );
					else
						o.text = e.text;
				}

				if( e.font != null && e.font.length > 0 )
					o.font = e.font;

				o.tweenDuration = e.tweenDuration;
				o.tweenHoverEndMode = e.tweenModeUnHover;
				o.tweenHoverStartMode = e.tweenModeHover;

				if( e.orientation != null ) o.orientation = e.orientation;

				o.state = Default;


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

			case "cerastes.ui.Sound":
				var o = cast(obj, cerastes.ui.Sound);
				var e: CUISound = cast entry;

				o.cue = e.cue;
				o.volume = e.volume;
				o.loop = e.loop;


			default:


		}
	}

	public static function getFont( file: String, e: { sdfSize: Int, sdfAlpha: Float, sdfSmoothing: Float } )
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
			var atlasPos = file.indexOf(".atlas") + 6;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, hxd.res.Atlas );
			if( res != null )
				return res.get( tileName );
		}
		else
		{
			try
			{
				var res = hxd.Res.loader.loadCache( file, hxd.res.Image );
				if( res == null || res.entry.isDirectory )
					return null;

				return res.toTile();
			}
			catch(e)
			{
				return null;
			}
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



	public static function writeObject( def: CUIObject, timelines: Array<cerastes.ui.Timeline>, obj: Object, file: String )
	{

		#if hl
		var cui: CUIFile = {
			version: version,
			root: def,
			timelines: timelines,
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