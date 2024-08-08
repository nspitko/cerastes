package cerastes;


import hxd.PixelFormat;
import hxd.Pixels;
import h2d.Tile;
import cerastes.fmt.AtlasResource;
import cerastes.fmt.AtlasResource.AtlasEntry;
import h3d.mat.Texture;
import hxd.fmt.pak.FileSystem;
#if hldx
import dx.Driver.ResourceBind;
#end
import haxe.io.Path;
#if hlsdl
import sdl.Sdl;
#end
import cerastes.butai.Debug;
import haxe.Json;
#if hl
import sys.io.FileOutput;
import sys.io.File;
#end

#if client
import cerastes.ui.Console.GlobalConsole;
#end

enum abstract Spew(Int) {
	var ALWAYS = 0;
	var ERROR = 1;
	var WARNING = 2;
	var ASSERT = 3;
	var INFO = 4;
	var DEBUG = 5;
	var SPAM = 6;
	var NEVER = 7;
}

@:structInit
class LogLine
{
	public var level: Spew;
	public var pos: haxe.PosInfos;
	public var line: String;
	public var time: Float;
}

class Utils
{
	public static var BREAK_ON_ERROR = false;
	public static var BREAK_ON_WARNING = false;
	public static var WRITE_LOG = false;

	public static var LOG_LEVEL = 0;
	public static var SHOW_BULLET_AABBS = false;

	#if hl
	public static var logFile : FileOutput = null;
	#end

	private static var startTime : Float = 0;

	#if hlimgui
	private static var log: Array<LogLine> = [];
	private static var logStart: Float = -1;
	#end

	static var recentLogs: Array<String> = [];


	public static function writeLog(str: String, ?level: Spew, ?pos:haxe.PosInfos, ?always = false )
	{
		if( !always )
		{
			if( recentLogs.indexOf(str) != -1 )
				return;

			recentLogs.push(str);
			if( recentLogs.length > 10 )
				recentLogs.shift();
		}

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

		#if hlimgui

		if( logStart == -1 )
			logStart = haxe.Timer.stamp();

		log.push( {
			line: str,
			level: level,
			pos: pos,
			time: haxe.Timer.stamp() - logStart
		} );
		#end


		haxe.Log.trace( str, pos );
	}

	/**
	 * Debug assert: Removed on release builds for MAXIMUM SPEEEEEEED
	 * @param condition
	 * @param msg
	 * @param pos
	 */
	public static inline function debugAssert( condition: Bool, msg: String, ?pos:haxe.PosInfos )
	{
		#if debug
		if( !condition )
		{
			writeLog('Assertion failed: ${msg} ', ASSERT, pos);

			#if ( butai && hl )
			var json = Json.stringify({
				line: pos.lineNumber,
				text: msg,
				"function": pos.methodName,
				file: pos.fileName,
				time: hxd.Timer.elapsedTime,
				level: Spew.ASSERT
			});
			Debug.debugWrite("log",json);
			#end

			#if hl
			if( WRITE_LOG )
				logFile.flush();
			#end
			#if ( !noassert && hl )
				hl.Api.breakPoint();
			#end
		}
		#end
	}

	public static inline function assert( condition: Bool, ?msg: String, ?pos:haxe.PosInfos )
	{
		if( msg == null )
			msg = "Assertion failed";

		if( !condition )
		{
			writeLog('Assertion failed: ${msg} ', ASSERT, pos);

			#if ( butai && hl )
			var json = Json.stringify({
				line: pos.lineNumber,
				text: msg,
				"function": pos.methodName,
				file: pos.fileName,
				time: hxd.Timer.elapsedTime,
				level: Spew.ASSERT
			});
			Debug.debugWrite("log",json);
			#end

			#if hl
			if( WRITE_LOG )
				logFile.flush();
			#end
			#if ( !noassert && hl )
				hl.Api.breakPoint();
			#end
		}
	}

