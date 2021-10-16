package cerastes.tools;

import h3d.Vector;
import h2d.Graphics;
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
	var scene3d: h3d.scene.Scene;
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
		"Image" => false,
		"Model" => true,
		"Sound" => true,
		"Particles" => true,
		"Font" => true,
		"Butai" => false,
		"UI Layout" => true,
		"Texture Atlas" => true,
		"Others" => false,
	];

	public static var needsReload = false;

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");
		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;

		// ???? hacky shit. We really want to just dynamically size this for our sprite
		viewportWidth = cast viewportWidth;
		viewportHeight = cast  viewportHeight;
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
			scene3d: null,
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
			//p.scene = new h2d.Scene();
			loadAsset(p);


			if( p.texture == null && p.scene != null )
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
				asset.scene = new h2d.Scene();
				asset.texture = hxd.Res.load( asset.file ).toTexture();
				asset.dirty = false;

			case "fnt":
				asset.scene = new h2d.Scene();
				if( StringTools.endsWith( asset.file, ".msdf.fnt" ) )
				{
					var res = hxd.Res.loader.loadCache( asset.file, hxd.res.BitmapFont);
					var t = new h2d.Text( res.toSdfFont(16,4,0.4, 1/16), asset.scene );

					t.maxWidth = previewWidth - 8;
					t.x = previewWidth / 2;
					t.y = previewHeight / 2;
					t.textAlign = Center;
					t.text = t.font.name;

				}
				else
				{
					var res = hxd.Res.loader.loadCache( asset.file, hxd.res.BitmapFont);

					var t = new Text(res.toFont(), asset.scene );
					trace(t.font.name);
					t.maxWidth = previewWidth - 8;

					t.textAlign = MultilineCenter;
					t.text = t.font.name;
					t.y = ( previewHeight - t.textHeight ) / 2;
					t.x = ( previewWidth - t.textWidth ) / 2;
				}

			case "bdef":
				asset.scene = new h2d.Scene();
				var bmp = new Bitmap( hxd.Res.tools.config.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;

			case "cui":
				asset.scene = new h2d.Scene();
				var res = new cerastes.fmt.CUIResource( hxd.Res.loader.load(asset.file).entry );

				var obj = res.toObject();

				var scale = previewWidth / viewportWidth;
				obj.scale( scale );

				var offsetY = ( ( viewportWidth - viewportHeight ) / 2 ) * scale;
				obj.y = offsetY;

				asset.scene.addChild( obj );

				var t = new h2d.Text( hxd.Res.fnt.kodenmanhou16.toFont(), asset.scene);

				t.text = Path.withoutDirectory( Path.withoutExtension(asset.file) );
				t.textAlign = Center;
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.color = Vector.fromColor( getTypeColor(asset.file) );
				t.dropShadow = { dx:1, dy : 1, color : 0, alpha : 1 };

			case "csd":
				asset.scene = new h2d.Scene();
				asset.alwaysUpdate = true;

				var res = hxd.Res.load( asset.file ).to( SpriteResource );
				var obj = res.toSprite( asset.scene );
				obj.mute = true;

				var bounds = obj.getBounds();

				var scale = previewWidth / Math.max(bounds.width, bounds.height);
				obj.scale( scale );

				bounds = obj.getBounds();
				var center = bounds.getCenter();

				obj.x = previewWidth / 2 - center.x;
				obj.y = previewHeight / 2 - center.y;

				var t = new h2d.Text( hxd.Res.fnt.kodenmanhou16.toFont(), asset.scene);

				t.text = Path.withoutDirectory( Path.withoutExtension(asset.file) );
				t.textAlign = Center;
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.color = Vector.fromColor( getTypeColor(asset.file) );
				t.dropShadow = { dx:1, dy : 1, color : 0, alpha : 1 };

			case "atlas":
				asset.scene = new h2d.Scene();
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

				var t = new h2d.Text( hxd.Res.fnt.kodenmanhou16.toFont(), asset.scene);

				t.text = Path.withoutDirectory( Path.withoutExtension(asset.file) );
				t.textAlign = Center;
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.color = Vector.fromColor( getTypeColor(asset.file) );
				t.dropShadow = { dx:1, dy : 1, color : 0, alpha : 1 };

			case "fbx":
				asset.scene3d = new h3d.scene.Scene();
				var cache = new h3d.prim.ModelCache();
				var newObject = cache.loadModel( hxd.Res.loader.load( asset.file ).toModel() );
				asset.scene3d.addChild( newObject);
				asset.texture = new Texture(previewWidth,previewHeight, [Target] );

				var t = new h2d.Text( hxd.Res.fnt.kodenmanhou16.toFont(), asset.scene);

				t.text = Path.withoutDirectory( Path.withoutExtension(asset.file) );
				t.textAlign = Center;
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.color = Vector.fromColor( getTypeColor(asset.file) );
				t.dropShadow = { dx:1, dy : 1, color : 0, alpha : 1 };

			case "wav" | "mp3" | "ogg":

				asset.scene = new h2d.Scene();
				var g = new Graphics(asset.scene);
				var t = new h2d.Text( hxd.Res.fnt.kodenmanhou16.toFont(), asset.scene);
				t.dropShadow = { dx:1, dy : 1, color : 0, alpha : 1 };

				t.text = Path.withoutDirectory( Path.withoutExtension(asset.file) );
				t.textAlign = Center;
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.color = Vector.fromColor( getTypeColor(asset.file) );



				sys.thread.Thread.create(() -> {
					var sound = hxd.Res.load( asset.file ).toSound();
					var data = sound.getData();

					var resample: hxd.snd.WavData = cast data.resample(8000, UI8, data.channels );

					var sampleCount = resample.duration * resample.samplingRate;




					g.moveTo(0, previewHeight / 2);
					g.lineStyle(1,0xAAAAAA);
					var scale = 4;
					for( i in 0 ... previewWidth )
					{

						var pct = i / previewWidth;
						var loc = pct * resample.duration;
						var idx = Math.floor( loc * resample.samplingRate );
						var min = 0.;
						var max = 0.;
						for( i in 0 ... 25 )
						{
							var val = ( ( @:privateAccess resample.rawData.get(idx + i*2) / 255.) - 0.5 ) * previewHeight;
							min = Math.min(min, val);
							max = Math.max(max, val);
						}
						g.lineTo(i,min + previewHeight / 2);
						g.lineTo(i,max + previewHeight / 2);
					}
					asset.dirty = true;
				});




				trace("Not waiting for thread....");





			default:
				asset.scene = new h2d.Scene();
				var bmp = new Bitmap( hxd.Res.tools.hexagonal_nut.toTile(), asset.scene );
				bmp.width = previewWidth;
				bmp.height = previewHeight;

				var t = new h2d.Text( hxd.Res.fnt.kodenmanhou16.toFont(), asset.scene);
				t.dropShadow = { dx:1, dy : 1, color : 0, alpha : 1 };

				t.text = Path.withoutDirectory( Path.withoutExtension(asset.file) );
				t.textAlign = Center;
				t.maxWidth = previewWidth - 8;
				t.x = 4;
				t.y = 4;
				t.color = Vector.fromColor( getTypeColor(asset.file) );


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
		ImGui.begin("\uf07c Asset browser", isOpenRef, ImGuiWindowFlags.NoDocking);

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
			#if cannonml
			case "cml":
				var t: BulletEditor = cast ImguiToolManager.showTool("BulletEditor");
				t.openFile( asset.file );
			#end
			case "cui":
				var t: UIEditor = cast ImguiToolManager.showTool("UIEditor");
				t.openFile( asset.file );
			case "csd":
				var t: SpriteEditor = cast ImguiToolManager.showTool("SpriteEditor");
				t.openFile( asset.file );
			case "atlas":
				var t: AtlasBrowser = cast ImguiToolManager.showTool("AtlasBrowser");
				t.openFile( asset.file );
			#if cannonml
			case "cbl":
				var t: BulletLevelEditor = cast ImguiToolManager.showTool("BulletLevelEditor");
				t.openFile( asset.file );
			#end

			case "wav" | "ogg" | "mp3":
				hxd.Res.load( asset.file ).toSound().play();
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

		var typeColor: ImVec4 =  IG.colorToImVec4( getTypeColor( asset.file ) );
		switch(ext)
		{
			case "png" | "bmp" | "gif" | "jpg":
				ImGui.textColored(typeColor,"Texture");
				ImGui.separator();
				ImGui.image(asset.texture, {x: Math.min( asset.texture.width, 512 * scaleFactor), y: Math.min(asset.texture.height, 512 * scaleFactor) });
			default:
				ImGui.textColored(typeColor,getItemType(asset));

		}

		ImGui.endTooltip();
	}

	function getTypeColor( file: String )
	{
		var ext = Path.extension( file );
		return switch(ext)
		{
			case "wav" | "mp3" | "ogg": 0xFF88FF88;
			case "cui": 0xFF8888FF;
			case "atlas": 0xFFff8888;
			case "csd": 0xFF88ffff;
			case "fbx": 0xFFff88ff;
			case "png" | "bmp" | "gif": 0xFFffff88;
			default: 0xFFFFFFFF;
		}
	}

	function getItemType( asset: AssetBrowserPreviewItem )
	{

		var ext = Path.extension( asset.file );
		return switch(ext)
		{
			case "fnt" | "msdf" | "sdf": "Font";
			case "cui": "UI Layout";
			case "png" | "bmp" | "gif" | "jpg": "Image";
			case "wav" | "ogg" | "mp3": "Sound";
			case "bdef": "Butai";
			case "csd": "Sprite";
			case "atlas": "Texture Atlas";
			case "fbx": "Model";
			#if cannonml
			case "cml": "Cannon Bullet File";
			case "cbl": "Cannon Bullet Level";
			#end
			default: "Others";

		}

	}


	override public function render( e: h3d.Engine)
	{
		Metrics.begin();
		for( file => target in previews )
		{
			if( !target.dirty && !target.alwaysUpdate )
				continue;

			target.texture.clear( 0 );

			e.pushTarget( target.texture );
			e.clear(0,1);
			if( target.scene != null )
				target.scene.render(e);
			if( target.scene3d != null )
				target.scene3d.render(e);
			e.popTarget();

			target.dirty = false;
		}
		Metrics.end();
	}

}
#end