
package cerastes.tools;
import hxd.res.Sound;
import cerastes.SoundManager;
import cerastes.SoundManager;
import cerastes.tools.ImguiTools.IG;
#if hlimgui
import hxd.Key;
import sys.io.File;
import game.GameState;
import cerastes.data.Nodes.Link;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;

import cerastes.flow.Flow;
import haxe.rtti.Meta;
import haxe.rtti.Rtti;
import cerastes.tools.ImguiTool.ImguiToolManager;
import cerastes.tools.ImguiTools.ComboFilterState;
import cerastes.tools.ImguiTools.ImGuiTools;

import hl.Ref;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import imgui.NodeEditor;
import hl.UI;

@:structInit
class AETreeNode
{
	public var name: String = "Root";
	public var cues: Map<String, SoundCue> = [];
	public var children: Array<AETreeNode> = [];
}

@:keep
@multiInstance(true)
class AudioEditor extends ImguiTool
{

	var cues: Map<String, SoundCue> = [];

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var cueTree: AETreeNode = {};


	var fileName: String = null;

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var nestedCues: Array<String> = [];

	var selectedTreeNode: AETreeNode;
	var selectedTreeCue: String;
	var selectedCue: SoundCue;

	var zoom: Float = 500; // pixels per second


	public function new()
	{

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		openFile( "data/soundtest.audio" );
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
		ImGui.setNextWindowSize({x: windowWidth * 0.7, y: windowHeight * 0.7}, ImGuiCond.Once);
		ImGui.begin('\uf569 Audio Editor ${fileName != null ? fileName : ""}###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('View##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		cueEditor();

		ImGui.end();

		browser();
		inspector();


		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}


	}

	inline function sToPixel( seconds: Float )
	{
		return ( seconds * zoom );
	}

	function cueEditor()
	{
		if( selectedCue == null )
			return;


		ImGui.pushStyleColor( ImGuiCol.ChildBg, 0x66444444 );
		ImGui.beginChild("tracklist",{x: -1, y: 0}, false, ImGuiWindowFlags.HorizontalScrollbar );
		var windowPos = ImGui.getWindowPos();

		var size: ImVec2 = ImGui.getWindowSize();

		var x = ImGui.getCursorPosX();
		var step = 100;


		while( x < size.x  )
		{


			var ms = x / zoom * 1000;

			ImGui.sameLine();
			ImGui.setCursorPosX(x);
			ImGui.textColored( {x: 1, y: 1, z: 1, w: 0.5}, '${ms}ms');



			x += step;
		}

		var screenPos = ImGui.getWindowPos();

		//ImGui.dummy({x: 10, y: 35});

		var cursorPos = ImGui.getCursorPos();

		if( selectedCue.tracks == null ) selectedCue.tracks = [];

		var trackIdx = 0;
		for(track in selectedCue.tracks )
		{
			renderTrack( track, trackIdx++ );
		}


		var drawList = ImGui.getWindowDrawList();

		var size: ImVec2 = ImGui.getWindowSize();

		var x = 0;

		var startX = screenPos.x;
		var startY = screenPos.y + ImGui.getFontSize();

		drawList.addLine({x: startX + x, y: startY}, {x: startX + x + size.x, y: startY}, 0x33FFFFFF, 2.0);

		while( x < size.x )
		{

			drawList.addLine({x: startX + x, y: startY}, {x: startX + x, y: startY + size.y}, 0x33FFFFFF, 2.0);
			x += step;
		}

		ImGui.endChild();
		ImGui.popStyleColor();
	}

	static var imguiIds: Map<String, ImGuiID> = [];
	function getID( id: String )
	{
		if( !imguiIds.exists(id) )
			imguiIds.set(id, ImGui.getID(id));

		return imguiIds[id];
	}

	function renderTrack( track: SoundCueTrack, idx: Int)
	{
		var trackHeight = 50;



		ImGui.textColored({x: 1, y: 1, z: 0.5, w: 1.0},'Track ${idx+1}');

		var padding = 8;
		ImGui.pushStyleVar2( ImGuiStyleVar.FramePadding, {x: 2, y: padding} );

		ImGui.beginChildFrame( getID('track_${idx}'), {x: -1, y: trackHeight}, ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse );


		var pos = ImGui.getCursorPos();


		if( track.items == null ) track.items = [];
		for( item in track.items )
		{
			renderItem( item, trackHeight - padding * 2, pos );
		}

		ImGui.endChildFrame();

		ImGui.popStyleVar();
	}

