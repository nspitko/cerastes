package cerastes.butai;

import haxe.Json;

import game.GameState;
import cerastes.ui.Console.GlobalConsole;
import cerastes.butai.ButaiTypeBuilder.ButaiNode;
import cerastes.butai.ButaiDialogController;
import db.Butai;

import cerastes.butai.Debug;

#if butai
@:build(cerastes.macros.Callbacks.ButaiCallbackGenerator.build("res/nodes.bdef"))
#end
@:build(cerastes.macros.Callbacks.CallbackGenerator.build())
class ButaiNodeManager
{
	static inline var prefix = "db.";
	private var currentNode : ButaiNode;
	private var lastDialogueNode : ButaiNode;

	private var parser = new hscript.Parser();
	private var interp = new hscript.Interp();

	private var conditions = new Array< db.Butai.ConditionNode >();

	private var stack = new Array< ButaiNode >();

	private var paused = true;

	private var scanOnly = false;

	public var lastCG = "";


	public var seenNodes : Array<String>;

	public function new(node : ButaiNode)
	{
		setup(node);
	}

	public function setup( node : ButaiNode )
	{
		if( node == null )
		{
			Utils.error("Setup called with invalid node; File didn't load?");
			return;
		}

		trace(node);


		reset();

		interp.variables.set("GS", GameState );
		interp.variables.set("Std", Std );

		interp.variables.set("changeScene", ButaiSupport.changeScene );

		interp.variables.set("set", GameState.set );
		interp.variables.set("get", GameState.get );
		interp.variables.set("seenNode", seenNode );

		if( ButaiDialogController.instance == null )
			ButaiDialogController.instance = new ButaiDialogController();


		// @todo THIS IS BAD PLEASE FIX
		for( v in Butai.variables )
		{
			switch( v.type )
			{
				case "Bool":
					registerVariable( v.name, v.value == "True" );
				case "Int":
					registerVariable( v.name, Std.parseInt( v.value ) );
				case "Float":
					registerVariable( v.name, Std.parseFloat( v.value ) );
			}

		}


		currentNode = node;
		stack = [];

		Debug.registerOnDebugMsg( this, onDebugJump );
	}

	// Regsiter butai variables directly into intrep with defaults
	function setupVariables()
	{

	}

	public function onDebugJump( cmd: DebugMessage, ?handled )
	{
		jump( cmd.v );
		return false;
	}


	public function registerVariable(name: String, variable: Dynamic)
	{
		interp.variables.set(name, variable );
	}
	public function unregisterVariable( name: String )
	{
		interp.variables.remove( name );
	}

	public function reset()
	{
		seenNodes = new Array<String>();
		currentNode = null;
		stack = [];
		GameState.reset();
		resume();
	}


	public function resume()
	{
		paused = false;
	}

	public function pause()
	{
		paused = true;
	}

	public function jump( node: String )
	{
		var target = db.Butai.lookup( node );
		if( target == null )
		{
			Utils.assert(false,"Invalid hard jump: " + node);
			return;
		}
		next( db.Butai.lookup( node ) );
	}

	public function tryJump( node: String )
	{
		var target = db.Butai.lookup( node );
		if( target == null )
		{
			return false ;
		}
		next( db.Butai.lookup( node ) );
		return true;
	}

	private function getInputs( node : ButaiNode, ?pin: String ) : Array< ButaiNode >
	{
		var out = new Array<ButaiNode>();
		for( input in node.inputs )
		{
			if( pin != null && pin == input.name )
				out.push(input.target.get() );
			else if( pin  == null )
				out.push(input.target.get());
		}
		return out;
	}

	public function getOutputs( node : ButaiNode, ?pin: String ) : Array< ButaiNode >
	{
		var out = new Array<ButaiNode>();
		for( output in node.outputs )
		{
			if( pin != null && pin == output.name )
				out.push(output.target.get() );
			else if( pin  == null )
				out.push(output.target.get());
		}
		return out;
	}

