package cerastes.fmt;
#if macro
import hxd.res.Config;
#end

class CerastesResources
{
	#if macro
	public static function build()
	{
		Config.extensions["csd"] = "cerastes.fmt.SpriteResource";
	}
	#end
}