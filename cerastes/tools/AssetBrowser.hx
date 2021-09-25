package cerastes.tools;

import cerastes.macros.Metrics;
#if hlimgui

import cerastes.fmt.SpriteResource;
import hxd.res.Atlas;
import cerastes.tools.ImguiTool.ImguiToolManager;
import h2d.Text;
import h2d.Font;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTools.ImVec2Impl;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import h3d.mat.Texture;
import h2d.Bitmap;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import imgui.ImGui;
import h2d.Object;
import haxe.ds.Map;

typedef AssetBrowserPreviewItem = {
	var file: String;
	var texture: Texture;
	var scene: h2d.Scene;
	var dirty: Bool;
	var alwaysUpdate: Bool;
	var loaded: Bool;
}

class AssetBrowser  extends  ImguiTool
{
	var previews = new Map<String, AssetBrowserPreviewItem>();

	var previewWidth = 64;
	var previewHeight = 64;

	var viewportWidth: Int;
	var viewportHeight: Int;

	var placeholder: Texture;
	var placeholderID: Int;

	var filterText: String = "";

	var scaleFactor = Utils.getDPIScaleFactor();

	var filterTypes = [
		"Sprite" => true,
		"Image" => true,
		//"Model" => true,
		"Particles" => true,
		"Fonts" => true,
		"Butai" => true,
		"UI File" => true,
		"Texture Atlas" => true,
		"Others" => true,
	];

	public static var needsReload = false;

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");
		viewportWidth = 640;
		viewportHeight = 360;
		if( size != null )
		{
			var p = size.split("x");
			viewportWidth = Std.parseInt(p[0]);
			viewportHeight = Std.parseInt(p[1]);
		}

		previewWidth = cast Math.floor( previewWidth * scaleFactor );
		previewHeight = cast Math.floor( previewHeight * scaleFactor );

		placeholder = hxd.Res.tools.uncertainty.toTexture();

