package cerastes.tools;

#if hlimgui
import hxd.DropFileEvent;
import cerastes.ui.Anim;
using imgui.ImGui.ImGuiKeyStringExtender;
import cerastes.fmt.CUIResource;
import cerastes.fmt.AtlasResource.PackMode;
import hl.UI;
import hxd.Key;
import imgui.ImGuiMacro.wref;
import cerastes.file.CDParser;
import cerastes.fmt.AtlasResource.Atlas;
import cerastes.fmt.AtlasResource.AtlasEntry;
import cerastes.fmt.AtlasResource.AtlasFrame;
import h2d.Tile;
import cerastes.tools.ImguiTool.ImGuiToolManager;
import h2d.Text;
import h2d.Font;
import cerastes.tools.ImguiTools.IG;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import h3d.mat.Texture;
import h2d.Bitmap;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import imgui.ImGui;
import h2d.Object;
import haxe.ds.Map;
import cerastes.macros.MacroUtils.imTooltip;

enum AESelectedObjectType {
	None;
	Entry;
	Frame;
}


@multiInstance(true)
class AtlasBuilder  extends  ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var filterText: String = "";

	var scaleFactor = Utils.getDPIScaleFactor();

	var atlas: Atlas;

	var previewWidth : Float;
	var previewHeight: Float;

	var selectedEntry: AtlasEntry;
	var selectedFrame: AtlasFrame;

	var selectedItemType: AESelectedObjectType = None;

	var previewAnim: cerastes.ui.Anim;
	var previewScene: h2d.Scene;
	var sceneRT: Texture;


	static var globalIndex = 0;
	var index = 0;

	var isInspectorHovered: Bool = false;

	public override function getName() { return '\uf247 Atlas Editor (${fileName})'; }

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

		previewWidth = 100 * scaleFactor;
		previewHeight = 50 * scaleFactor;

		index = globalIndex++;

		atlas = {};

		previewScene = new h2d.Scene();
		previewScene.scaleMode = Fixed(viewportWidth,viewportHeight, 1, Left, Top);
		sceneRT = new Texture(10,10, [Target] );

		// TESTING
		//openFile("atlases/TextureGroup1.catlas");
	}

	public override function openFile( f: String )
	{
		fileName = f;

		atlas = CDParser.parse( hxd.Res.loader.load( fileName ).toText(), cerastes.fmt.AtlasResource.Atlas );
		atlas.load();


	}

	override function onWindowChanged( w: hxd.Window )
	{
		if( window != null )
		{
			window.removeDragAndDropTarget( onFileDrop );
		}
		if( w != null )
			w.addDragAndDropTarget( onFileDrop );
	}


	function onFileDrop( event : DropFileEvent )
	{
		if( isInspectorHovered && selectedEntry != null )
		{
			for( f in event.files )
				addFrame( selectedEntry, f.file );
		}
		else
		{
			for( f in event.files )
				addSprite( f.file );
		}

		if( fileName != null && fileName != "")
			atlas.pack( fileName, false );

	}


	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		if( forceFocus )
		{
			forceFocus = false;
			ImGui.setNextWindowFocus();
		}
		ImGui.setNextWindowSize({x: 700 * scaleFactor, y: 400 * scaleFactor}, ImGuiCond.Once);
		ImGui.begin('\uf247 Atlas Editor (${fileName})###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);


		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		packer();

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('View##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );

		var vp = ImGui.viewportGetCurrentViewport();
		setWindow( vp.PlatformHandle );

		handleShortcuts();

		var text = IG.textInput("##Filter",filterText,"Filter");
		if( text != null )
			filterText = text;


		ImGui.beginChild("atlasbrowser_assets",null, false, ImGuiWindowFlags.AlwaysAutoResize);



		populateTiles();

		ImGui.endChild();

		ImGui.end();

		inspector();


		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}
	}

	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Inspector##${windowID()}');
		handleShortcuts();

		if( selectedEntry != null )
		{
			ImGui.pushFont( ImGuiToolManager.headingFont );
			ImGui.text( selectedEntry.name );
			ImGui.popFont();

			var oldName = selectedEntry.name;
			var name = selectedEntry.name;
			if( ImGui.inputText( "ID", name ) )
			{
				selectedEntry.name = name;
				atlas.entries[name] = selectedEntry;
				atlas.entries.remove(oldName);
			}

			ImGui.text("Frames");
			ImGui.separator();
			ImGui.beginChildFrame( ImGui.getID( "frames" ), {x: -1, y: 100 * ImGuiToolManager.scaleFactor});

			for( frame in selectedEntry.frames )
			{
				var file = frame.file;
				var bits = file.split("/");
				var name = bits.length > 0 ? bits[bits.length - 1] : file;

				var flags = ImGuiTreeNodeFlags.DefaultOpen | ImGuiTreeNodeFlags.Leaf;
				if( selectedItemType == Frame && frame == selectedFrame )
					flags |= ImGuiTreeNodeFlags.Selected;

				if( ImGui.treeNodeEx( '${name}', flags ) )
				{
					if( ImGui.isItemHovered() )
					{
						onFrameHover( frame );
					}
					if( ImGui.isItemClicked( ) )
					{
						selectedFrame = frame;
						selectedItemType = Frame;
					}
					ImGui.treePop();
				}
			}

			ImGui.endChildFrame();

			if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
			{
				ImGui.openPopup('${windowID()}_framerc');
			}

			if( ImGui.beginPopup('${windowID()}_framerc') )
			{

				if( ImGui.menuItem( 'Add...') )
				{
					addFrame( selectedEntry );
				}

				ImGui.endPopup();
			}

			if( selectedFrame != null )
			{
				if( ImGui.button("Move Up") )
				{
					var idx = selectedEntry.frames.indexOf( selectedFrame );
					if( idx > 0 )
					{
						selectedEntry.frames.remove( selectedFrame );
						selectedEntry.frames.insert(idx-1, selectedFrame );
					}
				}
				ImGui.sameLine();
				if( ImGui.button("Move Down") )
				{
					var idx = selectedEntry.frames.indexOf( selectedFrame );
					if( idx > 0 )
					{
						selectedEntry.frames.remove( selectedFrame );
						selectedEntry.frames.insert(idx+1, selectedFrame );
					}
				}
				// NL
				if( ImGui.button("Clone") )
				{
					var idx = selectedEntry.frames.indexOf( selectedFrame );
					if( idx == -1 ) idx = 0;

					selectedEntry.frames.insert(idx+1, selectedFrame.clone() );
				}
				ImGui.sameLine();
				if( ImGui.button("Remove") )
				{
					var idx = selectedEntry.frames.indexOf( selectedFrame );
					if( idx > 0 )
					{
						selectedEntry.frames.remove( selectedFrame );
					}
				}
				// NL
				ImGui.inputInt("Frame duration (ms)", selectedFrame.duration, 10, 100 );
				ImGui.checkbox("Skip trim", selectedFrame.noTrim );
				ImGui.inputInt("Padding", selectedFrame.padding );




				ImGui.separator();
			}



			var hasDefaultFrame = selectedEntry.defaultFrame != -1;
			if( ImGui.checkbox("Default Frame", hasDefaultFrame) )
			{
				selectedEntry.defaultFrame = hasDefaultFrame ? 0 : -1;
			}
			imTooltip( "This is the frame that will be used when the animation isn't playing. Useful for things like blinks, where we don't want to hide the underlying sprite when we're not animating." );


			if( hasDefaultFrame )
			{
				ImGui.inputInt("Frame Index", selectedEntry.defaultFrame,1,10 );
				imTooltip( "Frame number to use as the default frame." );

			}

			ImGui.separator();

			ImGui.image(sceneRT, { x: selectedEntry.size.x, y: selectedEntry.size.y }, null, null, null, {x: 1, y: 1, z:1, w:1} );



		} // end selected entry

		var wpos = ImGui.getWindowPos();
		var wsize = ImGui.getWindowSize();
		var mouse = ImGui.getMousePos();
		isInspectorHovered =	wpos.x < mouse.x && wpos.x + wsize.x > mouse.x &&
								wpos.y < mouse.y && wpos.y + wsize.y > mouse.y;

		ImGui.end();
	}

	function packer()
	{
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Packer##${windowID()}');
		handleShortcuts();

		// Fixup
		if( atlas.size == null )
			atlas.size = {x: 32, y: 32};

		if( atlas.packMode == null )
			atlas.packMode = MaxRects;

		if( ImGui.button("Pack") )
		{
			atlas.pack( fileName );
		}
		ImGui.sameLine();

		ImGui.text("Size:");
		ImGui.sameLine();
		ImGui.setNextItemWidth(200);
		wref( ImGui.inputInt("##Width", _), atlas.size.x );
		ImGui.sameLine();
		ImGui.setNextItemWidth(200);
		wref( ImGui.inputInt("##Height", _), atlas.size.y );
		ImGui.sameLine();

		ImGui.setNextItemWidth(200);
		var out = IG.combo("Mode", atlas.packMode, PackMode );
		if( out != null )
			atlas.packMode = out;

		if( atlas.textureFile != null )
			IG.image( CUIResource.getTile( atlas.textureFile) );
		else
			ImGui.text("No atlas built.");

		ImGui.end();
	}


	function populateTiles()
	{

		var windowPos : ImVec2 =  ImGui.getWindowPos();
		var windowContentRegionMax : ImVec2 = ImGui.getWindowContentRegionMax();
		var windowRight = windowPos.x + windowContentRegionMax.x;
		var style : ImGuiStyle = ImGui.getStyle();

		final buttonWidth = 128 * scaleFactor;
		final buttonHeight = 128 * scaleFactor;

		var style = ImGui.getStyle();

		for(name => entry in atlas.entries )
		{
			if( filterText.length > 0 && !StringTools.contains(name, filterText) )
				continue;

			var tile = entry.tile;
			if( tile.width == 0 && tile.height == 0 && entry.tiles.length > 0 )
				tile = entry.tiles[1];

			ImGui.pushID('btn_${name}');

			var desiredW = ( previewHeight / tile.height ) * tile.width;

			//if( IG.imageButton( tile, {x: desiredW, y: previewHeight}, -1, 2 ) )
			var buttonPos = ImGui.getCursorPos();
			if( ImGui.button('',{x: buttonWidth, y: buttonHeight } ) )
			{
				previewScene.removeChildren();
				selectedEntry = entry;
				selectedItemType = Entry;
				selectedFrame = null;
				previewAnim = new Anim(selectedEntry, previewScene);
				previewAnim.loop = true;
				sceneRT.resize( entry.size.x > 0 ? entry.size.x : 1, entry.size.y > 0 ? entry.size.y : 1 );
			}


			if( ImGui.isItemHovered() )
			{
				onItemHover(entry);
			}



			if( ImGui.beginDragDropSource() )
			{
				ImGui.setDragDropPayloadString("atlas_tile",'$fileName|$name');

				onItemHover(entry);

				ImGui.endDragDropSource();
			}

			var itemRectMax: ImVec2 = ImGui.getItemRectMax();
			var nextButtonX2 = itemRectMax.x + style.ItemSpacing.x + previewWidth;
			if( nextButtonX2 < windowRight )
				ImGui.sameLine();

			var restorePos = ImGui.getCursorPos();


			var scale = 2.0;
			if( tile.width * scale > buttonWidth )
				scale = buttonWidth / tile.width;

			if( tile.height * scale > buttonHeight )
				scale = buttonHeight / tile.height;

			var px = buttonPos.x + buttonWidth / 2 - ( tile.width * scale ) / 2;
			var py = buttonPos.y + buttonHeight / 2 - ( tile.height * scale ) / 2;

			ImGui.setCursorPos( {x: px, y: py } );

			IG.image( tile, {x: scale, y: scale } );

			ImGui.setCursorPos( restorePos );

			ImGui.popID();


		}
	}

	function onItemHover( entry: AtlasEntry )
	{
		ImGui.beginTooltip();
		ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.text(entry.name);
		ImGui.popFont();
		ImGui.text('Entry size=${entry.size.x}x${entry.size.y}, ${entry.frames.length} tiles.');
		ImGui.separator();

		var hoverSize = 1024 * scaleFactor;

		var scale = 2.0;
		if( entry.size.x * scale > hoverSize )
			scale = hoverSize / entry.size.x;

		if( entry.size.y * scale > hoverSize )
			scale = hoverSize / entry.size.y;

		for( i in 0 ... entry.frames.length )
		{
			var frame = entry.frames[i];
			ImGui.text('Frame ${i} size=${frame.size.x}x${frame.size.y}, offset=${frame.offset.x}x${frame.offset.y}, pos=${frame.pos.x}x${frame.pos.y}');
			IG.image( frame.tile, {x: scale, y: scale} );
		}



		ImGui.endTooltip();
	}

	function onFrameHover( frame: AtlasFrame )
	{
		ImGui.beginTooltip();
		ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.text(frame.file);
		ImGui.popFont();
		ImGui.separator();

		var hoverSize = 1024 * scaleFactor;

		var scale = 2.0;
		if( frame.size.x * scale > hoverSize )
			scale = hoverSize / frame.size.x;

		if( frame.size.y * scale > hoverSize )
			scale = hoverSize / frame.size.y;

		ImGui.text('size=${frame.size.x}x${frame.size.y}, offset=${frame.offset.x}x${frame.offset.y}, pos=${frame.pos.x}x${frame.pos.y}');
		IG.image( frame.tile, {x: scale, y: scale} );


		ImGui.endTooltip();
	}

	public override inline function windowID()
	{
		return 'catlased${fileName != null ? fileName : ""+toolId}';
	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'CAtlasEditorDS${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			//dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.30, null, idOut);
			//dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}


	function saveAs()
	{
		hxd.System.allowTimeout = false;
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes atlas files", exts:["catlas"]}
			]
		});
		hxd.System.allowTimeout = true;
		if( newFile != null )
		{
			fileName = Utils.toLocalFile( newFile );

			save();


			cerastes.tools.AssetBrowser.needsReload = true;
		}
	}

	function save()
	{
		if( fileName == null )
		{
			saveAs();
			return;
		}

		#if binpacking
		atlas.pack(fileName);
		ImGuiToolManager.showPopup("Pack job started",'May take several minutes depending on the texture size.', Info);
		#else
		ImGuiToolManager.showPopup("Save failure",'Not build with binpacker!', Error);
		#end
	}

	function addSprite(newFile: String = null)
	{
		if( newFile == null )
		{
			hxd.System.allowTimeout = false;
			newFile = UI.loadFile({
				title:"Add Sprite...",
				filters:[
				{name:"Images", exts:["png"]}
				]
			});
			hxd.System.allowTimeout = true;
		}
		if( newFile != null )
		{
			var fileName = Utils.toLocalFile( newFile );

			// This broke at some poin....
			//if( Utils.assert( hxd.File.exists( fileName ), 'Could not locate rel path to $newFile' ) )
			{
				atlas.add(fileName);
			}

		}

		atlas.rebuildLinks();
	}

	function addFrame( entry: AtlasEntry, newFile: String = null )
	{
		if( newFile == null )
		{
			hxd.System.allowTimeout = false;
			newFile = UI.loadFile({
				title:"Add Frame...",
				filters:[
				{name:"Images", exts:["png"]}
				]
			});
			hxd.System.allowTimeout = true;
		}
		if( newFile != null )
		{
			var fileName = Utils.toLocalFile( newFile );
			// This broke at some poin....
			//if( hxd.File.exists( fileName ))
			{
				var frame: AtlasFrame = {
					file: fileName
				};

				entry.frames.push( frame );
			}
		}

		atlas.rebuildLinks();
	}

	function handleShortcuts()
	{
		var io = ImGui.getIO();
		if( ImGui.isWindowFocused( ImGuiFocusedFlags.RootAndChildWindows ) )
		{
			if( io.KeyCtrl )
			{
				if( ImGui.isKeyPressed( 'S'.imKey() ) )
					save();
			}

			if( ImGui.isKeyPressed( ImGuiKey.Delete ) && selectedItemType == Frame && selectedFrame != null && selectedEntry != null )
			{
				selectedEntry.frames.remove( selectedFrame );
			}
		}
	}

	function menuBar()
	{

		handleShortcuts();
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( ImGui.menuItem("Add...", "Ctrl+N"))
				{
					addSprite();
				}

				if ( fileName != null && ImGui.menuItem("Save", "Ctrl+S"))
				{
					save();
				}
				if (ImGui.menuItem("Save As..."))
				{
					saveAs();
				}

				ImGui.endMenu();
			}
			if( ImGui.beginMenu("View", true) )
			{
				if (ImGui.menuItem("Reset docking"))
				{
					dockCond = ImGuiCond.Always;
				}
				ImGui.endMenu();
			}
			ImGui.endMenuBar();
		}
	}


	override public function render( e: h3d.Engine)
	{
		sceneRT.clear( 0 );

		var oldW = e.width;
		var oldH = e.height;

		e.pushTarget( sceneRT );
		e.clear(0,1);

		@:privateAccess// @:bypassAccessor
		{
			e.width = sceneRT.width;
			e.height = sceneRT.height;
			previewScene.checkResize();
			previewScene.setElapsedTime( ImGui.getIO().DeltaTime );
			previewScene.render(e);
			e.width = oldW;
			e.height = oldH;
		}

		e.popTarget();
	}


}

#end