	public function nextAll( node )
	{
		var outputs = getOutputs( node );
		for( out in outputs )
			next( out );
	}

	// Processes the currentNode and sets the next one.
	// We have to set next node while processing due to condition blocks.
	public function next( node : ButaiNode )
	{
		if( paused )
		{
			if( node != null )
				stack.unshift( node );
			return;
		}
		currentNode = null;
		if( node == null )
		{
			return;
		}

		Debug.debugUpdate('cn',cast node.id);

		switch( Type.getClassName(Type.getClass(node )) )
		{
			case "db.SceneNode":
				var sceneNode : db.Butai.SceneNode = cast node;

				if( !onSceneNode(cast node) )
				{
					Utils.info("Changing scene: " + sceneNode.scene );
					ButaiSupport.changeScene( sceneNode.scene );

					nextAll( node );
				}

			case "db.MusicNode":

				var mpn : db.Butai.MusicNode = cast node;


				if( !onMusicNode( mpn ) )
				{
					SoundManager.playMusic( mpn.file );
					nextAll( node );
				}

			case "db.SFXNode":

				var mpn : db.Butai.SFXNode = cast node;


				if( !onSFXNode( mpn ) )
				{
					SoundManager.sfx( mpn.file, mpn.loop == "1" );

					nextAll( node );
				}

			case "db.SFXStopNode":

				var mpn : db.Butai.SFXStopNode = cast node;
				SoundManager.stopsfx( mpn.file );

				if( !onSFXStopNode( mpn ) )
					nextAll( node );


			// Ok this one's a bit of a snowflake.
			// We want to find the next *non-logic* node on every branch
			// then jump to a random one. The goal here is to allow random
			// branches to conditional nodes (ie, only offer a random jump
			// target if we would meet it's base conditions)
			//
			// LD HACK: Only checks the first node for a condition, then assumes
			// the rest is probably fine.
			case "db.RandomNode":

				if( onRandomNode( cast node ) )
					return;

				var outputs = getOutputs( node );
				var validOutputs = [];
				for( out in outputs )
				{
					if( Type.getClassName(Type.getClass(out )) == "db.ConditionNode" )
					{

						var condition : db.Butai.ConditionNode = cast out;
						var script = condition.script;
						var program = parser.parseString(script);

						var result : Bool = interp.execute(program);

						var outputs = getOutputs( out, result ? "true" : "false" );

						if( outputs.length > 0 )
							validOutputs.push(out);
					}
					else
					{
						validOutputs.push( out );
					}
				}

				if( validOutputs.length > 0 )
				{
					var idx = Std.random( validOutputs.length );
					next( validOutputs[idx] );
				}

			// Here comes the fun: We don't support Articy's bullshit scripting language
			// but we DO support haxe, and boy howdy if the syntax ain't the same
			case "db.InstructionNode":

				var instruction : db.Butai.InstructionNode = cast node;
				var script = instruction.script;
				try
				{
					var program = parser.parseString(script);
					interp.execute(program);
				}
				catch( e: hscript.Expr.Error )
				{
					Utils.warning('Error in instruction ${instruction.id}(Line ${parser.line}): ${e}');
					Utils.warning('Instruction was: ${instruction.script}');
				}

				if( !onInstructionNode( instruction ) )
					nextAll( node );

			// Same deal, but conditions are evaluated as a giant "if".
			// True -> Output 0, False -> 1
			case "db.ConditionNode":
				var condition : db.Butai.ConditionNode = cast node;
				var script = condition.script;
				var result = false;
				try
				{
					var program = parser.parseString(script);

					result = interp.execute(program);

				}
				catch( e: Dynamic )
				{
					Utils.warning('Error in condition ${condition.id}: ${e}');
					Utils.warning('Condition was: ${condition.script}');
				}

				if( !onConditionNode( condition ) )
				{
					var outputs = getOutputs( node, result ? "true" : "false" );
					for( out in outputs )
						next( out );
				}

			// Jumps just tell us where to go next
			case "db.JumpNode":
				var j : db.Butai.JumpNode = cast node;

				if( !onJumpNode(j ) )
					jump(j.target);

			// Jumps just tell us where to go next
			case "db.JumpWithReturnNode":
				var j : db.Butai.JumpWithReturnNode = cast node;

				if( !onJumpWithReturnNode(j ) )
				{
					var outputs = getOutputs( node );
					for( out in outputs )
						stack.unshift( out );

					next( db.Butai.lookup( j.target ) );
				}

			case "db.ContainerNode":
				var ctn : db.Butai.ContainerNode = cast node;

				// Find the entrance
				var entrance = db.Butai.find( "ContainerEntranceNode", cast ctn.id );

				if( !onContainerNode(ctn ) )
					next(entrance); // @todo shouldn't this be nextAll??

			case "db.ContainerExitNode":
				var ctn : db.Butai.ContainerExitNode = cast node;

				// Find the container
				var container = ctn.parent.get();

				if( !onContainerExitNode(ctn ) )
					nextAll( container );

			case "db.FirstTimeNode":

				if( !onFirstTimeNode( cast node  ) )
				{
					var seen = seenNodes.indexOf( cast node.id ) != -1;

					if( !seen )
						seenNodes.push( cast node.id );

					var outputs = getOutputs( node, seen ? "repeat" : "first" );
					for( out in outputs )
						next( out );

				}

			case other:
				var field = Reflect.field(this, 'on${node.type}' );
				if( field == null )
				{
					Utils.error("Unknown node type: " + other);

					nextAll(node);
					return;
				}

				var handled = Reflect.callMethod(this, field, [node]);
				if( !handled )
					nextAll(node);
		}

	}