		loadAssets("res");
	}


	function createPreview( file: String )
	{
		if( previews.exists( file ) )
			return previews.get(file);

		previews.set(file,{
			file: file,
			texture: null,
			scene: null,
			dirty: false,
			loaded: false,
			alwaysUpdate: false,
		});

		return previews.get(file);
	}

	function setVisible( p: AssetBrowserPreviewItem )
	{

		if( !p.loaded )
		{


			p.dirty = true;
			p.loaded = true;
			p.scene = new h2d.Scene();
			loadAsset(p);


			if( p.texture == null )
			{
				// loadAsset may just fill us with a texture

				p.scene.scaleMode = Stretch(previewWidth, previewHeight);
				p.texture = new Texture(previewWidth,previewHeight, [Target] );
			}
			else
			{
				p.scene = null;
			}


		}
	}

	function loadAsset(asset: AssetBrowserPreviewItem)
	{
		var ext = Path.extension( asset.file );
		switch(ext)
		{
			case "png" | "bmp" | "gif" | "jpg":

				asset.texture = hxd.Res.load( asset.file ).toTexture();
				asset.dirty = false;

			case "fnt":
				var any = hxd.Res.load( asset.file );

				var font = hxd.fmt.bfnt.Reader.parse( any.entry.getBytes(), function(name){
					return hxd.Res.load( '${any.entry.directory}/${name}'  ).toTile();
				});


				var t = new Text(font, asset.scene );
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.text = "The quick brown fox jumps over the lazy dog";

			case "bdef":
				var bmp = new Bitmap( hxd.Res.tools.config.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;

			case "cui":
				var res = new cerastes.fmt.CUIResource( hxd.Res.loader.load(asset.file).entry );

				var obj = res.toObject();

				var scale = previewWidth / viewportWidth;
				obj.scale( scale );

				asset.scene.addChild( obj );

			case "csd":

				asset.alwaysUpdate = true;

				var res = hxd.Res.load( asset.file ).to( SpriteResource );
				var obj = res.toSprite( asset.scene );
				var bounds = obj.getBounds();


				var scale = previewWidth / bounds.width;
				obj.scale( scale );


			case "atlas":
				var atlas = hxd.Res.load( asset.file ).to( Atlas );

				var count = 0;

				for(name => tiles in atlas.getContents() )
				{
					var b = new Bitmap( tiles[0].t, asset.scene );

					b.x = 10 * scaleFactor * count;
					b.y = 10 * scaleFactor * count;

					var scale = ( previewWidth / tiles[0].t.width  ) * 0.7;
					b.scale(scale);

					count++;

					if( count > 3 )
						break;
				}




			default:
				var bmp = new Bitmap( hxd.Res.tools.hexagonal_nut.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;


		}
	}

	function disposePreview( file )
	{
		if( !previews.exists( file ) )
			return;

		var p = previews[file];

		//p.texture.dispose();

		previews.remove(file);
	}

	override public function update( delta: Float )
	{
		Metrics.begin();
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		if( needsReload )
		{
			needsReload = false;
			loadAssets("res");
		}

		ImGui.setNextWindowSize({x: 700 * scaleFactor, y: 400 * scaleFactor}, ImGuiCond.Once);
		ImGui.begin("\uf07c Asset browser", isOpenRef);

		var text = IG.textInput("",filterText,"Filter");
		if( text != null )
			filterText = text;

		ImGui.sameLine();

		if (ImGui.button("Filter Types..."))
            ImGui.openPopup("ab_filtertypes");

		if (ImGui.beginPopup("ab_filtertypes"))
        {
			if( ImGui.menuItem("All") )
			{
				for( key in filterTypes.keys() )
					filterTypes[key] = true;
			}
			if( ImGui.menuItem("None") )
			{
				for( key in filterTypes.keys() )
					filterTypes[key] = false;
			}
			ImGui.separator();
			for( label => value in filterTypes )
			{
				if( ImGui.menuItem(label,"", value) )
					filterTypes[label] = !value;
			}

			ImGui.endPopup();
		}

		ImGui.beginChild("assetbrowser_assets",null, false, ImGuiWindowFlags.AlwaysAutoResize);

		//ImGui.combo( "" )

		populateAssets();


		ImGui.endChild();

		ImGui.end();

		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}

		Metrics.end();

		// Editor window
	}

	inline function pathFix(path: String)
	{
		return path.substr(4);
	}

	function loadAssets( path: String )
	{
		for(f in FileSystem.readDirectory(path))
		{
			var fp = Path.join([path,f]);

			if( FileSystem.isDirectory(fp) )
			{
				var ffp = pathFix(fp);
				if( ffp == "tools" || ffp == ".tmp" )
					continue;

				loadAssets( fp );
				continue;
			}
			createPreview( pathFix(fp) );

		}
	}

	function openAssetEditor( asset: AssetBrowserPreviewItem )
	{
		var ext = Path.extension( asset.file );
		switch( ext )
		{
			case "cml":
				var t: BulletEditor = cast ImguiToolManager.showTool("BulletEditor");
				t.openFile( asset.file );
			case "cui":
				var t: UIEditor = cast ImguiToolManager.showTool("UIEditor");
				t.openFile( asset.file );
			case "csd":
				var t: SpriteEditor = cast ImguiToolManager.showTool("SpriteEditor");
				t.openFile( asset.file );
			case "atlas":
				var t: AtlasBrowser = cast ImguiToolManager.showTool("AtlasBrowser");
				t.openFile( asset.file );
		}
	}

	function populateAssets()
	{

		var windowPos : ImVec2 =  ImGui.getWindowPos();
		var windowContentRegionMax : ImVec2 = ImGui.getWindowContentRegionMax();
		var windowRight = windowPos.x + windowContentRegionMax.x;
		var style : ImGuiStyle = ImGui.getStyle();
		for(fp => preview in previews )
		{
			if( filterText.length > 0 && !StringTools.contains(fp, filterText) )
				continue;

			if( !filterTypes[getItemType( preview )] )
				continue;

			var t = preview.texture != null ? preview.texture : placeholder;

			if( ImGui.imageButton( t, {x: previewWidth, y: previewHeight}, null, 2 ) )
			{
				trace('Asset select: ${preview.file}');
			}
			if( ImGui.isItemVisible() )
			{
				setVisible(preview);
			}

			if( ImGui.isItemHovered() )
			{
				onItemHover(preview);
				if( ImGui.isMouseDoubleClicked( ImGuiMouseButton.Left ) )
				{
					trace('Asset open: ${preview.file}');
					openAssetEditor( preview );
				}
			}



			if( ImGui.beginDragDropSource() )
			{
				ImGui.setDragDropPayloadString("asset_name",preview.file);

				ImGui.beginTooltip();
				ImGui.image(t, {x: 128 * scaleFactor, y: 128*scaleFactor});
				ImGui.endTooltip();

				ImGui.endDragDropSource();
			}

			var itemRectMax: ImVec2 = ImGui.getItemRectMax();
			var nextButtonX2 = itemRectMax.x + style.ItemSpacing.x + previewWidth;
			if( nextButtonX2 < windowRight )
				ImGui.sameLine();




		}
	}

	function onItemHover( asset: AssetBrowserPreviewItem )
	{
		ImGui.beginTooltip();
		ImGui.text(asset.file);

		var ext = Path.extension( asset.file );
		var typeColor: ImVec4 = {x:0.5,y:1.0,z:1.0,w:1.0};
		switch(ext)
		{
			case "bdef":
				ImGui.textColored(typeColor,"Butai node definition file");
			case "fnt":
				ImGui.textColored(typeColor,"Font atlas");
			case "cui":
				ImGui.textColored(typeColor,"UI File");
			case "cml":
				ImGui.textColored(typeColor,"Cannon package");
			case "atlas":
				ImGui.textColored(typeColor,"Texture atlas");
			case "csd":
				ImGui.textColored(typeColor,"Sprite");
			case "png" | "bmp" | "gif" | "jpg":
				ImGui.textColored(typeColor,"Texture");
				ImGui.separator();
				ImGui.image(asset.texture, {x: Math.min( asset.texture.width, 512 * scaleFactor), y: Math.min(asset.texture.height, 512 * scaleFactor) });
			default:

		}

		ImGui.endTooltip();
	}

	function getItemType( asset: AssetBrowserPreviewItem )
	{

		var ext = Path.extension( asset.file );
		return switch(ext)
		{
			case "fnt": "Fonts";
			case "cui": "UI File";
			case "png" | "bmp" | "gif" | "jpg": "Images";
			case "bdef": "Butai";
			case "csd": "Sprite";
			case "atlas": "Texture Atlas";
			default: "Others";

		}

	}


	override public function render( e: h3d.Engine)
	{

		for( file => target in previews )
		{
			if( !target.dirty && !target.alwaysUpdate )
				continue;

			target.texture.clear( 0 );

			e.pushTarget( target.texture );
			e.clear(0,1);
			target.scene.render(e);
			e.popTarget();

			target.dirty = false;
		}

	}

}
#end