
package cerastes.c3d;

import cerastes.Entity.EntityManager;
#if bullet
import bullet.Native;
import bullet.Shape;
#end
import h3d.Matrix;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import cerastes.c3d.Prefab.PrefabDef;
import h3d.Vector;
import h3d.Quat;
import h3d.scene.World;
import h3d.scene.Object;

@:structInit
class PrefabEntry
{
	public var file: String;
	public var x: Float;
	public var y: Float;
	public var z: Float;
	public var rotation: Quat;
}

@:structInit
class GeoEntry
{
	public var file: String;
	public var transform: Matrix;
}

@:structInit
class WorldDef
{
	@serializeType("cerastes.c3d.PrefabEntry")
	public var prefabs: Array<PrefabEntry>;
	@serializeType("cerastes.c3d.GeoEntry")
	public var geo: Array<GeoEntry>;

	public function save(file: String)
	{
		var kv = CDPrinter.print(this);
		sys.io.File.saveContent( Utils.fixWritePath(file,"world"),kv);
	}

	public static function load( file: String )
	{
		return CDParser.parse( hxd.Res.load( file ).toText(), WorldDef );
	}
}

class World extends Object
{
	#if bullet
	public var physics: BulletWorld;
	public static var physicsMaxSubSteps = 1;

	#end

	public var entityManager: EntityManager;

	public function new( ?parent: Object )
	{
		super( parent );
		#if bullet
		physics = new BulletWorld(this);
		physics.setGravity(0,0,-9.8);
		#end

		entityManager = new EntityManager();
	}

	public function tick(delta: Float)
	{
		#if bullet
		physics.stepSimulation( delta, physicsMaxSubSteps);
		physics.checkCollisions();
		#end
		entityManager.tick(delta);
	}

}