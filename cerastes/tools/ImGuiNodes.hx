package cerastes.tools;

import hxd.Key;
import cerastes.c2d.Vec2;
import haxe.ds.ArraySort;
import cerastes.flow.Flow.FlowComment;
#if hlimgui
import cerastes.tools.ImguiTool.ImGuiToolManager;
import imgui.Markdown;
import cerastes.data.Nodes;
import cerastes.data.Nodes;
import haxe.Constraints;
import cerastes.tools.ImguiTools.ComboFilterState;
import cerastes.tools.ImguiTools.IG;
import imgui.NodeEditor;
import imgui.ImGui;
using imgui.ImGui.ImGuiKeyStringExtender;

import imgui.ImGuiMacro.wref;

@:structInit class ConnectionQueryResult
{
	public var node: Node;
	public var pin: PinId;
}

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


@:allow(cerastes.data.Node)
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

	public var onContext: ( nodeId: NodeId32, pinId: PinId32, linkId: LinkId32 ) -> Void = null;
	public var createLink: (sourceId: PinId32, destId: PinId32, id: Int) -> Link = (sourceId: PinId32, destId: PinId32, id: Int) -> { var l: Link = { sourceId: sourceId, destId: destId, id: id }; return l; };

	public var shouldNavigateToContent = false;
	public var canSuspend = false;

	var firstRender = true;
	var active = false;

	var selectedNodes: Array<Node>;
	var selectedObjectCount: Int;

	public function new()
	{
		editor = NodeEditor.createEditor();
	}

	public function regenerateData()
	{
		for( l in links )
		{
			var startPinId32 = l.sourceId;
			var startNode = queryPin( startPinId32 );
			if( startNode != null )
			{

				var startPinDef = startNode.getPinDefForPin(startPinId32);

				if( startPinDef.color != 0 )
					l.color = IG.colorToImVec4( startPinDef.color );
			}

		}
	}

	public function registerNode(name: String, cls: Class<Node>)
	{
		registeredNodes.set(name, cls);
	}

	function getNextId()
	{
		do
		{
			nextId++;
		}
		while( !isIdFree(nextId) );

		return nextId;
	}

	function isIdFree( id: Int )
	{
		for( n in nodes )
		{
			if( n.id == nextId )
				return false;
			for( portId => pinId in n.pins )
				if( pinId == id )
					return false;
		}

		for( link in links )
			if( link.id == id )
				return false;

		return true;
	}


	function idExists(id: NodeId32  )
	{
		for( n in nodes )
			if( n.id == id)
				return true;

		return false;
	}

	function queryPin( pinId: PinId32 ) : Node
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



	function queryConnections( pinId: PinId32 ) : Array<ConnectionQueryResult>
	{
		var out = [];
		// Find the links
		for( l in links )
		{
			var otherId = -1;
			if( l.sourceId == pinId )
				otherId = l.destId;
			else if( l.destId == pinId )
				otherId = l.sourceId;

			if( otherId != -1 )
			{

				var otherNode = queryPin( otherId );
				var r: ConnectionQueryResult = {
					node: otherNode,
					pin: otherId
				};
				out.push(r);
			}
		}

		return out;
	}

	public function addNode(node: Node, x: Float, y: Float)
	{
		node.init(this);
		#if tools
		node.editorData.x = x;
		node.editorData.y = y;
		#end
		nodes.push( node );
	}

	public function render()
	{
		// HACK: Do not do shit while minimized, it breaks the world.
		if( hxd.Window.getInstance().width == 0 || hxd.Window.getInstance().height == 0 )
			return false;


		var size = ImGui.getContentRegionAvail();
		if( size.x == 0 || size.y == 0  )
			return false;


		NodeEditor.setCurrentEditor( editor );
		active = true;

		if( style == null )
			style = NodeEditor.getStyle();

		style.NodeRounding = 0;


		NodeEditor.begin("test", size);

		if( iconWidth == 0 )
		{
			var size: ImVec2 = ImGui.calcTextSize("\uf04e");
			iconWidth = size.x;
		}


		for( node in nodes )
		{
			renderNode( node );
		}

		for( link in links )
		{
			NodeEditor.link( link.id, link.sourceId, link.destId, link.color, link.thickness );
		}

		handleEvents();

		selectedNodes = getSelectedNodes();
		selectedObjectCount = NodeEditor.getSelectedObjectCount();

		active = false;
		NodeEditor.end();

		if(firstRender )
			firstRender = false;


		canSuspend = true;
		return true;
	}

	function getNode(nodeId: NodeId32 )
	{
		for( n in nodes )
		{
			if( n.id == nodeId )
				return n;
		}

		return null;
	}

	function renderNode( node: Node )
	{

		node.onBeforeEditor( this );

		switch( node.def.kind )
		{
			case Blueprint:
				renderBlueprintNode(node);
			case Comment:
				renderCommentNode(node);
			case Micro:
				renderMicroNode(node);
			case Note:
				renderNoteNode(node);
			default:
				Utils.assert(false, 'Unknown node kind ${node.def.kind}');
		}

		if( ImGui.isItemHovered() )
		{
			var contents = node.onTooltip( this );
			if( contents != null && contents.length > 0 )
			{
				var style = ImGui.getStyle();
				NodeEditor.suspend();
				var size = ImGui.calcTextSize( contents);
				size.x += style.WindowPadding.x * 2;
				size.y += style.WindowPadding.y * 2;
				ImGui.setNextWindowSizeConstraints( size, { x: size.x * 2, y: size.y * 2 } );

				ImGui.beginTooltip();
				Markdown.text( contents, ImGuiToolManager.markdownConfig );
				ImGui.endTooltip();

				NodeEditor.resume();
			}
		}


		if( !node.editorData.hasRendered )
		{
			node.editorData.hasRendered = true;

			NodeEditor.setNodePosition( node.id, {x: node.editorData.x, y: node.editorData.y } );

			if( node.def.kind == Comment )
			{
				NodeEditor.setGroupSize( node.id, node.size );
			}

			//if( node.id == 1 )
			//	NodeEditor.centerNodeOnScreen( node.id );
		}
		else
		{
			var pos: ImVec2 = NodeEditor.getNodePosition(node.id );
			node.editorData.x = pos.x;
			node.editorData.y = pos.y;
		}

		if( shouldNavigateToContent )
		{
			//NodeEditor.navigateToContent();
			//shouldNavigateToContent = false;
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

		NodeEditor.group(node.size);

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
				0x44FFFFFF, style.GroupRounding, ImDrawFlags.RoundCornersAll);

			drawList.addRect(
				{x: itemMin.x - padX, y: itemMin.y - padY },
				{x: itemMax.x + padX, y: itemMax.y + padY },
				0x88FFFFFF, style.GroupRounding, ImDrawFlags.RoundCornersAll);

			//ImGui.popStyleVar();

			//var min: ImVec2 = NodeEditor.getGroupMin();
			//var max: ImVec2 = NodeEditor.getGroupMax();
			//var size: ImVec2 = {x: max.x - min.x, y: max.y - min.y};

			var c = Std.downcast( node, FlowComment);

			var size: ImVec2 = NodeEditor.getNodeSize( c.id );


			if( size.x > 0 && size.y > 16)
				node.setSize( size );


		}



		NodeEditor.endGroupHint();
	}

	function renderBlueprintNode( node: Node )
	{

		var tile = hxd.Res.tools.BlueprintBackground.toTile();
		var width = node.width;
		var titleSize: ImVec2 = ImGui.calcTextSize(node.label);

		NodeEditor.beginNode( node.id );
		ImGui.pushID( '${node.id}' );


		var headerStart: ImVec2 = ImGui.getCursorPos();
		var headerStartS: ImVec2S = { x: headerStart.x, y: headerStart.y };

		headerStart.x -= style.NodePadding.x;
		headerStart.y -= style.NodePadding.y;

		ImGui.text( node.label );
		if( node.labelInfo != null )
		{
			ImGui.sameLine();
			ImGui.textColored( IG.colorToImVec4(0xFF888888 ), node.labelInfo );
		}

		var headerEnd: ImVec2 = ImGui.getCursorPos();
		headerEnd.x = headerStart.x + width  + style.NodePadding.z;
		var headerEndS: ImVec2S = { x: headerEnd.x, y: headerEnd.y };

		ImGui.setCursorPosY( headerEnd.y + style.NodeBorderWidth * 8 );

		node.render();

		var pinStart: ImVec2 = {x: headerStart.x, y: ImGui.getCursorPosY()};

		//ImGui.setCursorPos( pinStart );
		ImGui.setCursorPosY( pinStart.y );

		var ports = [ for (k in node.pins.keys()) k ];
		ports.sort( Reflect.compare );


		for( portId in ports )
		{
			var pinId: Int = node.pins[portId];
			var def = node.getPinDefForPort(portId);
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


		for( portId in ports )
		{
			var pinId: Int = node.pins[portId] == null ? 0 : node.pins[portId];
			var def = node.getPinDefForPort(portId);
			if( def.kind == Output )
			{
				var size: ImVec2 = ImGui.calcTextSize(def.label);
				var posX: Int = cast (pinStart.x + width -  size.x  );
				ImGui.setCursorPosX( posX );

				NodeEditor.beginPin(pinId, PinKind.Output );
				NodeEditor.pinPivotAlignment({x:1.0,y:0.5});
				if( def.color != 0 )
					ImGui.textColored( IG.colorToImVec4( def.color ), def.label );
				else
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


	function renderMicroNode( node: Node )
	{
		var width = node.width;

		NodeEditor.beginNode( node.id );
		ImGui.pushID( '${node.id}' );


		node.render();

		var pinStart: ImVec2 = ImGui.getCursorPos();


		for( portId => pinId in node.pins )
		{
			var def = node.getPinDefForPort(portId);
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
			var def = node.getPinDefForPort(portId);
			if( def.kind == Output )
			{
				var size: ImVec2 = ImGui.calcTextSize(def.label);
				var posX: Int = cast (pinStart.x + width -  size.x  );
				ImGui.setCursorPosX( posX );

				NodeEditor.beginPin(pinId, PinKind.Output );
				NodeEditor.pinPivotAlignment({x:1.0,y:0.5});
				if( def.color != 0 )
					ImGui.textColored( IG.colorToImVec4( def.color ), def.label );
				else
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
	}

	function renderNoteNode( node: Node )
	{
		var size = node.size;

		NodeEditor.beginNode( node.id );
		ImGui.pushID( '${node.id}' );


		node.render();



		//ImGui.dummy(size);

		ImGui.popID();
		NodeEditor.endNode();
	}

	function findNode( nodeId: NodeId32 )
	{
		for( n in nodes )
		{
			if( n.id == nodeId )
				return n;
		}

		return null;
	}

	function findLink( linkId: LinkId32 )
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


			var startPinId: PinId = -1;
			var endPinId: PinId = -1;


			var startRef = hl.Ref.make(startPinId);
			var endRef = hl.Ref.make(endPinId);

			if( NodeEditor.queryNewLink( startRef, endRef ) )
			{
				var isValid = true;

				var startNode = queryPin( startPinId );
				var endNode = queryPin( endPinId );

				var startPinDef = startNode.getPinDefForPin(startPinId);
				var endPinDef = endNode.getPinDefForPin(endPinId);

				if( startPinDef.kind == endPinDef.kind )
					isValid = false;

				// @todo: Need to special case bool/int conversions
				if( startPinDef.dataType != endPinDef.dataType )
					isValid = false;


				if( isValid )
				{
					showLabel('+ Create Link: ${startNode.id} -> ${endNode.id}', 0x55202d20 );
					var accept = false;
					if( startPinDef.color != 0 )
						accept = NodeEditor.acceptNewItem2( IG.colorToImVec4( startPinDef.color ) );
					else
						accept = NodeEditor.acceptNewItem();


					if( accept )
					{
						var link = createLink(startPinId, endPinId, getNextId());
						links.push( link );
						if( startPinDef.color != 0 )
							link.color = IG.colorToImVec4( startPinDef.color );


					}
				}
				else
				{
					if( startPinDef != null && startPinDef.color != 0 )
						NodeEditor.rejectNewItem2( IG.colorToImVec4( startPinDef.color ) );
					else
						NodeEditor.rejectNewItem2();
				}
			}

			if( NodeEditor.queryNewNode( startRef ) )
			{
				var startNode = queryPin( startPinId );
				var startPinDef = startNode.getPinDefForPin(startPinId);

				var isValid = startPinDef.kind == Output;

				if( isValid && NodeEditor.acceptNewItem() )
				{
					queryPinId = startPinId;

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
			while( wref( NodeEditor.queryDeletedNode( _ ), nodeId ) )
			{
				var node = findNode(nodeId);

				if( !Utils.verify( node != null, 'Unknown nodeID ${nodeId} marked as deleted!') )
					continue;

				nodes.remove( node );
				NodeEditor.acceptDeletedItem();

			}

			while( wref( NodeEditor.queryDeletedLink( _, _, _ ), linkId, pinStartId, pinEndId ) )
			{
				var link = findLink(linkId);

				if( !Utils.verify( link != null, 'Unknown linkID ${linkId} marked as deleted!') )
					continue;

				links.remove( link );
				NodeEditor.acceptDeletedItem();

			}
		}

		NodeEditor.endDelete();


		if( canSuspend )
		{
			NodeEditor.suspend();
			if( wref( NodeEditor.showNodeContextMenu( _ ), contextNodeId ) )
			{
				//NodeEditor.suspend();
				ImGui.openPopup("node_rc");
				//NodeEditor.resume();
			}

			if( wref( NodeEditor.showLinkContextMenu( _ ), contextLinkId ) )
			{
				//NodeEditor.suspend();
				ImGui.openPopup("link_rc");
				//NodeEditor.resume();
			}

			if( wref( NodeEditor.showPinContextMenu( _ ), contextPinId ) )
			{
				//NodeEditor.suspend();
				ImGui.openPopup("pin_rc");
				//NodeEditor.resume();
			}

			if( NodeEditor.showBackgroundContextMenu() )
			{
				//NodeEditor.suspend();
				queryPinId = -1;

				var pos: ImVec2 = ImGui.getMousePos();
				lastPos.x = pos.x;
				lastPos.y = pos.y;

				ImGui.openPopup("link_drop_rc");
				//NodeEditor.resume();
			}



			NodeEditor.resume();
		}

		//Handle node movement



		// Hover specifically deals with a single drag, which may not select.
		var nodeId = NodeEditor.getHoveredNode();
		if( nodeId > 0 )
		{
			var node = getNode(nodeId);
			if( node != null )
			{
				var pos: ImVec2 = NodeEditor.getNodePosition(nodeId );
				node.editorData.x = pos.x;
				node.editorData.y = pos.y;

				if( node.kind == Comment )
				{
					var size: ImVec2 = NodeEditor.getNodeSize( nodeId );
					node.setSize( size );
				}
			}
		}




		if( canSuspend )
		{
			NodeEditor.suspend();
			popups();
			// Shortcuts
			if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) )
			{
				var io = ImGui.getIO();
				if( io.KeyCtrl && ImGui.isKeyPressed( 'C'.imKey() ) )
					copy();
				//if( Key.isDown( Key.CTRL ) && Key.isPressed( Key.X )  )
				//	cut();
				if( io.KeyCtrl && ImGui.isKeyPressed( 'V'.imKey() ) )
					paste();
			}
			NodeEditor.resume();
		}


	}

	var copyBuffer: Array<Node> = null;


	function copy()
	{
		copyBuffer = getSelectedNodes().copy();
	}

	public static function copyNode<T>(c:T):T
	{
		var cls:Class<T> = Type.getClass(c);
		var inst:T = Type.createEmptyInstance(cls);
		var fields = Type.getInstanceFields(cls);
		for (field in fields)
		{
			var val:Dynamic = Reflect.field(c,field);
			if ( ! Reflect.isFunction(val) )
			{
				// @todo: this is shallow, may need to be deep?
				if( Std.isOfType( val, Array ) )
				{
					var array: Array<Any> = cast val;
					val = array.copy();
				}
				if( Std.isOfType( val, haxe.ds.StringMap ) )
				{
					var map: haxe.ds.StringMap<Any> = cast val;
					val = map.copy();
				}
				if( Std.isOfType( val, haxe.ds.IntMap ) )
				{
					var map: haxe.ds.IntMap<Any> = cast val;
					val = map.copy();
				}

				Reflect.setField(inst,field,val);
			}
		}
		return inst;
	}

	function paste()
	{
		if( copyBuffer == null )
			return;

		var copyIds = copyBuffer.map( (n: Node ) -> return n.id );

		// First, find the most upper right node as a starting point
		var offset: Vec2 = { x: CMath.T_FLOAT_MAX, y: CMath.T_FLOAT_MAX };
		for( n in copyBuffer )
		{
			if( n.editorData.y < offset.y || ( Math.round( n.editorData.y ) ==  Math.round( offset.y ) && n.editorData.x < offset.x ) )
			{
				offset.x = n.editorData.x;
				offset.y = n.editorData.y;
			}
		}

		var pos = NodeEditor.screenToCanvas(ImGui.getMousePos());
		// @bugbug
		var posVec: Vec2 = {x: pos.x, y: pos.y};

		var idMap: Map<PinId32, PinId32> = [];

		for( n in copyBuffer )
		{
			var newNode = copyNode(n);
			var newPos: Vec2 = {x: n.editorData.x, y: n.editorData.y };
			newPos = posVec + ( newPos - offset );
			addNode(newNode, newPos.x, newPos.y);

			for( k => v in n.pins )
				idMap.set(n.pins[k], newNode.pins[k]);
		}

		// Now process links between pasted nodes.
		for( link in links )
		{
			var srcNode = queryPin( link.sourceId );
			var dstNode =  queryPin( link.destId );
			if( srcNode == null || dstNode == null )
				continue;

			var srcId = srcNode.id;
			var dstId = dstNode.id;

			if( copyIds.indexOf(srcId ) != -1 && copyIds.indexOf( dstId ) != -1 )
			{
				var newLink = createLink( idMap[link.sourceId], idMap[link.destId], getNextId());

				var startNode = srcNode;

				var startPinDef = startNode.getPinDefForPin(link.sourceId);

				if( startPinDef.color != 0 )
					newLink.color = IG.colorToImVec4( startPinDef.color );

				links.push(newLink);
			}
		}


	}

	var state: ComboFilterState = {};
	var text = "";

	function popups()
	{
		if( ImGui.beginPopup("node_rc") )
		{
			if( onContext != null )
				onContext( contextNodeId, 0, 0 );

			if( ImGui.menuItem( 'Delete Node') )
			{
				var ret = NodeEditor.deleteNode( contextNodeId );
				Utils.info('Delete ${contextNodeId} -> ${ret}');
			}

			ImGui.endPopup();
		}

		if( ImGui.beginPopup("link_rc") )
		{
			if( onContext != null )
				onContext( 0, 0, contextLinkId );

			if( ImGui.menuItem( 'Delete Link') )
			{
				var ret = NodeEditor.deleteLink( contextLinkId );
				Utils.info('Delete ${contextLinkId} -> ${ret}');
			}

			ImGui.endPopup();
		}

		if( ImGui.beginPopup("pin_rc") )
		{
			//if( onContext != null )
			//	onContext( 0, contextPinId32, 0  );

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
			var hints = [ for( k => v in registeredNodes ) k ];

			if( ImGui.isWindowAppearing() )
				ImGui.setKeyboardFocusHere();

			var ret = IG.comboFilter("##nodeInput",hints, state) ;
			if( ret != null )
			{
				var t = registeredNodes.get( ret );
				if( t != null )
				{
					var n = Type.createEmptyInstance(t);

					var pos:ImVec2 = NodeEditor.screenToCanvas(lastPos);

					addNode( n, pos.x, pos.y );

					var targetPinId32 = n.getDefaultInputPinId32();
					if( targetPinId32 != -1 && queryPinId != cast -1 )
					{
						var link = createLink(queryPinId, targetPinId32, getNextId());

						var startNode = queryPin( queryPinId );

						var startPinDef = startNode.getPinDefForPin(queryPinId);

						if( startPinDef.color != 0 )
							link.color = IG.colorToImVec4( startPinDef.color );

						links.push(link);
					}

					ImGui.closeCurrentPopup();
					state = {};
				}
			}

			ImGui.endPopup();
		}
	}

	public function getSelectedNodes()
	{
		if( !active )
			return selectedNodes;

		var nodeIds: hl.NativeArray<NodeId> = NodeEditor.getSelectedNodes();
		var out = [];

		if( firstRender )
			return out;

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
		if( firstRender )
			return null;

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

	public function getSelectedLink() : Link
	{
		if( firstRender )
			return null;

		var linkIds: hl.NativeArray<LinkId> = NodeEditor.getSelectedLinks();
		if( linkIds.length != 1 )
			return null;

		for( linkId in linkIds )
		{
			for( l in links )
				if( l.id == linkId )
					return l;
		}

		return null;
	}

	function showLabel(label: String, color: ImU32)
	{
		ImGui.setCursorPosY(ImGui.getCursorPosY() - ImGui.getTextLineHeight() );
		var size = ImGui.calcTextSize(label);

		var style = ImGui.getStyle();

		var padding: ImVec2 = style != null ? {x: style.FramePadding.x, y: style.FramePadding.y } : {x: 2, y: 2};
		var spacing: ImVec2 = style != null ? {x: style.ItemSpacing.x, y: style.ItemSpacing.y } : {x: 2, y: 2};

		var cursorPos: ImVec2 = ImGui.getCursorPos();
		ImGui.setCursorPos({x: cursorPos.x + spacing.x, y: cursorPos.y - spacing.y });

		var screenPos: ImVec2 = ImGui.getCursorScreenPos();

		var rectMin: ImVec2 = {x: screenPos.x - padding.x, y: screenPos.y - padding.y };
		var rectMax: ImVec2 = {x: screenPos.x + size.x + padding.x, y: screenPos.y + size.y + padding.y };

		var rectMinS: ImVec2S = {x: rectMin.x, y: rectMin.y}
		var rectMaxS: ImVec2S = {x: rectMax.x, y: rectMax.y}


		var drawList = ImGui.getWindowDrawList();
		drawList.addRectFilled(rectMinS, rectMaxS, color, size.y * 0.15);
		ImGui.text(label);
	};
}

#end