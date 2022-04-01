package cerastes.flow;

import game.GameState;
import cerastes.fmt.FlowResource;
import cerastes.data.Nodes;
#if hlimgui
import haxe.rtti.Meta;
import cerastes.tools.ImGuiNodes;
import cerastes.tools.ImguiTool;
import cerastes.tools.ImguiTools;
import imgui.NodeEditor;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import hl.UI;
#end

/**
 * Puts text on the screen
 */
 class InstructionNode extends FlowNode
 {
	 @editor("Condition","StringMultiline")
	 public var instruction: String;

	 public override function process( runner: FlowRunner )
	 {

		try
		{
			var program = runner.context.parser.parseString(instruction);

			runner.context.interp.execute(program);


		}
		catch (e )
		{
			Utils.warning('Error:${e.message}\nWhile running instruction for node ${id}\nInstruction was ${instruction}');
		}

		nextAll( runner );
	 }

	 #if hlimgui
	 static final d: NodeDefinition = {
		 name:"Instruction",
		 kind: Blueprint,
		 color: 0xFF222288,
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
				 dataType: Node,
			 }
		 ]
	 };

	 override function get_def() { return d; }
	 #end
 }

/**
 * True/false logic block, because sometimes you need a bit more explicit control than link conditions
 * give you out of the box.
 */
 class ConditionNode extends FlowNode
 {
	 @editor("Condition","StringMultiline")
	 public var condition: String;

	 public override function process( runner: FlowRunner )
	 {

		try
		{
			var program = runner.context.parser.parseString(condition);

			var result : Bool = runner.context.interp.execute(program);
			if( result )
				next( pins[1], runner ); // true
			else
				next( pins[2], runner ); // false


		}
		catch (e )
		{
			next( pins[2], runner ); // false
			Utils.warning('Error:${e.message}\nWhile running conditions for node ${id}.\nInstruction was ${condition}');
		}
	 }

	 #if hlimgui
	 static final d: NodeDefinition = {
		 name:"Condition",
		 kind: Blueprint,
		 color: 0xFF222288,
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
				 label: "True \uf04b",
				 dataType: Node,
				 color: 0xFF22AA22
			 },
			 {
				 id: 2,
				 kind: Output,
				 label: "False \uf04b",
				 dataType: Node,
				 color: 0xFFaa2222
			 }
		 ]
	 };

	 override function get_def() { return d; }
	 #end
 }


/**
 * Used to switch between scenes
 * be done from other sources.
 */
 @:structInit
 class FlowComment extends FlowNode
 {
	#if hlimgui
	@editor("Comment","String")
	public var comment: String;
	public var commentWidth: Single = 0;
	public var commentHeight: Single = 0;


	static final d: NodeDefinition = {
		name:"Comment",
		kind: Comment,
		pins: []
	};

	override function get_def() { return d; }
	override function get_label() { return comment; }
	override function get_size() { return {x: commentWidth, y: commentHeight}; }
	override function setSize(v: ImVec2)
	{
		commentWidth = v.x;
		commentHeight = v.y;
	}
	 #end
 }



/**
 * Loads (and jumps into) another flow file
 */
class FileNode extends FlowNode
{
	@editor("Label","File","flow")
	public var file: String;

	@noSerialize
	var childRunner: FlowRunner;

	public override function process( runner: FlowRunner )
	{
		var hasExited = false;


		if( file == null || !hxd.Res.loader.exists( file ) )
		{
			Utils.error('File node ${id} points to missing file ${file}!');
			super.process(runner);
			return;
		}

		childRunner = hxd.Res.loader.loadCache( file, FlowResource ).toFlow( runner.context );
		childRunner.registerOnExit( this, (handled: Bool) -> {
			if( hasExited )
			{
				Utils.error('File ${ file } has exited more than once!');
				return handled;
			}
			hasExited = true;
			nextAll( runner );
			return handled;
		} );
		childRunner.run();
	}

	#if hlimgui
	static final d: NodeDefinition = {
		name:"File",
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

	override function get_def() { return d; }

	override function get_labelInfo()
	{
		if( file != null )
		{
			var c = file.split("/");
			return c[c.length - 1];
		}
		return null;
	}
	#end
}


/**
 * Used to switch between scenes
 * be done from other sources.
 */
class SceneNode extends FlowNode
{
	@editor("Scene","ComboString")
	public var scene: String;


	public override function process( runner: FlowRunner )
	{
		Main.currentScene.switchToNewScene( scene );

		super.process(runner);
	}

