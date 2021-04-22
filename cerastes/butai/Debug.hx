
package cerastes.butai;

import haxe.Json;

#if hl
import sys.net.Socket;
#end

typedef DebugMessage = {
	var m: String;
	var v: String;
	var p: String;
}

@:build(cerastes.macros.Callbacks.CallbackGenerator.build())
class Debug
{
	#if hl
	public static var debugSocket : Socket;
	#end

	public static function init()
	{
		registerWithDebugServer();
	}


	public static function registerWithDebugServer()
	{
		#if hl
		//try
		{
			debugSocket = new Socket();
			debugSocket.connect(new sys.net.Host("localhost"),5121);
			debugSocket.output.writeString(Json.stringify({ 'm':"Connect" })+ "\n");
			debugSocket.setBlocking(false);
			Utils.notice("Connected to debug server");
		}
		/*catch(e : Dynamic)
		{
			Utils.info('Unable to connect to debug server: ${e}');
			debugSocket = null;
		}*/
		#end

	}

	public static function debugUpdate(m: String, value: String, ?p: String = "Main")
	{
		#if hl
		if(debugSocket  != null )
		{
			var msg : DebugMessage = {
				m: m,
				v: value,
				p: p
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

	public static function debugWrite(m: String, value: String, ?p: String = "Main")
	{
		debugUpdate(m, value, p);
	}

	@:callbackStatic
	public static function onDebugMsg(msg: DebugMessage): Bool;


	static function debugReadSocket()
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

	static function checkDebugSocket()
	{
		#if hl
		if( debugSocket != null )
		{
			var data = debugReadSocket();
			if( data.length > 0 )
			{
				var cmd : DebugMessage = Json.parse(data);
				var handled = onDebugMsg( cmd );
				if( !handled )
					Utils.warning('Unhandled debug command: ${cmd.m}: ${cmd.v}');

			}
		}
		#end
	}

	public static function tick( delta: Float )
	{
		checkDebugSocket();
	}
}