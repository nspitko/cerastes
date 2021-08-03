package cerastes.tools;

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
	var textureID: Int;
	var dirty: Bool;
	var alwaysUpdate: Bool;
	var loaded: Bool;
}

class AssetBrowser  extends  ImguiTool
{
	var previews = new Map<String, AssetBrowserPreviewItem>();

	var previewWidth = 64;
	var previewHeight = 64;

	var placeholder: Texture;
	var placeholderID: Int;

	var filterText: String = "";

	var scaleFactor = Utils.getDPIScaleFactor();

	var filterTypes = [
		"Images" => true,
		"Models" => true,
		"Particles" => true,
		"Fonts" => true,
		"Butai" => true,
		"UI Files" => true,
		"Others" => true,
	];

	public function new()
	{
		previewWidth = cast Math.floor( previewWidth * scaleFactor );
		previewHeight = cast Math.floor( previewHeight * scaleFactor );

		placeholder = hxd.Res.tools.uncertainty.toTexture();
		placeholderID = ImGuiDrawableBuffers.instance.registerTexture( placeholder );

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
			textureID: -1,
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

			p.textureID = ImGuiDrawableBuffers.instance.registerTexture( p.texture );

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
				var bmp = new Bitmap( hxd.Res.tools.font.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;

			case "bdef":
				var bmp = new Bitmap( hxd.Res.tools.config.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;

			case "bnode":
				var bmp = new Bitmap( hxd.Res.tools.checkbox_tree.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;

			case "cui":
				var bmp = new Bitmap( hxd.Res.tools.cui.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;


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
		// UI preview pane
		//ImGui.begin("Preview");
		//
		//ImGui.end();

		ImGui.begin("\uf07c Asset browser", null, ImGuiWindowFlags.AlwaysAutoResize);

		ImGui.beginChild("assetbrowser_assets",{x: 500 * scaleFactor, y: 350 * scaleFactor}, false, ImGuiWindowFlags.AlwaysAutoResize);

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

		//ImGui.combo( "" )

		populateAssets();


		ImGui.endChild();

		ImGui.end();

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

			var t = preview.textureID != -1 ? preview.textureID : placeholderID;

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
			case "png" | "bmp" | "gif" | "jpg":
				ImGui.textColored(typeColor,"Texture");
				ImGui.separator();
				ImGui.image(asset.textureID, {x: asset.texture.width, y: asset.texture.height});
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
			case "cui": "UI Files";
			case "png" | "bmp" | "gif" | "jpg": "Images";
			case "bdef": "Butai";
			default: "Other";

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