	#if hlimgui
	static final d: NodeDefinition = {
		name:"Scene",
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

	override function get_def() { return d; }

	override function getOptions( field: String ): Array<Dynamic>
	{
		if( field == "scene")
		{
			var cls = CompileTime.getAllClasses(Scene);
			return [ for(c in cls) Type.getClassName(c) ];
		}

		return super.getOptions(field);
	}
	#end

}

/**
 * A standard label node. Registers itself with the runner so string-based lookups can
 * be done from other sources.
 */
 @:structInit
class LabelNode extends FlowNode
{
	@editor("Label","String")
	public var labelId: String = null;

	public override function register( runner: FlowRunner )
	{
		if( labelId != null)
			runner.labels.set( labelId, this );
	}

	#if hlimgui
	static final d: NodeDefinition = {
		name:"Label",
		kind: Blueprint,
		color: 0xFF882222,
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

	override function get_def()	{ return d;	}

	override function get_labelInfo()
	{
		return labelId;
	}
	#end
}

/**
 * The entry point for all flow files
 */
 @:structInit
class EntryNode extends FlowNode
{
	public override function register( runner: FlowRunner )
	{
		runner.root = this;
	}

	#if hlimgui
	static final d: NodeDefinition = {
		name:"Entry",
		kind: Blueprint,
		color: 0xFF882222,
		pins: [
			{
				id: 0,
				kind: Output,
				label: "Output \uf04b",
				dataType: Node
			}
		]
	};

	override function get_def()	{ return d;	}
	#end
}

/**
 * The exit point for all flow files, pops stack
 */
 @:structInit
class ExitNode extends FlowNode
{
	public override function process( runner: FlowRunner )
	{
		runner.onExit();
	}

	#if hlimgui
	static final d: NodeDefinition = {
		name:"Exit",
		kind: Blueprint,
		color: 0xFF882222,
		pins: [
			{
				id: 0,
				kind: Input,
				label: "\uf04e Input",
				dataType: Node,
			},
		]
	};

	override function get_def()	{ return d;	}

	#end
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
				// Check conditions, if any
				if( link.conditions != null )
				{
					var valid = true;
					for( condition in link.conditions )
					{
						try
						{
							var program = runner.context.parser.parseString(condition);

							var result : Bool = runner.context.interp.execute(program);
							if( !result )
							{
								valid = false;
								break;
							}

						}
						catch (e )
						{
							Utils.warning('Error:${e.message}\nWhile running conditions for link ${link.id}.\nCondition was ${condition}');
						}
					}
					if( !valid )
						continue;
				}
				var target = runner.lookupNodeByPin( link.destId );
				target.process( runner );
			}
		}
	}

	/**
	 * returns all nodes connected to this pin
	 * @param pin
	 * @param runner
	 */
	@:access(cerastes.flow.Flow.FlowRunner)
	public function getOutputs( pin: PinId, runner: FlowRunner )
	{
		var out = [];
		for( link in runner.links )
		{
			if( link.sourceId == pin )
			{
				// Check conditions, if any
				if( link.conditions != null )
				{
					var valid = true;
					for( condition in link.conditions )
					{
						try
						{
							var program = runner.context.parser.parseString(condition);

							var result : Bool = runner.context.interp.execute(program);
							if( !result )
							{
								valid = false;
								break;
							}

						}
						catch (e )
						{
							Utils.warning('Error:${e.message}\nWhile running conditions for link ${link.id}.\nCondition was ${condition}');
						}
					}
					if( !valid )
						continue;
				}
				var target = runner.lookupNodeByPin( link.destId );
				out.push(target);
			}
		}

		return out;
	}


	public function register( runner: FlowRunner )
	{

	}

	#if hlimgui
	function renderProps()
	{
		ImGui.pushID( '${id}' );
		ImGui.pushFont( ImguiToolManager.headingFont );
		ImGui.text( def.name );
		ImGui.popFont();

		var meta: haxe.DynamicAccess<Dynamic> = Meta.getFields( Type.getClass( this ) );
		for( field => data in meta )
		{
			var metadata: haxe.DynamicAccess<Dynamic> = data;
			if( metadata.exists("editor") )
			{
				var args = metadata.get("editor");
				switch( args[1] )
				{
					case "String" | "LocalizedString":
						var val = Reflect.getProperty(this,field);
						var ret = IG.textInput(args[0],val);
						if( ret != null )
							Reflect.setField( this, field, ret );

					case "StringMultiline" | "LocalizedStringMultiline":
						var val = Reflect.getProperty(this,field);
						var ret = IG.textInputMultiline(args[0],val,{x: -1, y: 300 * Utils.getDPIScaleFactor()},0,1024*8);
						if( ret != null )
							Reflect.setField( this, field, ret );

					case "Tile":
						var val = Reflect.getProperty(this,field);
						var ret = IG.inputTile(args[0],val);
						if( ret != null )
							Reflect.setField( this, field, ret );

					case "File":
						var val = Reflect.getProperty(this,field);
						var ret = IG.textInput(args[0],val);
						if( ret != null )
							Reflect.setField( this, field, ret );

						if( ImGui.beginDragDropTarget( ) )
						{
							var payload = ImGui.acceptDragDropPayloadString("asset_name");
							if( payload != null && StringTools.endsWith(payload, "flow") )
							{
								Reflect.setField( this, field, payload );
							}
						}


						if( ImGui.button("Select...") )
						{
							var file = UI.loadFile({
								title:"Select file",
								filters:[
								{name:"Cerastes flow files", exts:["flow"]},
								],
								filterIndex: 0
							});
							if( file != null )
								Reflect.setField( this, field, file );
						}

					case "ComboString":
						var val = Reflect.getProperty(this,field);
						var opts = getOptions( field );
						var idx = opts.indexOf( val );
						if( ImGui.beginCombo( args[0], val ) )
						{
							for( opt in opts )
							{
								if( ImGui.selectable( opt, opt == val ) )
									Reflect.setField( this, field, opt );
							}
							ImGui.endCombo();
						}


					default:
						ImGui.text('UNHANDLED!!! ${field} -> ${args[0]} of type ${args[1]}');
				}

			}
		}

		customRender();

		ImGui.popID();
	}

