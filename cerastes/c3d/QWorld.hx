
package cerastes.c3d;

import cerastes.c3d.map.QMap;
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
import cerastes.Entity.EntityManager;

class QWorld extends Object
{
	#if bullet
	public var physics: BulletWorld;
	#end

	public var map: QMap;

	public static final QU_TO_METERS = 1.7 / 64;
	public static final METERS_TO_QU = 64 / 1.7;

	public static var physicsMaxSubSteps = 1;

	public var entityManager: EntityManager;

	public function new( ?parent: Object )
	{
		super( parent );
		#if bullet
		physics = new BulletWorld(this);
		physics.setGravity(0,0,-9.8 * METERS_TO_QU);
		#end

		entityManager = new EntityManager();
	}

	public function loadMap(file: String)
	{
		map = new cerastes.c3d.map.QMap(file, this, this);
	}

	public function tick(delta: Float)
	{
		#if bullet
		physics.stepSimulation( delta, physicsMaxSubSteps);
		#end
		entityManager.tick(delta);
	}


}