	public function jumpWithReturn( target: String )
	{
		stack.unshift( db.Butai.lookup(target) );
	}



	public function notifyReload()
	{
		Utils.writeLog("Node file reloaded from disk.");
		if( currentNode != null && ButaiDialogController.instance.busy )
		{
			Utils.writeLog('Cancelling active dialog and jumping back to ${currentNode.id}');
			ButaiDialogController.instance.forceHide();
			jump( cast lastDialogueNode.id );
		}
	}

	public function tick( delta: Float )
	{

		if( paused )
			return;

		next( currentNode );

		if( currentNode == null && stack.length > 0 )
		{
			var node = stack.shift();
			next( node );
			//var outputs = getOutputs( node );
			//for( out in outputs )

		}

		if( currentNode == null && conditions.length > 0 )
		{
			for( instruction in conditions )
			{
				var script = instruction.script;

				try
				{

					var program = parser.parseString(script);

					var result : Bool = interp.execute(program);

					var outputs = getOutputs( instruction, result ? "true" : "false" );
					for( out in outputs )
					{
						disableCondition( cast instruction.id );
						next( out );
					}

					if( currentNode != null )
						break;
				}
				catch( e: Dynamic )
				{
					Utils.warning('Error in condition ${instruction.id}: ${e}');
					Utils.warning('Disabling condition ${instruction.id} to prevent further errors.');
					disableCondition( cast instruction.id );
				}


			}
		}
	}

	public function enableCondition( id: String )
	{
		var condition = db.Butai.lookup( id );
		if( condition == null )
		{
			Utils.assert(false, "Cannot enable condition (missing): " + id);
			return;
		}

		if( conditions.indexOf( condition ) == -1 )
			conditions.push( condition );

	}

	public function disableCondition( id: String )
	{
		for( condition in conditions )
		{
			if( condition.id == id )
			{
				conditions.remove( condition );
				return;
			}
		}

	}

	public function seenNode( nodeid: String )
	{
		return seenNodes.indexOf(nodeid) != -1 ? true : false;
	}
}

typedef GameStateType = {
	testVal: String,
}

class ButaiSupport
{

	public static function changeScene( className: String )
	{
		#if client
		Main.currentScene.switchToNewScene( className );
		#end
	}
}