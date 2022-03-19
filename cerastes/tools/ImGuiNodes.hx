package cerastes.tools;

import haxe.Constraints;
import cerastes.tools.ImguiTools.IG;
import imgui.NodeEditor;
import cerastes.tools.ImguiTools.ImVec2Impl;
import imgui.ImGui;

@:enum abstract NodeKind(Int) from Int to Int {
	var Blueprint = 0;
}

typedef PortId = Int;

@:enum abstract PinDataType(Int) from Int to Int {
	var Node 		= 0;	// Accepts an entire node as its input (Typically for logic flow)
	var Numeric 	= 1;	// Accepts numeric values (int/float)
	var Bool 		= 2;	// Accepts bool and numerics (where number > 0)
	var String		= 3;	// Accepts a string as its input
	var Texture		= 4;	// Textures
}

@:structInit class NodePinDefinition
{
	public var id: PortId;
	public var kind: PinKind;
	public var dataType: PinDataType;
	public var label: String;
	public var color: ImU32 = 0xFFDEDEDE;
}

@:structInit class NodeDefinition
{
	public var name: String;
	public var kind: NodeKind;
	public var pins: Array<NodePinDefinition>;
	public var width: Float = 0; // Override normal blueprint dimensions
	public var color: ImU32 = 0xFF228822; // Color for header
}

@:structInit class EditorData
{
	public var x: Float = 0;
	public var y: Float = 0;
	public var firstRender = true;
}

@:allow(cerastes.tools.ImGuiNodes)
@:structInit class Node
{
	var def(get, never): NodeDefinition;
	public var id: NodeId = -1;
	public var pins: Map<PortId,PinId> = [];
	public var editorData: EditorData = {};

	function get_def()
	{
		return null;
	}

	function init( n: ImGuiNodes )
	{
		Utils.assert( id == -1, "Double init on node" );

		id = n.getNextId();

		for( pin in def.pins )
		{
			pins.set(pin.id, n.getNextId());
		}
	}

	function getPinDefForPin( pinId: PinId )
	{
		for( portId => otherPinId in pins )
		{
			if( pinId == otherPinId )
				return def.pins[portId];
		}

		return null;
	}
}



@:structInit class Link
{
	public var id: LinkId;
	public var sourceId: PinId;
	public var destId: PinId;
	public var color: ImVec4 = null;
	public var thickness: Float = 0;
}


@:structInit class NodeFile
{
	public var nodes: Array<Node> = [];
	public var links: Array<Link> = [];
	public var version: Int = 1;
}

#if hlimgui

@:structInit
class TestNode extends Node
{
	static final d: NodeDefinition = {
		name:"Test Node",
		kind: Blueprint,
		color: 0xFF228822,
		pins: [
			{
				id: 0,
				kind: Input,
				label: "\uf04e Input",
				dataType: Node,
			},
			{
				id: 1,
				kind: Output,
				label: "Output \uf04b",
				dataType: Node
			},
			{
				id: 2,
				kind: Output,
				label: "Output 2 \uf04b",
				dataType: Node
			}
		]
	};

	override function get_def()
	{
		return d;
	}
}

@:allow(cerastes.tools.Node)
class ImGuiNodes
{

	var nextId = 1;

	public var nodes: Array<Node> = [];
	public var links: Array<Link> = [];

	var editor : EditorContext;

	var contextNodeId: NodeId;
	var contextPinId: PinId;
	var contextLinkId: LinkId;

	var style: Style = null;


	public function new()
	{
		editor = NodeEditor.createEditor();

		// TEST
		var t: TestNode = {};
		addNode(t, 0,0);
		var t: TestNode = {};
		addNode(t, 50,200);
	}

	function getNextId()
	{
		return nextId++;
	}

	function idExists(id: NodeId  )
	{
		for( n in nodes )
			if( n.id == id)
				return true;

		return false;
	}

	function queryPin( pinId: PinId ) : Node
	{
		for( node in nodes )
		{
			for( port => id in node.pins )
			{
				if( id == pinId )
				{
					return node;
				}
			}
		}
		return null;
	}

	public function addNode(node: Node, x: Float, y: Float)
	{
		node.init(this);
		nodes.push( node );
	}

