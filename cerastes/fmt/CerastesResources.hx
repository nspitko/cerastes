package cerastes.fmt;
#if macro
import hxd.res.Config;
#end

class CerastesResources
{
	#if macro
	public static function build()
	{
		#if spriteresource
		Config.extensions["csd"] = "cerastes.fmt.SpriteResource";
		#end
		#if cannonml
		Config.extensions["cbl"] = "cerastes.fmt.BulletLevelResource";
		#end
		Config.extensions["ui"] = "cerastes.fmt.CUIResource";
		#if flow
		Config.extensions["flow"] = "cerastes.fmt.FlowResource";
		#end
		Config.extensions["glb,gltf"] = "hxd.res.Model";

		Config.ignoredDirs["raw_sprites"] = true;


	}
	#end
}