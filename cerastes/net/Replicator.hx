package cerastes.net;
import haxe.io.Bytes;
#if macro
import haxe.macro.Context.*;
using haxe.macro.Tools;
#end

@:native("ReplicatorProxy")
class Replicator
{
	public static function create( id: Int ) : Replicated
	{
		trace("STUB");
		return null;
	}
}

