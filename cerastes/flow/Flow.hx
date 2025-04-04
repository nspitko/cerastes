package cerastes.flow;

import cerastes.Tickable.TimeManager;
import cerastes.data.Nodes;
import cerastes.fmt.FlowResource;
#if hlimgui
import imgui.ImGuiMacro.wref;
import haxe.rtti.Meta;
import cerastes.tools.ImGuiNodes;
import cerastes.tools.ImguiTool;
import cerastes.tools.ImguiTools;
import imgui.NodeEditor;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import hl.UI;
import cerastes.tools.FlowDebugger;
#end

@:structInit class FlowHandle<T:FlowNode>
{
	public var node: T;
	public var runner: FlowRunner;

	public function resume() { node.nextAll( runner ); }
	public function nextPort(port: PortId) {
		var pinId = node.pins[port];
		node.next( runner, pinId );
	}

	public function new( node: T, runner: FlowRunner )
	{
		this.node = node;
		this.runner = runner;
	}
}

/**
 * Puts text on the screen
 */
 class InstructionNode extends FlowNode
 {
	 @editor("Instruction","StringMultiline")
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
		 color: 0xFF555500,
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
	 @editor("Condition","Array","String")
	 public var conditions: Array<String>;

	 public override function process( runner: FlowRunner )
	 {
		var idx = 0;
		try
		{
			while( idx < conditions.length )
			{
				var program = runner.context.parser.parseString(conditions[idx]);

				var result : Bool = runner.context.interp.execute(program);
				if( result )
				{
					next( runner, pins[idx+1] ); // true
					return;
				}

				idx++;
			}
			next( runner, pins[idx+1] ); // false


		}
		catch (e )
		{
			next( runner, pins[2] ); // false
			Utils.warning('Error:${e.message}\nWhile running conditions for node ${id}.\nInstruction was ${conditions[idx]}');
		}
	 }

	 #if hlimgui
	 static final d: NodeDefinition = {
		 name:"Condition",
		 kind: Blueprint,
		 color: 0xFF222288,
		 //width: 75,
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
				 label: "\uf04b",
				 dataType: Node,
				 color: 0xFF22AA22
			 },
			 {
				 id: 2,
				 kind: Output,
				 label: "\uf04b",
				 dataType: Node,
				 color: 0xFFaa2222
			 }
		 ]
	 };

	 override function get_def() { return d; }

	 override function onBeforeEditor( editor: ImGuiNodes )
	{
		if( conditions != null )
		{
			var desiredPins = conditions.length + 1;
			for( i in 0 ... desiredPins )
			{
				if( !pins.exists(i+1) )
				{
					pins.set(i+1, editor.getNextId() );
				}
			}

			if( pins.exists( desiredPins + 1 ) )
				pins.remove( desiredPins + 1 );

		}
	}

	override function getPinDefForPort( portId: PortId ) : NodePinDefinition
	{
		if( conditions == null )
			conditions = [];

		if( portId > 0 )
		{
			if( portId == conditions.length + 1)
			{
				return {
					id: portId,
					kind: Output,
					label: '\uf04e False',
					dataType: Node,
					color: 0xFFaa2222
				}
			}
			else
			{
				return {
					id: portId,
					kind: Output,
					label: '\uf04e True ${portId}',
					dataType: Node,
					color: 0xFF22AA22
				}
			}

		}

		return super.getPinDefForPort( portId );
	}
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
	override function get_size(): ImVec2 { return {x: commentWidth, y: commentHeight}; }
	override function setSize(v: ImVec2)
	{
		// @bugbug What the fuck are these numbers
		commentWidth = v.x - 16;
		commentHeight = v.y - 43;

		if( commentHeight == 16)
			trace("Setting node to bad value?!");
	}
	 #end
 }

 /**
 * Used to switch between scenes
 * be done from other sources.
 */
@:structInit
class FlowNote extends FlowNode
{
	#if hlimgui
	@editor("Note","StringMultiline")
	public var note: String;

