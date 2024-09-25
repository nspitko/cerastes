package cerastes.net;
import haxe.io.Bytes;
#if macro
import haxe.macro.Context.*;
using haxe.macro.Tools;
#end

@:native("ReplicatorProxy")
class Replicator
{
	extern public static function create( id: Int ) : Replicated;
}

