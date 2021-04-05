package cerastes;


#if hl
import sys.io.FileOutput;
import sys.io.File;
#end

#if client
import cerastes.ui.Console.GlobalConsole;
#end
class Utils
{
	public static var BREAK_ON_ASSERT = true;
	public static var BREAK_ON_ERROR = false;
	public static var BREAK_ON_WARNING = false;
	public static var WRITE_LOG = false;

	public static var LOG_LEVEL = 0;
	public static var SHOW_BULLET_AABBS = true;

	#if hl
	public static var logFile : FileOutput = null;
	#end

	private static var startTime : Float = 0;

	public inline static function writeLog(str: String, ?pos:haxe.PosInfos )
	{
		//str = ( Main.host.isAuth ? "[S]" : "[C]" ) + str;
		#if hl
		if( WRITE_LOG )
		{
			if( logFile == null )
			{
				logFile = File.write("log.txt", false);
				logFile.writeString( "===== BEGIN ====\n");
				logFile.writeString( 'File opened ${Date.now().toString()}\n');
			}

			logFile.writeString( str + "\n");
		}
		#end



		haxe.Log.trace( str, pos );
	}

	public static inline function assert( condition: Bool, msg: String, ?pos:haxe.PosInfos )
	{
		if( !condition )
		{
			writeLog('Assertion failed: ${pos.fileName}:${pos.lineNumber}: ${msg} ', pos);
			#if hl
			if( WRITE_LOG )
				logFile.flush();
			#end
			if( BREAK_ON_ASSERT )
			{
				#if hl
					hl.Api.breakPoint();
				#end
			}
		}
	}

	public static function warning( msg: String, ?pos:haxe.PosInfos )
	{
		writeLog('Warning: ${pos.fileName}:${pos.lineNumber}: ${msg} ', pos);
		#if hl
		if( WRITE_LOG )
			logFile.flush();
		#end
		if( BREAK_ON_WARNING )
		{
			#if hl
				hl.Api.breakPoint();
			#end
		}
		#if debug
		#if client
		GlobalConsole.instance.console.log("Warning: " + msg, 0xFFFF00);
		#end
		#end
	}

	public static function error( msg: String, ?pos:haxe.PosInfos )
	{
		writeLog('ERROR: ${pos.fileName}:${pos.lineNumber}: ${msg} ', pos);
		#if hl
		if( WRITE_LOG )
			logFile.flush();
		#end
		if( BREAK_ON_ERROR )
		{
			#if hl
				hl.Api.breakPoint();
			#end
		}
		#if client
		GlobalConsole.instance.console.log("Error: " + msg, 0xFF0000);
		#end

	}

	public static function info( msg: String, ?loglevel: Int, ?pos:haxe.PosInfos )
	{
		if( startTime == 0 )
			startTime = haxe.Timer.stamp();

		//[${ Math.round( haxe.Timer.stamp() - startTime ) }]

		writeLog('INFO: ${msg} ', pos);
	}

	public static function notice( msg: String, ?pos:haxe.PosInfos )
	{
		writeLog('NOTICE: ${pos.fileName}:${pos.lineNumber}: ${msg} ', pos);
		#if hl
		if( WRITE_LOG )
			logFile.flush();
		#end
		#if client
		#if debug
		GlobalConsole.instance.console.log(msg, 0xFFFFFF);
		#end
		#end
	}

	public inline static function clamp(value:Float, min:Float, max:Float):Float
	{
		if (value < min)
			return min;
		else if (value > max)
			return max;
		else
			return value;
	}

	public inline static function clampInt(value:Int, min:Int, max:Int):Int
	{
		if (value < min)
			return min;
		else if (value > max)
			return max;
		else
			return value;
	}

	public inline function clampU(value: Float, max: Float): Float
	{
		if( value > max )
			return max;
		return value;
	}

	public inline static function round2( number : Float, precision : Int): Float {
		number = number * Math.pow(10, precision);
		number = Math.round( number ) / Math.pow(10, precision);
		return number;
	}

	public static function shuffleArray( arr : Array<Dynamic> )
	{
		for(i in 0...arr.length)
		{
			var a = arr[i];
			var b = Std.random( arr.length);
			arr[i] = arr[b];
			arr[b] = a;
		}
	}



	#if client
	public static function findElementTraverse( o: h2d.Object, id: String ) : Null<h2d.Object>
	{
		for( child in o.getChildren() )
		{
			if( child.dom != null && child.dom.id == id )
				return child;

			var o = findElementTraverse( child, id );
			if( o != null )
				return o;
		}

		return null;
	}
	#end
}