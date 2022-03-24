package cerastes.data;


import haxe.Constraints;
#if hlimgui
import cerastes.tools.ImGuiNodes;
import imgui.NodeEditor;
import cerastes.tools.ImguiTools.ImVec2Impl;
import imgui.ImGui;
#else
typedef NodeId = Int;
typedef PinId = Int;
typedef LinkId = Int;
#end


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
	#if hlimgui
	public var id: PortId;
	public var kind: PinKind;
	public var dataType: PinDataType;
	public var label: String;
	public var color: ImU32 = 0xFFDEDEDE;
	#end
}

@:structInit class NodeDefinition
{
	#if hlimgui
	public var name: String;
	public var kind: NodeKind;
	public var pins: Array<NodePinDefinition>;
	public var width: Float = 0; // Override normal blueprint dimensions
	public var color: ImU32 = 0xFF228822; // Color for header
	#end
}

@:structInit class EditorData
{
	public var x: Float = 0;
	public var y: Float = 0;
	@noSerialize
	public var hasRendered = false;
}

@:keepSub
@:allow(cerastes.tools.ImGuiNodes)
@:structInit class Node
{

	public var id: NodeId = -1;
	public var pins: Map<PortId,PinId> = [];
	#if hlimgui
	var def(get, never): NodeDefinition;
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
	#end
}



@:structInit class Link
{
	public var id: LinkId;
	public var sourceId: PinId;
	public var destId: PinId;
	#if hlimgui
	public var color: ImVec4 = null;
	public var thickness: Float = 0;
	#end
}


@:structInit class NodeFile
{
	public var nodes: Array<Node> = [];
	public var links: Array<Link> = [];
	public var version: Int = 1;
}