	public static inline function verify( condition: Bool, ?msg: String, ?pos:haxe.PosInfos )
	{
		if( msg == null )
			msg = "Assertion failed";

		if( !condition )
		{
			writeLog('Assertion failed: ${msg} ', ASSERT, pos);

			#if ( butai && hl )
			var json = Json.stringify({
				line: pos.lineNumber,
				text: msg,
				"function": pos.methodName,
				file: pos.fileName,
				time: hxd.Timer.elapsedTime,
				level: Spew.ASSERT
			});
			Debug.debugWrite("log",json);
			#end

			#if hl
			if( WRITE_LOG )
				logFile.flush();
			#end
			#if ( !noassert && hl )
				hl.Api.breakPoint();
			#end
		}

		return condition;
	}

	public static function warning( msg: String, ?pos:haxe.PosInfos )
	{
		writeLog('Warning: ${msg} ', WARNING, pos);
		#if hl
		if( WRITE_LOG )
			logFile.flush();
		#end
		#if ( butai && hl )
		var json = Json.stringify({
			line: pos.lineNumber,
			text: msg,
			"function": pos.methodName,
			file: pos.fileName,
			time: hxd.Timer.elapsedTime,
			level: Spew.WARNING
		});
		Debug.debugWrite("log",json);
		#end
		if( BREAK_ON_WARNING )
		{
			#if hl
				hl.Api.breakPoint();
			#end
		}
		#if debug
		#if client
		//GlobalConsole.console.externalLog("Warning: " + msg, 0xFFFF00);
		#end
		#end
	}

	public static function error( msg: String, ?pos:haxe.PosInfos )
	{
		writeLog('ERROR: ${msg} ', ERROR, pos);
		#if hl
		if( WRITE_LOG )
			logFile.flush();
		#end
		#if ( butai && hl )
		var json = Json.stringify({
			line: pos.lineNumber,
			text: msg,
			"function": pos.methodName,
			file: pos.fileName,
			time: hxd.Timer.elapsedTime,
			level: Spew.ERROR
		});
		Debug.debugWrite("log",json);
		#end
		if( BREAK_ON_ERROR )
		{
			#if hl
				hl.Api.breakPoint();
			#end
		}
		#if client
		GlobalConsole.console.externalLog("Error: " + msg, 0xFF0000);
		#end

	}

	public static function info( msg: String, ?loglevel: Int, ?pos:haxe.PosInfos )
	{
		if( startTime == 0 )
			startTime = haxe.Timer.stamp();

		//[${ Math.round( haxe.Timer.stamp() - startTime ) }]
		#if ( butai && hl )
		var json = Json.stringify({
			line: pos.lineNumber,
			text: msg,
			"function": pos.methodName,
			file: pos.fileName,
			time: hxd.Timer.elapsedTime,
			level: Spew.INFO
		});
		Debug.debugWrite("log",json);
		#end

		// Always write duplicate log entries.
		writeLog('${msg} ', INFO, pos, true);
	}

