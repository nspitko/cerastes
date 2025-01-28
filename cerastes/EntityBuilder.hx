package cerastes;

import cerastes.file.CDParser;
import cerastes.Entity.EntityFile;
import cerastes.Entity.EntityDef;
import haxe.ds.Map;

@:keep
@:native("EntityBuilderProxy")
class EntityBuilder
{
	extern public static var defMap: Map<String, cerastes.Entity.EntityDef>;

	extern public static function init( files: Array<String> ) : Void;
	extern static function parseFile( file: String ): Void;

	extern public static function create( def: EntityDef ) : Entity;
	extern public static function list( filter: Class<cerastes.Entity.EntityDef> ) : Array<String>;

}