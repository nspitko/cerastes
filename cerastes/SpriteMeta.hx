package cerastes;

import cerastes.Sprite.SpriteCache;
import cerastes.macros.SpriteData.SpriteDataItem;
#if spritemeta
@:native("cerastes.SpriteMetaProxy")
class SpriteMeta
{
	extern public static function getClassList() : Map<String, Array<cerastes.macros.SpriteData.SpriteDataItem>>;
	extern public static function create( cache: cerastes.Sprite.SpriteCache, ?parent: h2d.Object ) : Sprite;
}
#end