package cerastes.net;

#if server
import server.ClientManager;
import server.ClientBehavior;
#end
import cerastes.Entity.EntityManager;
import cerastes.net.Types.Chunk;
import haxe.io.Bytes;
import cerastes.Utils.*;
import cerastes.net.Types.RPCCall;
import cerastes.net.Types.RPCResponse;

class RPC
{



	#if client
	// RPC calls that haven't been sent yet
	public static var outboundRPC = new Array<RPCCall>();
	// RPC calls that have been sent but we're still waiting on a reply
	public static var pendingRPC = new Map<Int, RPCCall>();

	public static var rpcResponses = new Array<RPCResponse>();
	#end


	static var rpcID = 0;

	public static function registerRPC( rpc: RPCCall )
	{
//		info("Registering RPC...");

		#if server

		for( client in ClientManager.clients )
		{
			var clone = Reflect.copy(rpc);
			clone.callId = 0;
			while( client.pendingRPC.exists( clone.callId ) )
			{
				rpcID = ( rpcID + 1 ) % 255;
				clone.callId = rpcID;
			}
			client.outboundRPC.push(clone);
			client.pendingRPC.set(clone.callId, clone);
		}

		#else
		while( pendingRPC.exists( rpc.callId ) )
		{
			rpcID = ( rpcID + 1 ) % 255;
			rpc.callId = rpcID;
		}
		outboundRPC.push(rpc);
		pendingRPC.set(rpc.callId, rpc );

		#end

	}

	#if server
	public static function registerRPCResponse( client: ClientBehavior, ret: RPCResponse )
	{
		client.rpcResponses.push(ret);
	}
	#else
	public static function registerRPCResponse( ret: RPCResponse )
	{
		rpcResponses.push(ret);
	}

	#end

	#if server
	public static function parseRPCRequestBuffer( client: ClientBehavior, buffer: Bytes, pos: Int )
	#else
	public static function parseRPCRequestBuffer( buffer: Bytes, pos: Int )
	#end
	{
		pos++; // we're always given the full buffer, skip past the type byte
		var count = buffer.get( pos++ );

		var i = 0;
		while( i++ < count )
		{
			// Header
			var callId = buffer.get( pos++ );
			var methodId = buffer.get( pos++ );
			var targetId = buffer.getUInt16( pos ); pos += 2;


			// @todo

			var found = false;
			for( e in EntityManager.instance.entities )
			{
				if( e._repl_netid == targetId )
				{
					found = true;
					#if client
					pos = e._rpc_handleRequest( buffer, pos, methodId, callId );
					#elseif server
					pos = e._rpc_handleRequest( client, buffer, pos, methodId, callId );
					#end
					break;
				}
			}

			if( !found )
			{
				warning("Could not find target entity in RPC call, buffer is corrupt");
				return -1;
			}


		}

		return pos;
	}

	#if server
	public static function parseRPCResponseBuffer( client: ClientBehavior, buffer: Bytes, pos: Int )
	#else
	public static function parseRPCResponseBuffer( buffer: Bytes, pos: Int )
	#end
	{
		#if server
		var pendingRPC = client.pendingRPC;
		#end

		pos++; // we're always given the full buffer, skip past the type byte
		var count = buffer.get( pos++ );
		//info("Got an RPC response");

		var i = 0;
		while( i++ < count )
		{
			var callId = buffer.get( pos++ );
			if( !pendingRPC.exists( callId ) )
			{
				warning('Got unexpected RPC response ${callId}; buffer is now corrupt.');
				return -1;
			}
			var startPos = pos;
			var rpc = pendingRPC.get( callId );
			pos = rpc.callback( #if server client,#end buffer, pos  );
			pendingRPC.remove( callId );
			//info('Handled RPC request in ${pos - startPos} bytes');
		}

		return pos;
	}

	#if server
	public static function buildRPCBuffer(client: ClientBehavior, buffer: Bytes, pos: Int) : Int
	#else
	public static function buildRPCBuffer(buffer: Bytes, pos: Int) : Int
	#end
	{
		#if server
		var outboundRPC = client.outboundRPC;
		#end

		if( outboundRPC.length == 0 )
			return pos;

		//info("Building an RPC outbound buffer");


		if( outboundRPC.length > 255 )
			throw "Too many pending RPC calls pending";

		buffer.set(pos++, Chunk.RPCRequest );
		buffer.set(pos++, outboundRPC.length );

		for( rpc in outboundRPC )
		{
			pos = rpc.serialize(buffer, pos, rpc );
		}

		untyped outboundRPC.length = 0;

		return pos;
	}

	#if server
	public static function buildRPCResponseBuffer(rpcResponses: Array<RPCResponse>, buffer: Bytes, pos: Int) : Int
	#else
	public static function buildRPCResponseBuffer(buffer: Bytes, pos: Int) : Int
	#end

	{
		if( rpcResponses.length == 0 )
			return pos;

		//info("Building an RPC response outbound buffer");


		if( rpcResponses.length > 255 )
			throw "Too many pending RPC responses pending";

		buffer.set(pos++, Chunk.RPCResponse );
		buffer.set(pos++, rpcResponses.length );

		for( rpc in rpcResponses )
		{
			buffer.set( pos++, rpc.callId );
			pos = rpc.serializer(buffer, pos );
		}

		untyped rpcResponses.length = 0;

		return pos;
	}
}