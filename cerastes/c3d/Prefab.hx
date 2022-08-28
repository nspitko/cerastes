package cerastes.c3d;

import cerastes.c3d.Model.ModelDef;
import cerastes.file.CDPrinter;
import cerastes.file.CDParser;
import h3d.prim.ModelCache;
import h3d.scene.Object;
import hxd.res.Model;
import cerastes.c3d.Material.MaterialDef;

/**
 * Prefabs describe entities which are ready to be placed in the world.
 */

 enum TextureSlot
 {
	BASE;
	NORMAL;
	ROUGHNESS;
	EXTRA1;
	EXTRA2;
 }

@:enum
abstract BulletShape(Int) from Int to Int
{
	var Box = 0;
	var Sphere = 1;
	var Capsule = 2;

	var Max = 3;
}


@:structInit class ShapeDef
{
	public var shape: BulletShape;
	public var position: h3d.Vector;
	public var x1: h3d.Vector;
	public var x2: h3d.Vector;
	public var x3: h3d.Vector;
	public var x4: h3d.Vector;
}



@:structInit
class PrefabDef
{
	public var models: Array<ModelDef>;
	public var shapes: Array<ShapeDef>;

	public function save(file: String)
	{
		var kv = CDPrinter.print(this);
		#if sys
		sys.io.File.saveContent( Utils.fixWritePath(file,"prefab"),kv);
		#else
		Utils.error("Unhandled save on non-sys target");
		#end
	}

	public static function load( file: String )
	{
		return CDParser.parse( hxd.Res.load( file ).toText(), PrefabDef );
	}
}

class Prefab extends h3d.scene.Object
{
	static var cache: h3d.prim.ModelCache = new ModelCache();

	public function load( def: PrefabDef )
	{
		if( def.models != null )
		{
			for( m in def.models )
				addChild( m.toObject() );
		}
	}



}