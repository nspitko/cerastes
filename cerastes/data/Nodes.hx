package cerastes.data;

import hxd.clipper.Clipper.NodeType;
import haxe.Constraints;
#if hlimgui
import cerastes.tools.ImGuiNodes;
import imgui.NodeEditor;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import hl.UI;
#end

#if hlimgui
abstract NodeId32(Int) from NodeId to NodeId {}
abstract PinId32(Int) from PinId to PinId {}
abstract LinkId32(Int) from LinkId to LinkId {}
#else
abstract NodeId32(Int) from Int to Int {}
abstract PinId32(Int) from Int to Int {}
abstract LinkId32(Int) from Int to Int {}
#end

@:enum abstract NodeKind(Int) from Int to Int {
	var Blueprint = 0;
	var Comment = 1;
	var Micro = 2;
	var Note = 3;
}

typedef PortId = Int;

@:enum abstract PinDataType(Int) from Int to Int {
	var Node 		= 0;	// Accepts an entire node as its input (Typically for logic flow)
	var Numeric 	= 1;	// Accepts numeric values (int/float)
	var Bool 		= 2;	// Accepts bool and numerics (where number > 0)
	var Text		= 3;	// Accepts a string as its input
	var Texture		= 4;	// Textures
}

@:keep
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

@:keep
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

@:keep
@:structInit class EditorData
{
	#if tools
	public var x: Float = 0;
	public var y: Float = 0;
	@noSerialize
	public var hasRendered = false;
	#end
}

@:keepSub
@:allow(cerastes.tools.ImGuiNodes)
@:structInit class Node
{
	public var id: NodeId32 = -1;
	@serializeType("haxe.ds.IntMap")
	public var pins: Map<PortId,PinId32> = [];
	#if tools
	@serializeType("cerastes.data.EditorData")
	public var editorData: EditorData = {};
	#end
	#if hlimgui
	var def(get, never): NodeDefinition;
	public var label(get, never): String;
	public var labelInfo(get, never): String;
	public var width(get, never): Float;
	public var kind(get, never): NodeKind;

	function onBeforeEditor( editor: ImGuiNodes )
	{

	}

	function get_label()
	{
		return def.name;
	}

	function get_labelInfo()
	{
		return null;
	}

	function get_width()
	{
		if( def.width > 0 )
			return def.width;

		return 200;
	}

	function get_kind()
	{
		return def.kind;
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

	function getPinDefForPin( pinId: PinId32 )
	{
		for( portId => otherPinId32 in pins )
		{
			if( pinId == otherPinId32 )
				return getPinDefForPort( portId );
		}

		return null;
	}

	function getPinDefForPort( portId: Int )
	{
		return def.pins[portId];
	}

	function getDefaultInputPinId32(): PinId32
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

	// https://github.com/HaxeFoundation/haxe/issues/10652
	function setSize( newSize: ImVec2 )
	{

	}

	function render()
	{

	}
	#end
}



@:structInit class Link
{
	public var id: LinkId32;
	public var sourceId: PinId32;
	public var destId: PinId32;
	#if hlimgui
	@noSerialize
	public var color: ImVec4 = null;
	@noSerialize
	public var thickness: Float = 0;
	#end
}


@:structInit class NodeFile
{
	public var nodes: Array<Node> = [];
	public var links: Array<Link> = [];
	public var version: Int = 1;
}
