package cerastes.tools;

import imgui.ImGuiMacro.wref;
import cerastes.fmt.AtlasResource.PackMode;
import hl.UI;
import hxd.Key;
#if hlimgui
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

	var fileName: String = null;

	var atlas: Atlas;

	var previewWidth : Float;
	var previewHeight: Float;

	var selectedEntry: AtlasEntry;
	var selectedFrame: AtlasFrame;

	var selectedItemType: AESelectedObjectType = None;

	static var globalIndex = 0;
	var index = 0;

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

		// TESTING
		openFile("atlases/TextureGroup1.catlas");
	}

	public function openFile( f: String )
	{
		fileName = f;

		atlas = CDParser.parse( hxd.Res.loader.load( fileName ).toText(), cerastes.fmt.AtlasResource.Atlas );
		atlas.load();


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
					//var file =
				}

				ImGui.endPopup();
			}


		}

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

		IG.image( hxd.Res.loader.load(atlas.textureFile).toTile() );

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

			ImGui.pushID('btn_${name}');

			var desiredW = ( previewHeight / tile.height ) * tile.width;

			//if( IG.imageButton( tile, {x: desiredW, y: previewHeight}, -1, 2 ) )
			var buttonPos = ImGui.getCursorPos();
			if( ImGui.button('',{x: buttonWidth, y: buttonHeight } ) )
			{
				selectedEntry = entry;
				selectedItemType = Entry;
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

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			//dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}


	function saveAs()
	{
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes atlas files", exts:["catlas"]}
			]
		});
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

	function handleShortcuts()
	{
		if( !ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) )
			return;
		if( Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}
		if( Key.isDown( Key.DELETE) && selectedItemType == Frame && selectedFrame != null && selectedEntry != null )
		{
			selectedEntry.frames.remove( selectedFrame );
		}
	}

	function menuBar()
	{

		handleShortcuts();
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
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


}

#end