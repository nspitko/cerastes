
package cerastes.tools;
#if hlimgui
import hxd.res.Sound;
import cerastes.SoundManager;
import cerastes.SoundManager;
import cerastes.tools.ImguiTools.IG;

import hxd.Key;
import sys.io.File;
import cerastes.data.Nodes.Link;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;

import cerastes.flow.Flow;
import haxe.rtti.Meta;
import haxe.rtti.Rtti;
import cerastes.tools.ImguiTool.ImGuiToolManager;
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
import imgui.ImGuiMacro.wref;

@:structInit
class AETreeNode
{
	public var name: String = "Root";
	public var cues: Map<String, SoundCue> = [];
	public var children: Array<AETreeNode> = [];
}

enum AESelectMode
{
	Cue;
	Item;
	Track;
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

	var selectMode: AESelectMode = Cue;

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var nestedCues: Array<String> = [];

	var selectedTreeNode: AETreeNode;
	var selectedTreeCue: String;
	var selectedCue: SoundCue;
	var selectedTrack: SoundCueTrack;
	var selectedItem: SoundCueItem;

	var showPopupNew = false;

	var zoom: Float = 50; // pixels per second

	var cueInstance: CueInstance;

	public override function getName() { return "\uf569 Audio Editor"; }

	public function new()
	{

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		//openFile( "data/soundtest.audio" );
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

		popups();


		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}


	}

	var tmpInput = "";
	function popups()
	{
		if( showPopupNew )
		{
			ImGui.openPopup("new_cue");
			showPopupNew = false;
		}

		if( ImGui.beginPopupModal('new_cue'))
		{

			ImGui.setKeyboardFocusHere();
			var r = IG.textInput("Name", tmpInput,ImGuiInputTextFlags.EnterReturnsTrue);

			if( r != null )
			{
				tmpInput = r;
				cues.set(tmpInput, {});
				recomputeTree();
				ImGui.closeCurrentPopup();
			}

			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}


			ImGui.endPopup();
		}
	}

	inline function sToPixel( seconds: Float )
	{
		return ( seconds * zoom );
	}

	inline function pixelToS( pixels: Float )
	{
		return pixels / zoom;
	}

	var nextScrollX: Float = -1;
	function cueEditor()
	{
		if( selectedCue == null )
			return;

		if( selectedCue.tracks == null ) selectedCue.tracks = [];


		ImGui.pushStyleColor( ImGuiCol.ChildBg, 0x66444444 );

		ImGui.beginChild("tracklist",{x: -1, y: 0}, false, ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.HorizontalScrollbar );
		var windowPos = ImGui.getWindowPos();
		if( nextScrollX > 0 )
		{
			 ImGui.setScrollX(nextScrollX);
			 nextScrollX = -1;
		}

		var trackWidth = getTrackAreaWidth( selectedCue );
		var contentWidth = ImGui.getContentRegionAvail().x;
		if( trackWidth > contentWidth  )
			contentWidth = trackWidth;

		//var size: ImVec2 = ImGui.getWindowSize();

		var x = ImGui.getCursorPosX();
		var step = 100;


		while( x < contentWidth  )
		{
			var ms = x / zoom * 1000;

			ImGui.sameLine();
			ImGui.setCursorPosX(x);
			ImGui.textColored( {x: 1, y: 1, z: 1, w: 0.5}, '${ Math.floor(ms)}ms');
			x += step;
		}

		var screenPos = ImGui.getWindowPos();

		//ImGui.dummy({x: 10, y: 35});

		var cursorPos = ImGui.getCursorPos();


		var trackIdx = 0;

		ImGui.pushStyleVar( ImGuiStyleVar.ButtonTextAlign, {x: 0.0, y: 0.5} );
		for(track in selectedCue.tracks )
		{
			renderTrack( track, trackIdx++, contentWidth );
		}
		ImGui.popStyleVar( );


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

		var scrollX = ImGui.getScrollX();
		ImGui.endChild();

		if( ImGui.isWindowHovered( ImGuiFocusedFlags.RootAndChildWindows ) )
		{
			if( Key.isPressed( Key.MOUSE_WHEEL_UP ) )
				zoom *= 1.1;
			else if( Key.isPressed( Key.MOUSE_WHEEL_DOWN ) )
				zoom *= 0.9;

			if( zoom < 1 )
				zoom = 1;

		}


		if( ImGui.isItemHovered(  ImGuiHoveredFlags.AllowWhenBlockedByActiveItem ) && ImGui.beginDragDropTarget( ) )
		{
			var dropPos = ImGui.getMousePos();
			var position = dropPos.x - screenPos.x;

			var start = pixelToS(position);
			var item = toDragDropItem(start);

			if( item != null )
			{
				var track: SoundCueTrack = {
					items: [ item ]
				}

				selectedCue.tracks.push(track);
			}
		}

		ImGui.popStyleColor();

		if( cueInstance != null && cueInstance.time > 0 && !cueInstance.isFinished )
		{
			var contentWidth = ImGui.getContentRegionAvail().x;


			var cursorPos = sToPixel( cueInstance.time );

			drawList.addLine({x: startX + cursorPos - scrollX, y: startY}, {x: startX +  cursorPos - scrollX, y: startY + size.y}, 0x77FF2222, 4.0);

			if( cursorPos > scrollX + contentWidth  )
				nextScrollX = cursorPos;
		}
	}

	function toDragDropItem( start: Float )
	{
		var payload = ImGui.acceptDragDropPayloadString("asset_name");
		var item: SoundCueItem = null;
		if( payload != null )
		{
			// Is it an audio file?
			if( StringTools.endsWith( payload, ".wav" ) || StringTools.endsWith( payload, ".ogg" ) || StringTools.endsWith( payload, ".mp3" ))
			{
				item = {
					name: payload,
					type: Clip,
					start: start
				}
			}
		}

		return item;

	}

	static var imguiIds: Map<String, ImGuiID> = [];
	function getID( id: String )
	{
		if( !imguiIds.exists(id) )
			imguiIds.set(id, ImGui.getID(id));

		return imguiIds[id];
	}

	function getTrackAreaWidth( cue: SoundCue ): Float
	{

		var w: Float = 0;
		for( track in cue.tracks )
		{
			for( i in track.items)
			{
				var end = getItemEnd( i );
				end = sToPixel( end );
				if( end > w )
					w = end;
			}
		}

		return w;
	}

	function renderTrack( track: SoundCueTrack, idx: Int, trackWidth: Float)
	{
		var trackHeight = 50;
		var screenPos = ImGui.getWindowPos();


		ImGui.textColored({x: 1, y: 1, z: 0.5, w: 1.0},'Track ${idx+1}');

		var padding = 8;
		ImGui.pushStyleVar( ImGuiStyleVar.FramePadding, {x: 2, y: padding} );

		ImGui.beginChildFrame( getID('track_${idx}'), {x: trackWidth, y: trackHeight}, ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse );

		var pos = ImGui.getCursorPos();
		if( track.items == null ) track.items = [];

		var trackItemMax: Float = 0;

		ImGui.pushStyleVar( ImGuiStyleVar.FrameBorderSize, 1 );
		ImGui.pushStyleColor( ImGuiCol.Border, 0xFFFFFFFF );

		for( item in track.items )
		{
			var end = renderItem( item, trackHeight - padding * 2, pos );
			if( end > trackItemMax )
				trackItemMax = end;
		}

		ImGui.popStyleColor();
		ImGui.popStyleVar();

		ImGui.endChildFrame();
		if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
		{
			selectedTrack = track;
			selectMode = Track;
		}
		//ImGui.dummy({x: trackItemMax, y: 1});


		if( ImGui.beginDragDropTarget() )
		{
			var dropPos = ImGui.getMousePos();
			var position = dropPos.x - screenPos.x;

			var start = pixelToS(position);
			var item = toDragDropItem(start);
			if( item != null )
			{
				var end = getItemEnd( item );


				// Nudge start to not collide with anything else on the track
				var blocked;
				do
				{
					blocked = false;
					for( i in track.items )
					{
						var otherEnd = getItemEnd( i );
						if( ( item.start < i.start && end > i.start ) || // Before
							( item.start < otherEnd && end > otherEnd ) ||  // after
							( item.start > i.start && end < otherEnd ) // inside
							)
						{
							item.start = otherEnd;
							end = getItemEnd(item);
							blocked = true;
						}
					}
				}
				while( blocked );


				track.items.push(item);
			}
		}


		ImGui.popStyleVar();
	}

	var dragLast: Float = -1;
	var dragItem: SoundCueItem = null;

	function renderItem( item: SoundCueItem, height: Float, pos: ImVec2)
	{
		var start = item.start;
		var end = getItemEnd( item );

		start = sToPixel( start );
		end = sToPixel( end );


		ImGui.sameLine();
		ImGui.setCursorPosX( pos.x + start );

		//ImGui.pushStyleColor( ImGuiCol.Button, 0x8811DDDD );

		//drawList.addRectFilled( {x: startPos.x + start, y: startPos.y }, { x: startPos.x + end, y: startPos.y + height  }, 0x88AADD11 );
		if( ImGui.button( item.name, {x: end - start, y: height} ) )
		{
			selectedItem = item;
			selectMode = Item;
		}

		if( dragItem == null && ImGui.isItemHovered() && ImGui.isMouseDown( ImGuiMouseButton.Left )  )
		{
			dragLast = ImGui.getMousePos().x;
			dragItem = item;

		}
		if( dragItem == item )
		{
			if( ImGui.isMouseDragging(ImGuiMouseButton.Left) )
			{

				var newX = ImGui.getMousePos().x;
				var delta = newX - dragLast;
				dragLast = newX;

				var localDelta = pixelToS(delta);
				item.start += localDelta;
				if( item.start < 0 ) item.start = 0;
			}
			else
			{
				dragItem = null;
			}
		}



		//ImGui.setCursorPosX( start + 20 );
		//ImGui.text( item.name );


		//ImGui.popStyleColor();

		return end;

	}



	function getItemEnd( item: SoundCueItem )
	{
		var end = item.end;
		if( end == 0 )
		{
			if( item.type == Clip )
			{
				// Load the clip and determine its length
				var sound = hxd.Res.loader.loadCache( item.name, Sound ).getData();
				end = item.start + sound.duration * ( item.pitch > 0 ? 1 / item.pitch : 1.0 );
			}
			else
			{
				// ????!?!?!
				end = item.start + 100;
			}
		}

		return end;
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
				target.cues.set( path.join("."), cue);
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
		var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
		//if( c.children.length == 0)
		//	flags |= ImGuiTreeNodeFlags.Leaf;

		var icon = '\uf07c';

		if( selectedTreeNode == node )
		{
			flags |= ImGuiTreeNodeFlags.Selected;

		}

		var name = '${icon} ${node.name}';

		var isOpen = ImGui.treeNodeEx( name, flags );

		if( ImGui.isItemClicked() )
		{
			selectedTreeNode = node;
			selectedTreeCue = null;
		}



		if( isOpen  )
		{
			if( node.children.length > 0)
			{
				for( child in node.children )
					populateBrowser(child);
			}

			for( name => cue in node.cues )
			{

				var flags = ImGuiTreeNodeFlags.Leaf;

				if( selectedCue == null )
					selectedCue = cue; //@temp



				var icon = '\uf028';

				if( selectedTreeCue == name )
				{
					flags |= ImGuiTreeNodeFlags.Selected;
				}

				var shortName = name.split('.').pop();


				var label = '${icon} ${shortName}';

				var isOpen = ImGui.treeNodeEx( label, flags );

				if( ImGui.isItemClicked() )
				{
					selectedTreeCue = name;
					selectedCue = cue;
					selectedTreeNode = null;
					selectMode = Cue;
				}

				if( isOpen )
					ImGui.treePop();


			}

			ImGui.treePop();
		}




	}


	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');
		handleShortcuts();

		switch( selectMode )
		{
			case Cue:
				if( selectedCue != null )
				{
					ImGui.pushFont( ImGuiToolManager.headingFont );
					ImGui.text( selectedTreeCue );
					ImGui.popFont();
				}

			case Track:
				ImGui.text("Track");
			case Item:
				if( selectedItem != null )
				{

					ImGui.pushFont( ImGuiToolManager.headingFont );
					ImGui.text( selectedItem.name );
					ImGui.popFont();

					wref( ImGui.sliderDouble( "Volume", _, 0, 2 ), selectedItem.volume );
					wref( ImGui.sliderDouble( "Volume Variance", _, -1, 1 ), selectedItem.volumeVariance );

					wref( ImGui.checkbox( "Loop", _ ), selectedItem.loop );

					wref( ImGui.sliderDouble( "Pitch", _, 0, 2 ), selectedItem.pitch );
					wref( ImGui.sliderDouble( "Pitch Variance", _, -1, 1 ), selectedItem.pitchVariance );

					wref( ImGui.sliderDouble( "Low Pass", _, 0, 1 ), selectedItem.lowpass );
					wref( ImGui.sliderDouble( "Low Pass Variance", _, -1, 1 ), selectedItem.lowpassVariance );



				}


		}



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

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}

	public override function openFile( fileName: String )
	{
		var file: SoundCueFile = CDParser.parse(hxd.Res.loader.load( fileName ).toText(), SoundCueFile );
		cues = file.cues;

		this.fileName = fileName;

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

		var obj: SoundCueFile = {
			cues: cues
		}

		sys.io.File.saveContent( Utils.fixWritePath(fileName,"audio"), CDPrinter.print( obj ) );


		ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
	}

	function handleShortcuts()
	{
		if( !ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) )
			return;
		if( Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}

		if( Key.isDown( Key.CTRL ) && Key.isPressed( Key.N ) )
		{
			showPopupNew = true;
		}

		if(  Key.isPressed( Key.SPACE ) )
		{
			if( selectedCue != null )
			{
				if( cueInstance != null && !cueInstance.isFinished )
					cueInstance.stop();
				else
					cueInstance = selectedCue.play();
			}
		}

		if( Key.isPressed( Key.DELETE ) )
		{
			switch( selectMode )
			{
				case Cue:
					cues.remove( selectedTreeCue );
					selectedCue = null;
					recomputeTree();
				case Track:
					if( selectedCue != null && selectedTrack != null )
					{
						for( t in selectedCue.tracks )
						{

							if( t == selectedTrack )
								selectedCue.tracks.remove(t);

						}
					}

				case Item:
					if( selectedCue != null && selectedItem != null )
					{
						for( t in selectedCue.tracks )
						{
							for( i in t.items )
							{
								if( i == selectedItem )
									t.items.remove( i );
							}
						}
					}
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
				if( ImGui.menuItem("New Cue", "Ctrl+N") )
				{
					showPopupNew = true;
				}
				ImGui.separator();
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