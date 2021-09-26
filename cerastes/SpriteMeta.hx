package cerastes;

@:native("cerastes.SpriteMetaProxy")
class SpriteMeta
{
	extern public static function getClassList() : Map<String, Array<cerastes.macros.SpriteData.SpriteDataItem>>;
}