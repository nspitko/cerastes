package cerastes.data;

import hxd.clipper.Clipper.NodeType;
import haxe.Constraints;
#if hlimgui
import cerastes.tools.ImGuiNodes;
import imgui.NodeEditor;
import cerastes.tools.ImguiTools.ImVec2Impl;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import hl.UI;
#else
typedef NodeId = Int;
typedef PinId = Int;
typedef LinkId = Int;
#end


@:enum abstract NodeKind(Int) from Int to Int {
	var Blueprint = 0;
	var Comment = 1;
	var Micro = 2;
}

typedef PortId = Int;

@:enum abstract PinDataType(Int) from Int to Int {
	var Node 		= 0;	// Accepts an entire node as its input (Typically for logic flow)
	var Numeric 	= 1;	// Accepts numeric values (int/float)
	var Bool 		= 2;	// Accepts bool and numerics (where number > 0)
	var Text		= 3;	// Accepts a string as its input
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
	@serializeType("haxe.ds.IntMap")
	public var pins: Map<PortId,PinId> = [];
	#if hlimgui
	var def(get, never): NodeDefinition;
	@serializeType("cerastes.data.EditorData")
	public var editorData: EditorData = {};

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

	function getPinDefForPin( pinId: PinId )
	{
		for( portId => otherPinId in pins )
		{
			if( pinId == otherPinId )
				return getPinDefForPort( portId );
		}

		return null;
	}

	function getPinDefForPort( portId: Int )
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
	public var id: LinkId;
	public var sourceId: PinId;
	public var destId: PinId;
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
