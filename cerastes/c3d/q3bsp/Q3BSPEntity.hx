package cerastes.c3d.q3bsp;

import cerastes.c3d.Entity.EntityData;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import cerastes.c3d.Entity.BaseEntity;

@:structInit
class Q3BSPEntityData extends cerastes.c3d.Entity.EntityDataBase
{
	// Reference to the q3 BSP. Don't store this anywhere (Same with entity data),
	// else the whole map gets held in memory forever
	public var bsp: BSPFileDef = null;
}

@:keepSub
class Q3BSPEntity extends BaseEntity
{
	override function create( def: EntityData, w: World )
	{
		super.create(def, w);

		var origin = def.getPropertyPoint('origin');
		if( origin != null )
		{
			setAbsOrigin(
				origin.x,
				origin.y,
				origin.z
			);
		}
		// Common properties
		//targetName = def.getProperty("targetname");
		//angle = def.getPropertyFloat("angle");
		//spawnFlags = def.getPropertyInt("spawnflags");

	}
}