
package cerastes.c3d;

import cerastes.c3d.map.SerializedMap.EntityDef;
import cerastes.collision.Colliders.Point;
import h3d.scene.RenderContext;
import haxe.rtti.Meta;
import h3d.scene.Object;
import cerastes.Entity;

/**
 * h3d scene object version of entity. This is specifically means for use with QMap
 * but should also work jut fine without it as of the time of writing.
 */


abstract QTarget(String) from String
{
	inline public function new( s: String )
	{
		this = s;
	}
}


class QEntityManager extends EntityManager
{
	@:access( cerastes.c3d.QEntity )
	public function findTarget( targetName: String ): QEntity
	{
		for( e in entities )
		{
			var q: QEntity = cast e;
			if( q.targetName == targetName )
				return q;
		}
		return null;
	}


}


@:keepSub
@:keepInit
class QEntity extends Object implements cerastes.Entity
{
	// used by networking only
	public var lookupId: String;

	var destroyed = false;
	public var world(get, null): cerastes.c3d.QWorld;
	public var body: cerastes.c3d.BulletBody = null;

	// Common properties all entities might have
	var targetName: String = null;
	var spawnFlags: Int = 0;
	var angle: Float;

	public function get_world() : cerastes.c3d.QWorld
	{
		return world;
	}

	public function isDestroyed() { return destroyed; }

	public function destroy() {

		if( body != null )
			body.remove();

		destroyed = true;
	}

	public function tick( delta: Float )
	{
		// Slam position with body position
		if( body != null )
			body.sync();
	}

	function create( def: EntityDef, qworld: QWorld )
	{
		world = qworld;

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
			targetName = def.getProperty("targetname");
			angle = def.getPropertyFloat("angle");
			spawnFlags = def.getPropertyInt("spawnflags");
		}

		onCreated(def);

		initializeBody();

		world.entityManager.register(this);

	}

	function initializeBody()
	{
		if( body != null )
		{
			body.setTransform( new bullet.Point( x, y, z ) );
		}
	}

	function collide( manifold: bullet.Native.PersistentManifold, body: BulletBody, other: QEntity, otherBody: BulletBody )
	{
		onCollide( manifold, body, other, otherBody );
	}

	public function setAbsOrigin( x : Float, y : Float, z : Float )
	{
		setPosition(x,y,z);
		if( body != null )
		{
			body.setTransform( new bullet.Point(x,y,z) );
		}
	}

	@:access( cerastes.c3d.BulletBody )
	public function debugDrawBody( body: BulletBody, duration: Float = 0, color = 0xFF0000, alpha = 0.25, thickness=1.0 )
	{
		var shape = body.inst.getCollisionShape();
		var t = body.inst.getWorldTransform();
		var min = new bullet.Native.Vector3();
		var max = new bullet.Native.Vector3();
		shape.getAabb(t,min,max);


		// make points
		var p = [
			new h3d.col.Point(min.x(), min.y(), min.z()),
			new h3d.col.Point(max.x(), min.y(), min.z()),
			new h3d.col.Point(min.x(), max.y(), min.z()),
			new h3d.col.Point(min.x(), min.y(), max.z()),
			new h3d.col.Point(max.x(), max.y(), min.z()),
			new h3d.col.Point(max.x(), min.y(), max.z()),
			new h3d.col.Point(min.x(), max.y(), max.z()),
			new h3d.col.Point(max.x(), max.y(), max.z()),
		];
		var idx = new Array<Int>();
		idx.push(0); idx.push(1); idx.push(5);
		idx.push(0); idx.push(5); idx.push(3);
		idx.push(1); idx.push(4); idx.push(7);
		idx.push(1); idx.push(7); idx.push(5);
		idx.push(3); idx.push(5); idx.push(7);
		idx.push(3); idx.push(7); idx.push(6);
		idx.push(0); idx.push(6); idx.push(2);
		idx.push(0); idx.push(3); idx.push(6);
		idx.push(2); idx.push(7); idx.push(4);
		idx.push(2); idx.push(6); idx.push(7);
		idx.push(0); idx.push(4); idx.push(1);
		idx.push(0); idx.push(2); idx.push(4);

		var i =0;
		while( i < idx.length )
		{
			var index =  idx[i];
			var indexNext =  idx[i+1];
			DebugDraw.line( p[ index ] , p[ indexNext ], color, duration, alpha );
			i++;
			if( i % 3 == 2 ) i++;
		}
	}

	// entity IO
	function fireOutput( target: QTarget, port: String )
	{
		for( e in world.entityManager.entities )
		{
			var q: QEntity = cast e;
			if( q.targetName == target )
				q.fireInput( this, port );
		}
	}

	public function fireInput( source: QEntity, port: String )
	{
		onInput( source, port );
	}

	// Called when an entity is created, override this to define entity specific
	// behaviors
	function onCreated( def: EntityDef ) { }
	function onCollide( manifold: bullet.Native.PersistentManifold, body: BulletBody, other: QEntity, otherBody: BulletBody ) {}
	function onInput( source: QEntity, port: String ) {}

	// ====================================================================================
	// Static helpers
	// ====================================================================================

	static var classMap: Map<String, Class<Dynamic>>;

	// ------------------------------------------------------------------------------------
	public static function createEntity( def: EntityDef, world: QWorld  )  : Entity
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
	public static function createEntityClass( cls: Class<Dynamic>, world: QWorld, def: EntityDef = null ): QEntity
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
