package cerastes;

#if sys
import sys.io.File;
import sys.FileSystem;
#end
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import haxe.io.Path;
import cerastes.Utils;

enum abstract GameSaveType(Int)
{
	var Normal 	= 1;
	var Auto 	= 2;
	var Dev		= 3;

	var CustomTypesStart = 100;
}

class SaveLoad
{

	public function new()
	{

	}

	public function getSaveInfo( slot: Int, ?type: GameSaveType = Normal )
	{
		return null;
	}

	function getSaveFileName( slot: Int, type: GameSaveType )
	{
		var t = switch( type )
		{
			case Normal: "";
			case Auto: "_auto";
			case Dev: "_dev";

			default: "_other";
		}
		return 'sav${slot}${t}.sav';
	}

	function saveFolder()
	{
		#if sys
		var flags = cerastes.Native.CSIDL.CSIDL_LOCAL_APPDATA | cerastes.Native.CSIDL.CSIDL_FLAG_CREATE;
		Utils.info(cerastes.Native.getFolderPath( flags ));
		return Path.join( [ cerastes.Native.getFolderPath( flags ) ,'cerastes', 'saves']);
		#else
		return "";
		#end
	}

	public function save( slot: Int, ?type: GameSaveType = Normal )
	{
	}

	public function load( slot: Int, ?type: GameSaveType = Normal )
	{
	}

}