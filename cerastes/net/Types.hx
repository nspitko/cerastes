package cerastes.net;
import haxe.ds.Vector;
#if server
import server.ClientBehavior;
#end
import haxe.io.Bytes;
import cerastes.net.Replicated;

@:generic
class ReplicatedVector<T>
{
	private var vector : Vector<T>;
	private var isDirty: Bool = false;

	public inline function new(len: Int)
	{
		vector = new Vector<T>(len);
	}

	@:arrayAccess public inline function setVal(index:Int, val:T)
	{
		isDirty = true;
		return vector.set(index,val);
	}

	@:arrayAccess public inline function getVal(index:Int, val:T)
	{
		return vector.get(index);
	}

}

enum abstract Chunk(Int) from Int to Int {
	var Invalid			= 0;
	var FullEntities 	= 1; // Full sync of an entity, including data for creation
	var DeltaEntities 	= 2; // Deltas from last update
	var RemoveEntities 	= 3; // Entities for removal
	var RPCRequest		= 4; // RPC requests
	var RPCResponse		= 5; // RPC response data
}

typedef RPCCall = {
	var methodId: Int;
	var target: Replicated;
	var ?callId: Int; // Optional because the RPC manager will fill it out later
	var args: haxe.ds.Vector<Dynamic>;
	#if server
	var ?callback: (ClientBehavior, Bytes, Int ) -> Int;
	#else
	var ?callback: (Bytes, Int ) -> Int;
	#end
	var ?serialize: (Bytes, Int, RPCCall ) -> Int;
}

typedef RPCResponse = {
	var callId: Int;
	var response: Dynamic;
	var serializer: (Bytes, Int) -> Int;
}