	@noSerialize
	public static final maxWidth = 250;

	static final d: NodeDefinition = {
		name:"Note",
		kind: Note,
		pins: []
	};

	override function get_def() { return d; }
	override function get_label() { return note; }
	override function get_size(): ImVec2 {

		var size = ImGui.calcTextSize( note, null, false, maxWidth );

		return {x: size.x, y: maxWidth };
	}

	override function render()
	{
		ImGui.pushTextWrapPos( ImGui.getCursorPos().x + maxWidth );
		ImGui.textWrapped( note );
		ImGui.popTextWrapPos();

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
			super.process( runner );
			return;
		}

		childRunner = hxd.Res.loader.loadCache( file, FlowResource ).toFlow( runner.context );
		childRunner.parent = runner;
		childRunner.registerOnExit( this, (handled: Bool) -> {
			if( hasExited )
			{
				Utils.error('File ${ file } has exited more than once!');
				return handled;
			}
			hasExited = true;

			if( runner.child == childRunner )
				runner.child = null;

			nextAll( runner );
			return handled;
		} );
		runner.child = childRunner;
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

	override function onTooltip( editor: ImGuiNodes )
	{
		var out = super.onTooltip(editor);

		if( out.length > 0 ) out += "\n";
		out += '*File*\nPath: ${file}';

		return out;
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
		var scene: cerastes.Scene = cerastes.App.currentScene.switchToNewScene( scene, true );
		if( scene == null )
		{
			nextAll(runner);
		}
		else
		{
			scene.registerOnSceneReady(this, ( handled ) -> {
				nextAll( runner );
				scene.unregisterOnSceneReady(this);
				return handled;
			});
		}
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

	override function onTooltip( editor: ImGuiNodes )
	{
		var out = super.onTooltip(editor);

		if( out.length > 0 ) out += "\n";
		out += '*Scene*\n${scene}';

		return out;
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

	override function onTooltip( editor: ImGuiNodes )
	{
		var out = super.onTooltip(editor);

		if( out.length > 0 ) out += "\n";
		out += '*Label*\nId: ${labelId}';

		return out;
	}
	#end
}

/**
 * Jump to a label. Useful for organizing large graphs.
 */
 @:structInit
class JumpNode extends FlowNode
{
	@editor("Label","String")
	public var labelId: String = null;

	public override function process( runner: FlowRunner )
	{
		if( labelId != null)
			runner.jump(labelId);
	}

	#if hlimgui
	static final d: NodeDefinition = {
		name:"Jump",
		kind: Blueprint,
		color: 0xFF882222,
		pins: [
			{
				id: 0,
				kind: Input,
				label: "\uf04e Input",
				dataType: Node,
			}
		]
	};

	override function get_def()	{ return d;	}

	override function get_labelInfo()
	{
		return labelId;
	}

	override function onTooltip( editor: ImGuiNodes )
	{
		var out = super.onTooltip(editor);

		if( out.length > 0 ) out += "\n";
		out += '*Jump*\nTarget: ${labelId}';

		return out;
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
		super.register(runner);
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
	inline function key( runner: FlowRunner )
	{
		return '${runner.file}-${runner.context.key}-${id}';
	}

	public function wasSeen( runner )
	{
		return FlowState.seen.indexOf( key(runner) ) != -1;
	}

	/**
	 * Basic processing function for nodes. If baseclass is called, will call next
	 * on every pin.
	 *
	 * @param runner
	 */
	public function process( runner: FlowRunner )
	{
		nextAll( runner );
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
			next( runner, pinId );
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
	public function next( runner: FlowRunner, pin: PinId32 )
	{
		for( link in runner.links )
		{
			if( link.sourceId == pin )
			{
				// Check conditions, if any
				if( link.conditions != null )
				{
					var seen = FlowState.seen.indexOf( key( runner ) ) != -1;
					runner.context.interp.variables.set("once", !seen);
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
							valid = false;
							break;

						}
					}
					if( !valid )
						continue;
				}
				var target = runner.lookupNodeByPin( link.destId );
				FlowState.seen.push( key( runner ) );

				#if hlimgui
				FlowDebugger.addHistory(runner, this, target, pin);
				#end

				runner.queue( target );
			}
		}
	}

	/**
	 * returns all nodes connected to this pin
	 * @param pin
	 * @param runner
	 */
	@:access(cerastes.flow.Flow.FlowRunner)
	public function getOutputs( runner: FlowRunner, pin: PinId32 )
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

	var inputCallback: ImGuiInputTextCallbackDataFunc = null;

	function renderProps()
	{
		ImGui.pushID( '${id}' );
		ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.text( def.name );
		ImGui.popFont();

		var meta: haxe.DynamicAccess<Dynamic> = Meta.getFields( Type.getClass( this ) );
		for( field => data in meta )
		{
			var metadata: haxe.DynamicAccess<Dynamic> = data;
			if( metadata.exists("editor") )
			{
				var tooltip = null;
				if( metadata.exists("editorTooltip") )
				{
					tooltip = metadata.get("editorTooltip")[0];
				}
				var args = metadata.get("editor");
				renderElement(field, args[1], args, tooltip);
			}
		}

		customRender();

		ImGui.text('ID: ${id}');

		ImGui.popID();
	}

	function renderElement( field: String, type: String, args: Array<String>, ?tooltip: String )
	{
		switch( type )
		{
			case "Bool":
				var val = Reflect.getProperty(this,field);
				if( wref( ImGui.checkbox(args[0], _ ), val ) )
					Reflect.setField( this, field, val.get() );

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				onAfterProp(field);

			case "Int":
				var val = Reflect.getProperty(this,field);
				if( wref( ImGui.inputInt(args[0], _ ), val ) )
					Reflect.setField( this, field, val.get() );

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				onAfterProp(field);

			case "String" | "LocalizedString":
				var val = Reflect.getProperty(this,field);
				var ret = IG.textInput(args[0],val);
				if( ret != null )
					Reflect.setField( this, field, ret );

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				onAfterProp(field);

			case "StringMultiline" | "LocalizedStringMultiline":
				var val = Reflect.getProperty(this,field);
				var ret = IG.textInputMultiline(args[0],val,{x: -1, y: 300 * Utils.getDPIScaleFactor()}, ImGuiInputTextFlags.Multiline | ImGuiInputTextFlags.CallbackAlways ,1024*8, inputCallback);
				if( ret != null )
					Reflect.setField( this, field, ret );

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				onAfterProp(field);

			case "Tile":
				var val = Reflect.getProperty(this,field);
				var ret = IG.inputTile(args[0],val);
				if( ret != null )
					Reflect.setField( this, field, ret );

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				onAfterProp(field);

			case "File":
				var val = Reflect.getProperty(this,field);
				var ret = IG.textInput(args[0],val);
				if( ret != null )
					Reflect.setField( this, field, ret );

				onAfterProp(field);

				if( ImGui.beginDragDropTarget( ) )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && StringTools.endsWith(payload, "flow") )
					{
						Reflect.setField( this, field, payload );
					}
				}

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);


				if( ImGui.button("Select...") )
				{
					hxd.System.allowTimeout = false;
					var file = UI.loadFile({
						title:"Select file",
						filters:[
						{name:"Cerastes flow files", exts:["flow"]},
						],
						filterIndex: 0
					});
					hxd.System.allowTimeout = true;
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

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				onAfterProp(field);

			case "Array":
				ImGui.text(args[0]);

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				var val:Array<String> = Reflect.getProperty(this,field);
				switch( args[2] )
				{
					case "String":
						if( val != null )
						{
							for( idx in 0 ... val.length )
							{
								if( val[idx] == null )
									continue;

								ImGui.pushID('idx${idx}');
								wref( ImGui.inputText( '${idx}', _), val[idx] );

								if( ImGui.button("Del") )
									val.splice(idx,1);

								ImGui.popID();
							}
						}
						if( ImGui.button("Add") )
						{
							if( val == null )
								Reflect.setField( this, field, [""] );
							else
								val.push("");
						}
				}



			default:
				ImGui.text('UNHANDLED!!! ${field} -> ${args[0]} of type ${args[1]}');
		}
	}

