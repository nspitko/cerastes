
package cerastes.c3d;

import cerastes.c3d.Entity.EntityData;
import cerastes.collision.Colliders.Point;
import h3d.scene.RenderContext;
import haxe.rtti.Meta;
import h3d.scene.Object;
import cerastes.Entity;

/**
 * h3d scene object version of entity. This is specifically means for use with QMap
 * but should also work jut fine without it as of the time of writing.
 */


class QEntityManager extends EntityManager
{
	@:access( cerastes.c3d.QEntity )
	public function findTarget( targetName: String ): QEntity
	{
		for( e in entities )
		{
			var q: QEntity = cast e;
			if( q.name == targetName )
				return q;
		}
		return null;
	}


}


@:keepSub
@:keepInit
class QEntity extends cerastes.c3d.Entity.BaseEntity
{
	// Common properties all entities might have
	var spawnFlags: Int = 0;
	var angle: Float;


	override function create( d: EntityData, qworld: World )
	{
		var def: MapEntityData = cast d;
		if( def.spawnType == EST_ENTITY )
		{
			var origin = def.getPropertyPoint('origin');
			if( origin != null )
			{
				setPosition(
					-origin.x,
					origin.y,
					origin.z
				);
			}
			// Common properties
			name = def.getProperty("targetname");
			angle = def.getPropertyFloat("angle");
			spawnFlags = def.getPropertyInt("spawnflags");
		}

		super.create(def, world);


	}

	// ====================================================================================
	// Static helpers
	// ====================================================================================

	static var classMap: Map<String, Class<Dynamic>>;

	// ------------------------------------------------------------------------------------
	public static function createEntity( def: MapEntityData, world: World  )  : Entity
	{
		ensureClassMap();

		var className = def.getProperty("classname");
		if( className == null )
		{
			Utils.warning('Entity def missing classname!!!');
				return null;
		}

		var cls: Class<Dynamic> = classMap.get( className );

		if( cls != null )
		{
			var entity: QEntity = Type.createInstance(cls,[]);
			entity.create(def, world);
			world.addChild(entity);

			return entity;
		}

		Utils.warning('Could not find class def for ${className}');
		return null;
	}

	/**
	 * Same as CreateEntity, but instead of passing an entityDef direcetly, just specify
	 * the class.
	 *
	 * @param cls
	 * @param world
	 */
	public static function createEntityClass( cls: Class<Dynamic>, world: World, def: MapEntityData = null ): QEntity
	{
		if( cls != null )
		{
			if( def == null )
				def = {};
			var entity: QEntity = Type.createInstance(cls,[]);

			entity.create(def, world);
			world.addChild(entity);

			return entity;
		}

		Utils.warning('Could not find class def for ${cls}');
		return null;
	}

	static function ensureClassMap()
	{
		if( classMap != null )
			return;

		classMap = [];

		var classList = CompileTime.getAllClasses(Entity);
		for( c in classList )
		{
			var clsMeta = Meta.getType(c);
			var defs = clsMeta.qClass;
			if( defs != null )
			{
				for( d in defs )
				{
					classMap.set(d.name,c);
				}
			}
		}
	}

}