	function customRender()
	{
		// Add your own magic here!
	}

	function getOptions( field: String ) : Array<Dynamic>
	{
		return null;
	}
	#end

}
/**
 * Flow links contain additional data that may control their viability as exits, such as conditions
 */
@:structInit
class FlowLink extends Link
{
	public var conditions: Array<String> = null;
}

@:structInit
class FlowFile
{
	public var version: Int = 1;
	public var nodes: Array<FlowNode>;
	@serializeType("cerastes.flow.FlowLink")
	public var links: Array<FlowLink>;
}

class FlowContext
{
	public var parser = new hscript.Parser();
	public var interp = new hscript.Interp();

	var runner: FlowRunner;

	public function new( runner: FlowRunner )
	{
		this.runner = runner;

		interp.variables.set("GS", GameState );
		interp.variables.set("Std", Std );

		interp.variables.set("changeScene", changeScene );

		interp.variables.set("set", GameState.set );
		interp.variables.set("get", GameState.get );
		//interp.variables.set("seenNode", seenNode );

	}

	public static function changeScene( className: String )
	{
		#if client
		Main.currentScene.switchToNewScene( className );
		#end
	}
}

@:allow(cerastes.flow.FlowNode)
@:build(cerastes.macros.Callbacks.CallbackGenerator.build())
class FlowRunner
{
	var nodes: Array<FlowNode>;
	var links: Array<FlowLink>;

	var labels: Map<String, FlowNode> = [];

	var root: FlowNode;
	var stack: List<FlowNode>;

	var res: FlowResource;
	var context: FlowContext;

	/**
	 * OnExit is called when a flow reaches it's exit node.
	 * Mainly used for
	 * @return Bool
	 */
	@:callback
	public function onExit(): Bool;


	public function new( res: FlowResource, ?ctx: FlowContext )
	{
		this.res = res;
		this.nodes = res.getData().nodes;
		this.links = res.getData().links;

		context = ctx == null ? new FlowContext( this ) : ctx;

		for( n in nodes )
			n.register(this);
	}

	public function run()
	{
		root.process(this);
	}

	public function jump( id: String )
	{
		if( !labels.exists(id) )
		{
			Utils.error('Tried to jump to invalid label ${id} in file ${res.name}');
			return;
		}

		var node = labels.get(id);
		node.process( this );


	}

	public function jumpFile( file: String )
	{
		var hasExited = false;

		if( file == null || !hxd.Res.loader.exists( file ) )
		{
			Utils.error('Tried to jump to invalid file ${file}!');
			return;
		}

		var childRunner = hxd.Res.loader.loadCache( file, FlowResource ).toFlow( context );
		childRunner.registerOnExit( this, (handled: Bool) -> {
			if( hasExited )
			{
				Utils.error('File ${ file } has exited more than once!');
				return handled;
			}
			hasExited = true;
			return handled;
		} );
		childRunner.run();
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

	function lookupNodeById( nodeId: NodeId )
	{
		for( n in nodes )
		{
			if( n.id == nodeId )
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
				// Check conditions, if any
				if( l.conditions != null )
				{
					var valid = true;
					for( condition in l.conditions )
					{
						try
						{
							var program = context.parser.parseString(condition);

							var result : Bool = context.interp.execute(program);
							trace('${program} -> ${result}');
							if( !result )
							{
								valid = false;
								break;
							}

						}
						catch (e )
						{
							Utils.warning('Error:${e.message}\nWhile running conditions for link ${l.id}.\nCondition was ${condition}');
						}
					}
					if( !valid )
						continue;
				}
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