	/**
	 * Notices always show, but aren't considered errors.
	 * @param msg
	 * @param pos
	 */
	public static function notice( msg: String, ?pos:haxe.PosInfos )
	{
		writeLog('NOTICE: ${msg} ', ALWAYS, pos);
		#if hl
		if( WRITE_LOG )
			logFile.flush();
		#end
		#if client
		#if debug
		if( GlobalConsole != null &&  GlobalConsole.console != null )
			GlobalConsole.console.externalLog(msg, 0xFFFFFF);
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

	public static function getDPIScaleFactor() : Float
	{
		var scale: Float = 1;
		var size: Int = 0;
		#if hlsdl
		size = Sdl.getScreenHeight();
		#elseif hldx
		size = dx.Window.getScreenHeight();
		#end

		if( size > 1200 )
		{
			scale = 1.25;

			if( size >= 2160 )
				scale = 1.5;

		}
		return scale;

	}



	#if ( client && domkit )
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

	public static function toLocalFile( file: String )
	{
		// Fixup cursed windows bullshit
		file = StringTools.replace(file, "\\", "/");

		var resDir : String = haxe.macro.Compiler.getDefine("resourcesPath");
		if( resDir == null ) resDir = "res";
		var idx =  file.indexOf(resDir);
		if( idx == -1 ) return null;

		return file.substring(idx + resDir.length + 1 );
	}

	public static function fixWritePath(path: String, ?enforceExtension: String = null )
	{
		#if sys
		// Don't fixup abs paths
		if( !Path.isAbsolute(path) )
		{
			var resDir = haxe.macro.Compiler.getDefine("resourcesPath");
			if( resDir == null ) resDir = "res";


			// Add res path if it's missing
			var resPos = path.indexOf('/$resDir/');
			if( resPos == -1 )
			{
				path = Path.join([resDir,path]);
			}
		}
		if( enforceExtension != null && Path.extension(path) != enforceExtension )
		{
			path = Path.withExtension( Path.withoutExtension( path ), enforceExtension );
		}

		return sys.FileSystem.fullPath( path );

		#else
		Utils.warning("Trying to fix write path on non-sys target???");
		return path;
		#end
	}

	private static var missingTexture: Texture;
	private static var missingTile: h2d.Tile;
	private static var missingAtlas: AtlasEntry;
	private static var missingPixels: Pixels;

	public static function invalidTexture()
	{
		if( missingTexture == null )
			missingTexture = Texture.fromPixels( invalidPixels() );

		return missingTexture;
	}

	public static function invalidPixels()
	{
		if( missingPixels == null )
		{
			final size = 64;
			final block = 16;
			var e = false;

			missingPixels = Pixels.alloc(size,size, PixelFormat.ARGB);
			var access:hxd.Pixels.PixelsARGB = missingPixels;
			for( y in 0 ... cast ( size / block ) )
			{
				e = !e;
				for( x in 0 ... cast ( size / block ) )
				{
					var px = x * block;
					var py = y * block;
					e = !e;
					for( lpx in px ... px + block )
					{
						for( lpy in py ... py + block )
						{
							access.setPixel(lpx, lpy, e ? 0x000000FF : 0xFF00FFFF );
						}
					}
				}
			}
			missingPixels.convert( RGBA );
		}

		return missingPixels;
	}

	public static function invalidTile()
	{
		if( missingTile == null )
			missingTile = h2d.Tile.fromTexture( invalidTexture() );

		return missingTile;
	}

	public static function invalidAtlas()
	{
		if( missingAtlas == null )
		{
			var atlas: Atlas = {
				tile: invalidTile()
			};
			var frame: AtlasFrame = {
				pos: {x: 0, y: 0},
				offset: {x: 0, y: 0},
				size: {x: 1, y: 1},
				atlas: atlas,
			};
			missingAtlas = {
				frames: [
					frame
				],
				size: {x: 10, y: 10 },
				bbox: {x: 10, y: 10 },
				origin: {x: 0, y: 0},
				name: "Invalid",
			};
		}

		return missingAtlas;
	}

	public static function resolveTexture( file: String ): Texture
	{
		if( file == null || file == "")
			return invalidTexture();

		if(file.charAt(0) == "#" )
		{
			return Texture.fromColor( Std.parseInt( '0x${file.substr(1)}' ) );
		}
		else
		{
			if( !hxd.Res.loader.exists(file) )
				return invalidTexture();

			var res = hxd.Res.loader.loadCache( file, hxd.res.Image );
			if( res == null )
				return invalidTexture();

			return res.toTexture();
		}

	}

	public static function getAtlasEntry( file: String ) : AtlasEntry
	{
		if( file == null || file == "")
			return null;

		if ( file.indexOf(".catlas") != -1 )
		{
			var atlasPos = file.indexOf(".catlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, AtlasResource );
			if( res != null )
			{
				var entry = res.getData().entries[tileName];
				if( entry == null )
					return null;

				return entry;
			}
		}

		return null;
	}

	public static function isValidTexture( file: String ): Bool
	{
		if( file == null || file == "")
			return false;

		if(file.charAt(0) == "#" && file.length >= 7 )
			return true;

		if( hxd.Res.loader.exists( file ) )
			return true;

		return false;
	}

	public static function isValidMaterial( file: String ): Bool
	{
		if( file == null || file == "")
			return false;

		if( hxd.Res.loader.exists( file ) )
			return true;

		return false;
	}

	public static function getCoreCount()
	{
		return 15; // Hack
	}

	public static function getFont( file: String, ?e: { sdfSize: Int, sdfAlpha: Float, sdfSmoothing: Float } ) : h2d.Font
	{
		// Font shenanigans
		var isSDF = StringTools.endsWith( file, ".msdf.fnt" );

		if( !isSDF )
		{
			return hxd.Res.loader.loadCache( file, hxd.res.BitmapFont).toFont();
		}
		else if( e != null )
		{
			return hxd.Res.loader.loadCache( file, hxd.res.BitmapFont).toSdfFont(e.sdfSize,4,e.sdfAlpha,1/e.sdfSmoothing);
		}

		return hxd.res.DefaultFont.get();
	}

	public static function getTile( file: String )
	{
		if( file == null || file == "")
			return null;

		if(file.charAt(0) == "#" )
			return Tile.fromColor( Std.parseInt( '0x${file.substr(1)}' ) );
		else if ( file.indexOf(".catlas") != -1 )
		{
			var atlasPos = file.indexOf(".catlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, AtlasResource );
			if( res != null )
			{
				var entry = res.getData().entries[tileName];
				if( entry == null )
					return Utils.invalidTile();

				return entry.tile;
			}
		}
		else if ( file.indexOf(".atlas") != -1 )
		{
			var atlasPos = file.indexOf(".atlas") + 6;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, hxd.res.Atlas );
			if( res != null )
				return res.get( tileName );
		}
		else
		{
			try
			{
				var res = hxd.Res.loader.loadCache( file, hxd.res.Image );
				if( res == null || res.entry.isDirectory )
					return null;

				return res.toTile();
			}
			catch(e)
			{
				return null;
			}
		}

		return null;

	}

	public static function getTiles( file: String ): Array<Tile>
	{
		if( file == null || file == "")
			return [ Utils.invalidTile() ];

		if(file.charAt(0) == "#" )
			return [ Tile.fromColor( Std.parseInt( '0x${file.substr(1)}' ) ) ];
		else if ( file.indexOf(".catlas") != -1 )
		{
			var atlasPos = file.indexOf(".catlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, AtlasResource );
			if( res != null )
			{
				var entry = res.getData().entries[tileName];
				if( entry == null )
					return [ Utils.invalidTile() ];

				return entry.tiles;
			}
		}
		else if ( file.indexOf(".atlas") != -1 )
		{
			var atlasPos = file.indexOf(".atlas") + 7;
			var atlasName = file.substr( 0, atlasPos );
			var tileName = file.substr(atlasPos + 1);

			var res = hxd.Res.loader.loadCache(atlasName, hxd.res.Atlas );
			if( res != null )
				return res.getAnim( tileName );
		}
		else
		{
			var res = hxd.Res.loader.loadCache( file, hxd.res.Image );
			if( res == null || res.entry.isDirectory )
				return null;

			return [ res.toTile() ];
		}

		return [ Utils.invalidTile() ];

	}

	public static function clone( source: Dynamic )
	{
		var cls = Type.getClass(source);
		var inst = Type.createEmptyInstance(cls);
		var fields = Type.getInstanceFields(cls);
		for (field in fields)
		{

			// generic copy
			var val:Dynamic = Reflect.field(source,field);
			if ( !Reflect.isFunction(val) )
			{
				Reflect.setField(inst,field,val);
			}

		}

		return inst;
	}
}