	function renderItem( item: SoundCueItem, height: Float, pos: ImVec2)
	{
		var start = item.start;
		var end = item.end;
		if( item.end == 0 )
		{
			if( item.type == Clip )
			{
				// Load the clip and determine its length
				var sound = hxd.Res.loader.loadCache( item.name, Sound ).getData();
				end = start + sound.duration;
			}
			else
			{
				// ????!?!?!
				end = start + 100;
			}
		}

		start = pos.x + sToPixel( start );
		end = pos.x + sToPixel( end );

		ImGui.setCursorPosX( start );

		ImGui.pushStyleColor( ImGuiCol.Header, 0x8811DDDD );

		//drawList.addRectFilled( {x: startPos.x + start, y: startPos.y }, { x: startPos.x + end, y: startPos.y + height  }, 0x88AADD11 );
		ImGui.selectable( item.name, true, 0, {x: end - start, y: height} );
		//ImGui.setCursorPosX( start + 20 );
		//ImGui.text( item.name );


		ImGui.popStyleColor();

	}




	function browser()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Cues##${windowID()}');
		handleShortcuts();

		ImGui.beginChild("cuelist",null, false, ImGuiWindowFlags.AlwaysAutoResize);

		populateBrowser( cueTree );

		ImGui.endChild();



		ImGui.end();

	}

	function recomputeTree()
	{

		var sortedCues: Array<String> = [ for( k => v in cues ) k ];
		sortedCues.sort( Reflect.compare );

		for( cue in sortedCues )
		{
			var path = cue.split(".");
			//var name = path.pop();
			setLeaf( path, cues[cue] );
		}

	}
	function setLeaf( path: Array<String>, cue: SoundCue )
	{
		var target: AETreeNode = cueTree;
		for( i in 0 ... path.length )
		{
			var isLeaf = i == path.length - 1;
			var node = path[i];
			if( isLeaf )
			{
				target.cues.set(node, cue);
			}
			else
			{
				var t: AETreeNode = null;
				for( branch in target.children )
				{
					if( branch.name == node)
					{
						t = branch;
						break;
					}
				}

				if( t == null )
				{
					t = {
						name: node
					}
					target.children.push( t );
				}
				target = t;
			}
		}
	}

	function populateBrowser( node: AETreeNode )
	{

		for( child in node.children )
		{

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			//if( c.children.length == 0)
			//	flags |= ImGuiTreeNodeFlags.Leaf;

			var icon = '\uf07c';

			if( selectedTreeNode == child )
			{
				flags |= ImGuiTreeNodeFlags.Selected;

			}

			var name = '${icon} ${child.name}';

			var isOpen = ImGui.treeNodeEx( name, flags );

			if( ImGui.isItemClicked() )
			{
				selectedTreeNode = child;
				selectedTreeCue = null;
			}



			if( isOpen  )
			{
				if( child.children.length > 0)
				{
					populateBrowser(child);
				}

				for( name => cue in child.cues )
				{

					var flags = ImGuiTreeNodeFlags.Leaf;

					if( selectedCue == null )
						selectedCue = cue; //@temp



					var icon = '\uf028';

					if( selectedTreeCue == name )
					{
						flags |= ImGuiTreeNodeFlags.Selected;
					}

					var label = '${icon} ${name}';

					var isOpen = ImGui.treeNodeEx( label, flags );

					if( ImGui.isItemClicked() )
					{
						selectedTreeCue = name;
						selectedCue = cue;
						selectedTreeNode = null;
					}

					if( isOpen )
						ImGui.treePop();


				}

				ImGui.treePop();
			}

		}


	}


	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');
		handleShortcuts();

		ImGui.text("!!");


		ImGui.end();

	}




	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'AudioEditorDockspace${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut: hl.Ref<ImGuiID> = dockspaceId;

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}

	public function openFile( fileName: String )
	{
		var file: SoundCueFile = CDParser.parse(hxd.Res.loader.load( fileName ).toText(), SoundCueFile );
		cues = file.cues;

		recomputeTree();

	}

	function saveAs()
	{
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes audio files", exts:["audio"]}
			]
		});
		if( newFile != null )
		{
			fileName = Utils.toLocalFile( newFile );


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

	}

	function handleShortcuts()
	{
		if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}
	}

	function menuBar()
	{

		handleShortcuts();
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( fileName != null && ImGui.menuItem("Save", "CTRL+S"))
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

	public override inline function windowID()
	{
		return 'audioeditor${fileName != null ? fileName : ""+toolId}';
	}

}

#end