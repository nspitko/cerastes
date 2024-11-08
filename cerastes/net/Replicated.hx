package cerastes.net;
#if server
import server.ClientBehavior;
#end
import hl.I64;
import cerastes.Entity.EntityManager;
import hl.UI16;
import haxe.io.Bytes;


@:keepSub @:autoBuild(cerastes.net.Macros.ProxyGenerator.build())
interface Replicated
{
	@:noCompletion public var _repl_netid : UI16;


	// Everything below here is implemented by the autobuild macro. Do not manually
	// implement them unless you wanna have a bad time


	// repl
	@:noCompletion public function _repl_isDirty() : Bool;
	@:noCompletion public function _repl_unserialize(buffer: Bytes, pos: Int, ?full: Bool = false) : Int;
	@:noCompletion public function _repl_serialize(buffer: Bytes, pos: Int, ?full: Bool = false) : Int;
	@:noCompletion public function _repl_clsid() : Int;
	@:noCompletion public function _repl_reset() : Void;

	#if client
	// Called when the entity is created on the client (Previously: replicated())
	public function clientSpawn(): Void;
	// Called when the entity gets an update from the server. This is ONLY sent when the server sends
	// us new data about an entity! If nothing changes we will not get this call.
	public function clientUpdate(): Void;
	#end

	// RPC
	#if server
	@:noCompletion public function _rpc_handleRequest( client: ClientBehavior, buffer: Bytes, pos: Int, methodId: Int, callId: Int ) : Int;
	#else
	@:noCompletion public function _rpc_handleRequest( buffer: Bytes, pos: Int, methodId: Int, callId: Int ) : Int;
	#end

}