	public function render()
	{
		NodeEditor.setCurrentEditor( editor );

		if( style == null )
			style = NodeEditor.getStyle();

		NodeEditor.begin("test");

		for( node in nodes )
		{
			renderNode( node );
		}

		for( link in links )
		{
			NodeEditor.link( link.id, link.sourceId, link.destId, link.color, link.thickness );
		}

		handleEvents();

		NodeEditor.end();
	}

	function renderNode( node: Node )
	{

		switch( node.def.kind )
		{
			case Blueprint:
				renderBlueprintNode(node);
			default:
				Utils.assert(false, 'Unknown node kind ${node.def.kind}');
		}


		if( node.editorData.firstRender )
		{
			node.editorData.firstRender = false;

			NodeEditor.setNodePosition( node.id, {x: node.editorData.x, y: node.editorData.y } );

			if( node.id == 1 )
				NodeEditor.centerNodeOnScreen( node.id );
		}

	}

	function renderBlueprintNode( node: Node )
	{

		var tile = hxd.Res.tools.BlueprintBackground.toTile();
		var width = node.def.width > 0 ? node.def.width : 200;
		var titleSize: ImVec2 = ImGui.calcTextSize(node.def.name);

		NodeEditor.beginNode( node.id );


		var headerStart: ImVec2 = ImGui.getCursorPos();

		headerStart.x -= style.NodePadding.x;
		headerStart.y -= style.NodePadding.y;

		ImGui.text( node.def.name );

		var headerEnd: ImVec2 = ImGui.getCursorPos();
		headerEnd.x = headerStart.x + width - style.NodeBorderWidth * 2;


		ImGui.beginTable("nodeTable", 2, ImGuiTableFlags.SizingFixedFit);

		ImGui.tableNextColumn();

		for( portId => pinId in node.pins )
		{
			var def = node.def.pins[portId];
			if( def.kind == Input )
			{
				NodeEditor.beginPin(pinId, PinKind.Input );
				ImGui.text( def.label );
				NodeEditor.endPin();
			}
		}

		ImGui.tableNextColumn();

		ImGui.dummy({x: width/2, y: 1});

		for( portId => pinId in node.pins )
		{
			var def = node.def.pins[portId];
			if( def.kind == Output )
			{
				var size: ImVec2 = ImGui.calcTextSize(def.label);
				var posX: Int = cast (ImGui.getCursorPosX() + ImGui.getColumnWidth() -  size.x  );
				ImGui.setCursorPosX( posX );

				NodeEditor.beginPin(pinId, PinKind.Output );
				ImGui.text( def.label );
				NodeEditor.endPin();
			}
		}

		ImGui.endTable();

		NodeEditor.endNode();

		var drawList: ImDrawList = NodeEditor.getNodeBackgroundDrawList( node.id );
		drawList.addImageRounded( tile.getTexture(), headerStart, headerEnd, {x: 0, y: 0}, {x:1, y:1}, node.def.color, style.NodeRounding, ImDrawFlags.RoundCornersTop );
		drawList.addLine( {x: headerStart.x + style.NodeBorderWidth - 1, y: headerEnd.y }, {x: headerEnd.x - style.NodeBorderWidth, y: headerEnd.y}, node.def.color, style.NodeBorderWidth / 2 );
	}

	function findNode( nodeId: NodeId )
	{
		for( n in nodes )
		{
			if( n.id == nodeId )
				return n;
		}

		return null;
	}

	function findLink( linkId: LinkId )
	{
		for( l in links )
		{
			if( l.id == linkId )
				return l;
		}

		return null;
	}

