
package cerastes.tools;

import haxe.rtti.Meta;
import haxe.crypto.Md5;
#if hlimgui

import cerastes.flow.Flow;
import h3d.Engine;
import hxd.Key;
import h2d.Tile;
import cerastes.macros.Metrics;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTool.ImGuiToolManager;
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
	public var runnerId: Int;
	public var pos: haxe.PosInfos;
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

	var selectedItem: FlowHistoryElement = null;


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
			ImGuiToolManager.closeTool( this );
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
			ImGui.textColored( toImVec4ButBrighter( @:privateAccess h.toNode.def.color ),'${h.file}::${h.toNode.label}/${h.toNode.id}');
			if( ImGui.isItemHovered() )
			{
				ImGui.beginTooltip();
				ImGui.textColored( toImVec4ButBrighter( @:privateAccess h.fromNode.def.color ) ,'From ${h.fromNode.label}/${h.fromNode.id}');
				ImGui.text('In file ${h.file}');
				ImGui.text('With runner ${h.runnerId} (D=${h.depth})');
				ImGui.endTooltip();
			}
			if( ImGui.isItemClicked() )
			{
				selectedItem = h;
			}
		}

		if( stackChanged )
		{
			stackChanged = false;
			ImGui.setScrollY( ImGui.getScrollMaxY());
		}
	}

	function toImVec4ButBrighter( col: ImU32 )
	{
		var vec = ImVec4.getColor( col );

		vec.r *= 1.8;
		vec.g *= 1.8;
		vec.b *= 1.8;


		return vec;
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
			depth: depth,
			pos: runner.instigator,
			runnerId: runner.runnerId,
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


	@:access(cerastes.data.Node)
	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');
		handleShortcuts();

		if(selectedItem == null)
		{
			ImGui.end();
			return;
		}

		ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.textColored(toImVec4ButBrighter( selectedItem.toNode.def.color ), '${selectedItem.toNode.label}');
		ImGui.popFont();


		var textSize = ImGui.calcTextSize("test");
		var style = ImGui.getStyle();

		var meta: haxe.DynamicAccess<Dynamic> = Meta.getFields( Type.getClass( selectedItem.toNode ) );

		for( field => data in meta )
		{
			ImGui.columns(2);
			ImGui.setColumnWidth(0,100);

			var metadata: haxe.DynamicAccess<Dynamic> = data;
			if( metadata.exists("editor") )
			{
				var args = metadata.get("editor");
				var val = Reflect.getProperty(selectedItem.toNode, field );
				ImGui.text(args[0]);
				ImGui.nextColumn();

				ImGui.text(val.toString());
			}

			ImGui.columns(1);
		}

		ImGui.textColored( toImVec4ButBrighter( selectedItem.fromNode.def.color ) ,'From ${selectedItem.fromNode.label}/${selectedItem.fromNode.id}');
		ImGui.text('In file ${selectedItem.file}');
		ImGui.text('With runner ${selectedItem.runnerId}, Depth ${selectedItem.depth}');
		ImGui.text('');
		ImGui.text('Called from ${selectedItem.pos.fileName}');
		ImGui.text('${selectedItem.pos.className}::${selectedItem.pos.methodName}():${selectedItem.pos.lineNumber}');


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

			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.5, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}


}

#end