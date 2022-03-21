package cerastes.tools;

import cerastes.tools.ImguiTools.ComboFilterState;
import haxe.Constraints;
import cerastes.tools.ImguiTools.IG;
import imgui.NodeEditor;
import cerastes.tools.ImguiTools.ImVec2Impl;
import imgui.ImGui;

@:enum abstract NodeKind(Int) from Int to Int {
	var Blueprint = 0;
	var Comment = 1;
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

	public var label(get, never): String;

	function get_label()
	{
		return def.name;
	}

	function get_def()
	{
		return null;
	}

	function init( n: ImGuiNodes )
	{
		//Utils.assert( id > 0, "Double init on node" );

		id = n.getNextId();
		pins = [];
		editorData = {};

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

	inline function getPinDefForPort( portId: Int )
	{
		return def.pins[portId];
	}

	function getDefaultInputPinId(): PinId
	{
		for( portId => pinId in pins )
		{
			var pdef = getPinDefForPort( portId );
			if( pdef.kind == Input )
				return pinId;
		}

		return -1;
	}

	var size(get, never): ImVec2;

	function get_size()
	{
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

	var queryPinId: PinId;

	var style: Style = null;

	var registeredNodes: Map<String, Class<Node>> = [];

	var lastPos: ImVec2 = {x: 0.0, y:0.0};

	var iconWidth: Float = 0;

	public function new()
	{
		editor = NodeEditor.createEditor();
	}

	public function registerNode(name: String, cls: Class<Node>)
	{
		registeredNodes.set(name, cls);
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
		node.editorData.x = x;
		node.editorData.y = y;
		nodes.push( node );
	}

	public function render()
	{
		if( iconWidth == 0 )
		{
			var size: ImVec2 = ImGui.calcTextSize("\uf04e");
			iconWidth = size.x;
		}

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
			case Comment:
				renderCommentNode(node);
			default:
				Utils.assert(false, 'Unknown node kind ${node.def.kind}');
		}


		if( node.editorData.firstRender )
		{
			node.editorData.firstRender = false;

			NodeEditor.setNodePosition( node.id, {x: node.editorData.x, y: node.editorData.y } );

			//if( node.id == 1 )
			//	NodeEditor.centerNodeOnScreen( node.id );
		}

	}

	function renderCommentNode( node: Node )
	{

		var commentAlpha = 0.75;

		ImGui.pushStyleVar(ImGuiStyleVar.Alpha, commentAlpha);
		NodeEditor.pushStyleColor(StyleColor.NodeBg, {x: 255, y: 255, z: 255, w: 0.1});
		NodeEditor.pushStyleColor(StyleColor.NodeBorder, {x: 255, y: 255, z: 255, w: 0.3});
		NodeEditor.beginNode(node.id);
		ImGui.pushID( '${node.id}' );


		ImGui.text(node.label);

		NodeEditor.group({x:100, y:100});

		ImGui.popID();
		NodeEditor.endNode();
		NodeEditor.popStyleColor(2);
		ImGui.popStyleVar();

		if (NodeEditor.beginGroupHint(node.id))
		{
			//auto alpha   = static_cast<int>(commentAlpha * ImGui::GetStyle().Alpha * 255);
			var bgAlpha = 0.3;


			var min: ImVec2 = NodeEditor.getGroupMin();
			//auto max = ed::GetGroupMax();

			//min.x -= 8;
			min.y -= ImGui.getTextLineHeightWithSpacing() + 4;
			ImGui.setCursorScreenPos(min );// - ImVec2(-8, ImGui::GetTextLineHeightWithSpacing() + 4));
			ImGui.beginGroup();
			ImGui.text(node.label);
			ImGui.endGroup();

			var drawList = NodeEditor.getHintBackgroundDrawList();

			var itemMin = ImGui.getItemRectMin();
			var itemMax = ImGui.getItemRectMax();

			var padX = 8;
			var padY = 4;



			drawList.addRectFilled(
				{x: itemMin.x - padX, y: itemMin.y - padY },
				{x: itemMax.x + padX, y: itemMax.y + padY },
				0x44FFFFFF, 4.0, ImDrawFlags.RoundCornersAll);

			drawList.addRect(
				{x: itemMin.x - padX, y: itemMin.y - padY },
				{x: itemMax.x + padX, y: itemMax.y + padY },
				0x88FFFFFF, 4.0, ImDrawFlags.RoundCornersAll);

			//ImGui.popStyleVar();
		}
		NodeEditor.endGroupHint();
	}

	function renderBlueprintNode( node: Node )
	{

		var tile = hxd.Res.tools.BlueprintBackground.toTile();
		var width = node.def.width > 0 ? node.def.width : 200;
		var titleSize: ImVec2 = ImGui.calcTextSize(node.label);

		NodeEditor.beginNode( node.id );
		ImGui.pushID( '${node.id}' );


		var headerStart: ImVec2 = ImGui.getCursorPos();

		headerStart.x -= style.NodePadding.x;
		headerStart.y -= style.NodePadding.y;

		ImGui.text( node.label );

		var headerEnd: ImVec2 = ImGui.getCursorPos();
		headerEnd.x = headerStart.x + width  + style.NodePadding.z;

		var pinStart: ImVec2 = {x: headerStart.x, y: headerEnd.y + style.NodeBorderWidth * 8};

		//ImGui.setCursorPos( pinStart );
		ImGui.setCursorPosY( pinStart.y );


		for( portId => pinId in node.pins )
		{
			var def = node.def.pins[portId];
			if( def.kind == Input )
			{
				NodeEditor.beginPin(pinId, PinKind.Input );
				NodeEditor.pinPivotAlignment({x:0.0,y:0.5});
				ImGui.text( def.label );
				NodeEditor.endPin();
			}
		}

		var height =  ImGui.getCursorPosY() - pinStart.y;
		ImGui.setCursorPos( pinStart );


		for( portId => pinId in node.pins )
		{
			var def = node.def.pins[portId];
			if( def.kind == Output )
			{
				var size: ImVec2 = ImGui.calcTextSize(def.label);
				var posX: Int = cast (pinStart.x + width -  size.x  );
				ImGui.setCursorPosX( posX );

				NodeEditor.beginPin(pinId, PinKind.Output );
				NodeEditor.pinPivotAlignment({x:1.0,y:0.5});
				ImGui.text( def.label );
				NodeEditor.endPin();
			}
		}

		var height2 =  ImGui.getCursorPosY() - pinStart.y;
		var height = height > height2 ? height : height2;

		ImGui.setCursorPos( pinStart );

		ImGui.dummy({x: width, y: height});

		ImGui.popID();
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

			if( NodeEditor.queryNewNode( inputRef ) )
			{

				var inputNode = queryPin( inputPinId );
				var inputPinDef = inputNode.getPinDefForPin(inputPinId);

				var isValid = inputPinDef.kind == Output;

				if( isValid && NodeEditor.acceptNewItem() )
				{
					queryPinId = inputPinId;

					var pos: ImVec2 = ImGui.getMousePos();
					lastPos.x = pos.x;
					lastPos.y = pos.y;



					NodeEditor.suspend();
					ImGui.openPopup("link_drop_rc");
					NodeEditor.resume();

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



		if( IG.wref( NodeEditor.showNodeContextMenu( _ ), contextNodeId ) )
		{
			NodeEditor.suspend();
			ImGui.openPopup("node_rc");
			NodeEditor.resume();
		}

		if( IG.wref( NodeEditor.showLinkContextMenu( _ ), contextLinkId ) )
		{
			NodeEditor.suspend();
			ImGui.openPopup("link_rc");
			NodeEditor.resume();
		}

		if( IG.wref( NodeEditor.showPinContextMenu( _ ), contextPinId ) )
		{
			NodeEditor.suspend();
			ImGui.openPopup("pin_rc");
			NodeEditor.resume();
		}


		popups();


	}

	var state: ComboFilterState = {};
	var text = "";

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

		var flags = ImGuiWindowFlags.AlwaysAutoResize;

		if( ImGui.beginPopup("link_drop_rc", flags) )
		{
			var ref: hl.Ref<String> = text;

			var hints = [ for( k => v in registeredNodes ) k ];


			ImGui.setKeyboardFocusHere();
			if( IG.comboFilter("##nodeInput",ref,hints, state)  )
			{
				var t = registeredNodes.get( ref.get() );
				if( t != null )
				{
					var n = Type.createEmptyInstance(t);

					var pos:ImVec2 = NodeEditor.screenToCanvas(lastPos);

					addNode( n, pos.x, pos.y );

					var targetPinId = n.getDefaultInputPinId();
					if( targetPinId != -1 )
					{
						links.push({
							id: getNextId(),
							sourceId: queryPinId,
							destId: targetPinId,
						});
					}

					ImGui.closeCurrentPopup();
					ref.set("");
					state = {};
				}
			}


			text = ref.get();

			ImGui.endPopup();
		}
	}

	public function getSelectedNodes()
	{
		var nodeIds: hl.NativeArray<NodeId> = NodeEditor.getSelectedNodes();
		var out = [];
		for( nodeId in nodeIds )
		{
			for( n in nodes )
				if( n.id == nodeId )
					out.push( n );
		}

		return out;

	}

	public function getSelectedNode() : Node
	{
		var nodeIds: hl.NativeArray<NodeId> = NodeEditor.getSelectedNodes();
		if( nodeIds.length != 1 )
			return null;

		for( nodeId in nodeIds )
		{
			for( n in nodes )
				if( n.id == nodeId )
					return n;
		}

		return null;
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