	function onAfterProp( field: String )
	{

	}

	function customRender()
	{
		// Add your own magic here!
	}

	function getOptions( field: String ) : Array<Dynamic>
	{
		return null;
	}

	function updatePreviewWindow( windowId: String )
	{

	}

	function renderPreviewWindow(e: h3d.Engine)
	{

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

class FlowState
{
	public static var seen: Array<String> = [];
	public static var usedSelectors: Array<NodeId32> = [];
	public static var doneActions: Array<String> = [];

	public static function reset()
	{
		seen = [];
		usedSelectors = [];
		doneActions = [];
	}

}

@:allow(FlowRunner)
class FlowContext
{
	public var parser = new hscript.Parser();
	public var interp = new cerastes.StrictInterp();

	// Used to disambiguate dialogue seen states between rooms.
	public var key: String;

	var runner: FlowRunner;

	public function new( runner: FlowRunner )
	{
		this.runner = runner;

		interp.variables.set("Std", Std );

		interp.variables.set("changeScene", changeScene );

		interp.variables.set("set", set );
		interp.variables.set("get", get );

		FlowRunner.onContextCreated(this);
		//interp.variables.set("seenNode", seenNode );

	}

	public static function changeScene( className: String )
	{
		#if client
		App.currentScene.switchToNewScene( className );
		#end
	}

	public function get(key: String) : Dynamic
	{
		return interp.variables.get(key);
	}

	public function set(key: String, value: Dynamic)
	{
		interp.variables.set(key, value);
	}
}

@:allow(cerastes.flow.FlowNode)
@:build(cerastes.macros.Callbacks.CallbackGenerator.build())
class FlowRunner implements cerastes.Tickable
{
	var nodes: Array<FlowNode>;
	var links: Array<FlowLink>;

	var labels: Map<String, FlowNode> = [];

	var root: FlowNode;
	var stack: List<FlowNode> = new List<FlowNode>();

	var res: FlowResource;
	public var context: FlowContext;

	var file: String;
	// Just the name of the file, no path/ext
	var name: String;

	static var runnerIdx = 0;
	public var runnerId(default, null): Int = 0;

	var lastNodeId: NodeId32;

	// If set, indicates what created us
	public var instigator(default, null): haxe.PosInfos;

	// If set, points to the runner that created this one
	public var parent: FlowRunner = null;
	// Our active childrunner. We don't support running multiple direct
	// children at once, however our child could have a child.
	public var child: FlowRunner = null;

	// whether or not this runner has finished all tasks and is ready to exit.
	// This is mostly used for sub runners, if you just want to see if there
	// is any more pending work this frame use .busy
	public var finished( get, null ): Bool = false;
	function get_finished() { return finished; }

	// Whether or not we have a node in queue
	public var busy( get, never ): Bool;
	function get_busy() { return stack.first() != null; }

	/**
	 * OnExit is called when a flow reaches it's exit node.
	 * Mainly used for
	 * @return Bool
	 */
	@:callback
	public function onExit(): Bool;

	/**
	 * Called when a new runner is created. This lets us hook our own interp state and functions in
	 * @param runner
	 * @return Bool
	 */
	@:callbackStatic
	public static function onContextCreated(context: FlowContext): Bool;


	public function new( res: FlowResource, ?ctx: FlowContext, ?pos:haxe.PosInfos )
	{
		runnerId = runnerIdx++;
		this.instigator = pos;
		this.res = res;
		this.nodes = res.getData().nodes;
		this.links = res.getData().links;
		this.file = res.name;

		var r = ~/([A-z0-9-]+)\.flow/;
		Utils.assert(r.match(this.file), "Could not resolve flow name. This will break localization (and may crash)");
		this.name = r.matched(1);

		context = ctx == null ? new FlowContext( this ) : ctx;

		for( n in nodes )
			n.register(this);

		registerOnExit( this, (handled) -> {
			finished = true;
			unregisterOnExit(this);
			TimeManager.unregister( this );
			return handled;
		} );

		TimeManager.register(this);

		#if tools
		res.watch(() -> {
			try
			{
				var targetNodeId = lastNodeId;
				@:privateAccess res.data = null;

				this.nodes = res.getData().nodes;
				this.links = res.getData().links;

				var target = lookupNodeById( targetNodeId );
				if( target != null )
					queue(target);
				else
				{
					Utils.warning("Previous node ID is invalid; attempting to start from entry...");
					var target = lookupNodeByType( EntryNode );
					if( target != null )
						queue(target)
					else
						Utils.error("Live reload failed: Could not find a valid entry point.");
				}

				#if hlimgui
				ImGuiToolManager.showPopup('Live Reload','Successfully reloaded ${res.name}. Execution will attempt to continue from the last node.', ImGuiPopupType.Info);
				#end
			}
			catch( e )
			{
				Utils.warning('Live reload of ${res.name} failed!');
			}
		});

		#end

	}

	public function setVar( name: String, value: Dynamic )
	{
		context.interp.variables.set(name, value );
	}

	public function getVar( name: String )
	{
		return context.interp.variables.get( name );
	}

	public function run( nodeId: NodeId32 = 0, label: String = null )
	{
		if( nodeId != 0 )
		{
			var target = lookupNodeById( nodeId );
			queue( target );
		}
		else if( label != null )
		{
			jump( label );
		}
		else
		{
			queue( root );
		}
	}

	public function tick( delta: Float )
	{
		while( stack.first() != null )
		{
			var n = stack.pop();
			lastNodeId = n.id;
			n.process( this );
		}
	}

	public function queue( node: FlowNode )
	{
		stack.add(node);
	}

	public function jump( id: String )
	{
		if( !labels.exists(id) )
		{
			// Check child runners
			if( child != null && child.isValidJump( id ) )
			{
				child.jump(id);
				return;
			}
			Utils.error('Tried to jump to invalid label ${id} in file ${res.name}');
			return;
		}

		var node = labels.get(id);
		queue( node );


	}

	public function isValidJump( id: String )
	{
		return labels.exists(id);
	}

	public function jumpFile( file: String, nodeId: NodeId32 = 0, label: String = null )
	{
		var hasExited = false;

		if( file == null || !hxd.Res.loader.exists( file ) )
		{
			Utils.error('Tried to jump to invalid file ${file}!');
			return null;
		}

		var childRunner = hxd.Res.loader.loadCache( file, FlowResource ).toFlow( context );
		childRunner.parent = this;
		childRunner.registerOnExit( this, (handled: Bool) -> {
			if( hasExited )
			{
				Utils.error('File ${ file } has exited more than once!');
				return handled;
			}
			hasExited = true;

			// @todo: There should be a smarter way to handle this....
			if( childRunner == child )
				child = null;

			return handled;
		} );
		childRunner.run(nodeId, label);

		child = childRunner;

		return child;
	}

	function lookupNodeByPin( pinId: PinId32 )
	{
		for( n in nodes )
		{
			for( portId => otherPinId32 in n.pins )
				if( otherPinId32 == pinId )
					return n;
		}

		return null;
	}

	// You *really* don't want to do this outside of a few very specific cases, almost entirely tool based "oh no" ones.
	function lookupNodeByType( type: Class<FlowNode> )
	{
		for( n in nodes )
		{
			if( Std.isOfType(n, type ) )
			{
				return n;
			}
		}

		return null;
	}

	function lookupNodeById( nodeId: NodeId32 )
	{
		for( n in nodes )
		{
			if( n.id == nodeId )
				return n;
		}

		return null;
	}

	public function getOutputs( node: FlowNode, pinId: PinId32) : Array<FlowNode>
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
							Utils.info('${program} -> ${result}');
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