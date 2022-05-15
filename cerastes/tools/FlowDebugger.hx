
package cerastes.tools;

import haxe.crypto.Md5;
#if hlimgui

import cerastes.flow.Flow;
import h3d.Engine;
import hxd.Key;
import h2d.Tile;
import cerastes.macros.Metrics;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTool.ImguiToolManager;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import cerastes.data.Nodes;

@:structInit
class FlowHistoryElement
{
	public var file: String;
	public var depth: Int;
	public var fromNode: FlowNode;
	public var toNode: FlowNode;
	public var fromPin: PinId32;
}

@:keep
class FlowDebugger extends ImguiTool
{

	var scaleFactor = Utils.getDPIScaleFactor();

	static var flowHistory: List<FlowHistoryElement> = new List<FlowHistoryElement>();

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	static var stackChanged = true;


	public function new()
	{

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		//openFile( "data/nested_test.flow" );
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
		ImGui.begin('\uf1de Flow debugger###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('View##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		renderStack();

		processMouse();


		ImGui.end();

		inspector();



		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}

	}

	function renderStack()
	{
		var x: Float = 0;
		var d = ImGui.getWindowDrawList();

		var nodeWidth = 40 * scaleFactor;
		var nodeHeight = 20 * scaleFactor;
		var nodePadding = 5 * scaleFactor;

		var style = ImGui.getStyle();

		var windowPos = ImGui.getWindowPos();
		var scrollPosX: Float = ImGui.getScrollX();


		x  = windowPos.x - scrollPosX;




		for( h in flowHistory)
		{
			var checksum = Md5.encode( '${h.file}-${h.toNode.id}' );
			checksum = checksum.substr(-5);

			var y: Float = windowPos.y + h.depth * nodeHeight;
			var n = h.toNode;
			var pos: ImVec2S = { x: x, y: y };
			d.addRectFilled(pos, { x: x + nodeWidth, y: y + nodeWidth }, @:privateAccess n.def.color, style.TabRounding, ImDrawFlags.RoundCornersAll  );
			d.addText( { x: pos.x + style.FramePadding.x + 2, y: pos.y + style.FramePadding.y + 2 }, 0xFF000000, checksum );
			d.addText( { x: pos.x + style.FramePadding.x, y: pos.y + style.FramePadding.y }, 0xFFFFFFFF, checksum );


			x += nodeWidth + nodePadding;
		}

		ImGui.dummy({x: x - windowPos.x + scrollPosX, y: nodeHeight * 4});

		if( stackChanged )
		{
			stackChanged = false;
			ImGui.setScrollX( ImGui.getScrollMaxX() + nodeWidth + nodePadding );
		}
	}

	function handleShortcuts()
	{
		if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{

		}
	}


	public static function addHistory(runner: FlowRunner, from: FlowNode, to: FlowNode, fromPin: PinId32)
	{
		var depth = 0;
		var r = runner;
		while( r.parent != null )
		{
			depth++;
			r = r.parent;
		}
		flowHistory.add({
			file: @:privateAccess runner.file,
			fromNode: from,
			toNode: to,
			fromPin: fromPin,
			depth: depth
		});

		stackChanged = true;
	}

	function menuBar()
	{

		handleShortcuts();
		if( ImGui.beginMenuBar() )
		{
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
		return 'flowDebugger';
	}


	var mouseStart: ImVec2;
	function processMouse()
	{

	}


	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');
		handleShortcuts();


		ImGui.end();

	}





	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'FlowDebuggerDockspace${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut: hl.Ref<ImGuiID> = dockspaceId;

			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}


}

#end