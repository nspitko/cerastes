package cerastes.flow;

import imgui.NodeEditor.PinId;
import imgui.NodeEditor.NodeId;
import cerastes.tools.ImGuiNodes;

/**
 * A standard label node. Registers itself with the runner so string-based lookups can
 * be done from other sources.
 */
class SceneNode extends FlowNode
{
	public var scene: String;
	//static var def

	public override function process( runner: FlowRunner )
	{
		Main.currentScene.switchToNewScene( scene );

		super.process(runner);
	}
}

/**
 * A standard label node. Registers itself with the runner so string-based lookups can
 * be done from other sources.
 */
class LabelNode extends FlowNode
{
	public var labelId: String = null;

	static final d: NodeDefinition = {
		name:"Label",
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
			}
		]
	};

	override function get_def()
	{
		return d;
	}

	public override function register( runner: FlowRunner )
	{
		runner.labels.set( labelId, this );
	}
}

/**
 * FlowNodes are the base for all nodes in the flow
 *
 * They should never hold state, and instead attach it to the runner when needed. Node
 * sets may be running on multiple runners at once, and may be unloaded/reloaded as files change
 *
 */
@:structInit
class FlowNode extends Node
{
	/**
	 * Basic processing function for nodes. If baseclass is called, will call next
	 * on every pin.
	 *
	 * @param runner
	 */
	public function process( runner: FlowRunner )
	{
		nextAll(runner);
	}

	/**
	 * Calls Next on every pin.
	 *
	 * Safe to call on inputs since they will never hold the sourceId slot
	 *
	 * @param runner
	 */
	public function nextAll( runner: FlowRunner )
	{
		for( portId => pinId in pins )
		{
			next( pinId, runner );
		}
	}

	/**
	 * Process all nodes attached to the specified pin
	 *
	 * pin must always be the source pin
	 *
	 * @param pin
	 * @param runner
	 */
	@:access(cerastes.flow.Flow.FlowRunner)
	public function next( pin: PinId, runner: FlowRunner )
	{
		for( link in runner.links )
		{
			if( link.sourceId == pin )
			{
				var target = runner.lookupNodeByPin( link.destId );
				target.process( runner );
			}
		}
	}


	public function register( runner: FlowRunner )
	{

	}



}

@:allow(cerastes.flow.FlowNode)
class FlowRunner
{
	var nodes: Array<FlowNode>;
	var links: Array<Link>;

	var labels: Map<String, Node>;

	public function new( nodes: Array<FlowNode> )
	{
		this.nodes = nodes;

		for( n in nodes )
			n.register(this);
	}

	public function jump( id: NodeId )
	{

	}

	function lookupNodeByPin( pinId: PinId )
	{
		for( n in nodes )
		{
			for( portId => otherPinId in n.pins )
				if( otherPinId == pinId )
					return n;
		}

		return null;
	}

	public function getOutputs( node: FlowNode, pinId: PinId) : Array<FlowNode>
	{
		var out = [];
		for( l in links )
		{
			if( l.sourceId == pinId )
			{
				out.push( lookupNodeByPin( l.destId ) );
			}
		}

		return out;
	}


}

class Flow
{
	//public static function register
}