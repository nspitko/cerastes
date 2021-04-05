package cerastes.butai;

import haxe.Json;
#if hl
import sys.net.Socket;
#end
import game.GameState;
import cerastes.ui.Console.GlobalConsole;
import cerastes.butai.ButaiTypeBuilder.ButaiNode;
import cerastes.butai.ButaiDialogController;
import db.Butai;
import db.Data;

typedef DebugMessage = {
	var m: String;
	var v: String;
}

@:build(cerastes.macros.Callbacks.ButaiCallbackGenerator.build("res/nodes.bdef"))
@:build(cerastes.macros.Callbacks.CallbackGenerator.build())
class ButaiNodeManager
{
	static  inline var prefix = "db.";
	private  static var currentNode : ButaiNode;
	private  static var lastDialogueNode : ButaiNode;

	private static var parser = new hscript.Parser();
	private static var interp = new hscript.Interp();

	private static var conditions = new Array< db.Butai.ConditionNode >();

	private static var stack = new Array< ButaiNode >();

	private static var paused = true;

	private static var scanOnly = false;

	public static var lastCG = "";

	#if hl
	public static var debugSocket : Socket;
	#end

	public static var seenNodes : Array<String>;

	public static function setup( node : ButaiNode )
	{
		if( node == null )
		{
			Utils.error("Setup calle with invalid node; File didn't load?");
			return;
		}

		trace(node);

		registerWithDebugServer();
		reset();

		interp.variables.set("GameState", GameState );
		interp.variables.set("Std", Std );

		interp.variables.set("changeScene", ButaiSupport.changeScene );

		interp.variables.set("addItem", GameState.addItem );
		interp.variables.set("hasItem", GameState.hasItem );
		interp.variables.set("consumeItem", GameState.removeItem );
		interp.variables.set("removeItem", GameState.removeItem );

		interp.variables.set("set", GameState.set );
		interp.variables.set("get", GameState.get );
		interp.variables.set("seenNode", ButaiSupport.seenNode );

		if( ButaiDialogController.instance == null )
			ButaiDialogController.instance = new ButaiDialogController();

		// pre-emptively register CDB types with blank units. these will get overwritten by the latest instances later
		//for( unit in Data.units.all )
		{
			//registerVariable( "units" , null );
		}

		currentNode = node;
		stack = [];
	}

	public static function registerWithDebugServer()
	{
		#if hl
		try
		{
			debugSocket = new Socket();
			debugSocket.connect(new sys.net.Host("localhost"),5121);
			debugSocket.output.writeString(Json.stringify({ 'm':"Connect" })+ "\n");
			debugSocket.setBlocking(false);
			Utils.notice("Connected to debug server");
		}
		catch(e : Dynamic)
		{
			Utils.info("Unable to connect to debug server.");
			debugSocket = null;
		}
		#end

	}

	public static function debugUpdate(m: String, value: String)
	{
		#if hl
		if(debugSocket  != null )
		{
			var msg : DebugMessage = {
				m: m,
				v: value
			}
			try {
				debugSocket.output.writeString(Json.stringify(msg) + "\n");
			}
			catch(e: Dynamic)
			{
				Utils.warning("Lost connection to debug server");
				try{
					debugSocket.close();
					registerWithDebugServer();
				}
				catch(e: Dynamic)
				{
					Utils.warning("Unable to reconnect.");
				}

			}
		}
		#end
	}

	public static function registerVariable(name: String, variable: Dynamic)
	{
		interp.variables.set(name, variable );
	}
	public static function unregisterVariable( name: String )
	{
		interp.variables.remove( name );
	}

	public static function reset()
	{
		seenNodes = new Array<String>();
		currentNode = null;
		stack = [];
		GameState.reset();
		resume();
	}


	public static function resume()
	{
		paused = false;
	}

	public static function pause()
	{
		paused = true;
	}

	public static function jump( node: String )
	{
		var target = db.Butai.lookup( node );
		if( target == null )
		{
			Utils.assert(false,"Invalid hard jump: " + node);
			return;
		}
		next( db.Butai.lookup( node ) );
	}

	private static function getInputs( node : ButaiNode, ?pin: String ) : Array< ButaiNode >
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

	public static function getOutputs( node : ButaiNode, ?pin: String ) : Array< ButaiNode >
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

	static function nextAll( node )
	{
		var outputs = getOutputs( node );
		for( out in outputs )
			next( out );
	}

	// Processes the currentNode and sets the next one.
	// We have to set next node while processing due to condition blocks.
	public static function next( node : ButaiNode )
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

		debugUpdate('cn',cast node.id);



		switch( Type.getClassName(Type.getClass(node )) )
		{
			case "db.SceneNode":
				var sceneNode : db.Butai.SceneNode = cast node;
				Utils.info("Changing scene: " + sceneNode.scene );
				ButaiSupport.changeScene( sceneNode.scene );

				if( !onSceneNode(cast node) )
					nextAll( node );




			case "db.MusicNode":

				var mpn : db.Butai.MusicNode = cast node;
				SoundManager.playMusic( mpn.file );

				if( !onMusicNode( mpn ) )
					nextAll( node );

			case "db.SFXNode":

				var mpn : db.Butai.SFXNode = cast node;
				SoundManager.sfx( mpn.file, mpn.loop == "1" );

				if( !onSFXNode( mpn ) )
					nextAll( node );

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
				catch( e: Dynamic )
				{
					Utils.warning('Error in instruction ${instruction.id}: ${e}');
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
				var field = Reflect.field(ButaiNodeManager, 'on${node.type}' );
				if( field == null )
				{
					Utils.error("Unknown node type: " + other);
					nextAll(node);
					return;
				}

				var handled = Reflect.callMethod(ButaiNodeManager, field, []);
				if( !handled )
					nextAll(node);
		}

	}

	public static function jumpWithReturn( target: String )
	{
		stack.unshift( db.Butai.lookup(target) );
	}

	public static function debugReadSocket()
	{
		#if hl
		try
		{
			return debugSocket.input.readLine();
		}
		catch( e: Dynamic )
		{
			return "";
		}
		#end
	}

	public static function checkDebugSocket()
	{
		#if hl
		if( debugSocket != null )
			{
				var data = debugReadSocket();
				if( data.length > 0 )
				{
					var cmd : DebugMessage = Json.parse(data);
					switch( cmd.m )
					{
						case "j":
							ButaiDialogController.instance.forceHide();
							jump(cmd.v);
							return;
						default:
							Utils.warning('Unhandled debug command: ${cmd.m}: ${cmd.v}');
					}
				}
			}
		#end
	}

	public static function notifyReload()
	{
		Utils.writeLog("Node file reloaded from disk.");
		if( currentNode != null && ButaiDialogController.instance.busy )
		{
			Utils.writeLog('Cancelling active dialog and jumping back to ${currentNode.id}');
			ButaiDialogController.instance.forceHide();
			jump( cast lastDialogueNode.id );
		}
	}

	public static function tick( delta: Float )
	{
		if( ButaiDialogController.instance != null )
			ButaiDialogController.instance.tick( delta );
		checkDebugSocket();


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

	public static function enableCondition( id: String )
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

	public static function disableCondition( id: String )
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

	public static function seenNode( nodeid: String )
	{
		return ButaiNodeManager.seenNodes.indexOf(nodeid) != -1 ? true : false;
	}
}