	function handleEvents()
	{
		if( NodeEditor.beginCreate() )
		{

			var outputPinId: PinId = -1;
			var inputPinId: PinId = -1;

			var inputRef = new hl.Ref(inputPinId);
			var outputRef = new hl.Ref(outputPinId);

			if( NodeEditor.queryNewLink( inputRef, outputRef ) )
			{
				var isValid = true;

				var inputNode = queryPin( inputPinId );
				var outputNode = queryPin( outputPinId );

				var inputPinDef = inputNode.getPinDefForPin(inputPinId);
				var outputPinDef = outputNode.getPinDefForPin(outputPinId);

				if( inputPinDef.kind == outputPinDef.kind )
					isValid = false;

				// @todo: Need to special case bool/int conversions
				if( inputPinDef.dataType != outputPinDef.dataType )
					isValid = false;


				if( isValid )
				{
					showLabel('+ Create Link: ${inputNode.id} -> ${outputNode.id}', 0x55202d20 );
					if( NodeEditor.acceptNewItem() )
					{
						links.push({
							id: getNextId(),
							sourceId: inputPinId,
							destId: outputPinId,
						});

					}
				}
			}
		}
		// Not a bug: Always endCreate even if beginCreate is false. (?)
		NodeEditor.endCreate();

		if( NodeEditor.beginDelete() )
		{

			var nodeId: NodeId = 0;
			var linkId: LinkId = 0;
			var pinStartId: PinId = 0;
			var pinEndId: PinId = 0;
			while( IG.wref( NodeEditor.queryDeletedNode( _ ), nodeId ) )
			{
				var node = findNode(nodeId);

				if( Utils.assert( node != null, "Unknown nodeID marked as deleted!") )
					continue;

				nodes.remove( node );
				NodeEditor.acceptDeletedItem();

			}

			while( IG.wref( NodeEditor.queryDeletedLink( _, _, _ ), linkId, pinStartId, pinEndId ) )
			{
				var link = findLink(linkId);

				if( Utils.assert( link != null, "Unknown nodeID marked as deleted!") )
					continue;

				links.remove( link );
				NodeEditor.acceptDeletedItem();

			}
		}

		NodeEditor.endDelete();

		NodeEditor.suspend();

		if( IG.wref( NodeEditor.showNodeContextMenu( _ ), contextNodeId ) )
		{
			ImGui.openPopup("node_rc");
		}

		if( IG.wref( NodeEditor.showLinkContextMenu( _ ), contextLinkId ) )
		{
			ImGui.openPopup("link_rc");
		}

		if( IG.wref( NodeEditor.showPinContextMenu( _ ), contextPinId ) )
		{
			ImGui.openPopup("pin_rc");
		}


		popups();

		NodeEditor.resume();
	}

	function popups()
	{
		if( ImGui.beginPopup("node_rc") )
		{
			if( ImGui.menuItem( 'Delete Node') )
			{
				trace('Delete ${contextNodeId}');
				trace( NodeEditor.deleteNode( contextNodeId ) );
			}

			ImGui.endPopup();
		}

		if( ImGui.beginPopup("link_rc") )
		{
			if( ImGui.menuItem( 'Delete Link') )
			{
				trace('Delete ${contextLinkId}');
				trace( NodeEditor.deleteLink( contextLinkId ) );
			}

			ImGui.endPopup();
		}

		if( ImGui.beginPopup("pin_rc") )
		{
			if( ImGui.menuItem( 'Disconnect All') )
			{

				for( l in links )
					if( l.sourceId == contextPinId || l.destId == contextPinId )
						NodeEditor.deleteLink( l.id );
			}

			ImGui.endPopup();
		}
	}

	function showLabel(label: String, color: ImU32)
	{
		ImGui.setCursorPosY(ImGui.getCursorPosY() - ImGui.getTextLineHeight() );
		var size = ImGui.calcTextSize(label);

		var style = ImGui.getStyle();

		var padding: ImVec2 = style != null ? style.FramePadding : {x: 2, y: 2};
		var spacing: ImVec2 = style != null ? style.ItemSpacing : {x: 2, y: 2};

		var cursorPos: ImVec2 = ImGui.getCursorPos();
		ImGui.setCursorPos({x: cursorPos.x + spacing.x, y: cursorPos.y - spacing.y });

		var screenPos: ImVec2 = ImGui.getCursorScreenPos();

		var rectMin: ImVec2 = {x: screenPos.x - padding.x, y: screenPos.y - padding.y };
		var rectMax: ImVec2 = {x: screenPos.x + size.x + padding.x, y: screenPos.y + size.y + padding.y };


		var drawList = ImGui.getWindowDrawList();
		drawList.addRectFilled(rectMin, rectMax, color, size.y * 0.15);
		ImGui.text(label);
	};
}

#end