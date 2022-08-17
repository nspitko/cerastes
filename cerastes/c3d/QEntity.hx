
package cerastes.c3d;

import h3d.scene.RenderContext;
import haxe.rtti.Meta;
import cerastes.c3d.map.Data.Property;
import h3d.scene.Object;
import cerastes.Entity;

/**
 * h3d scene object version of entity. This is specifically means for use with QMap
 * but should also work jut fine without it as of the time of writing.
 */

@:keepSub
@:keepInit
@qClass(
	// Define base types we're going to need later.
	{
		name: "Angle",
		type: "baseclass",
		fields: [
			{
				name: "angle",
				desc: "Direction",
				type: "integer"
			}
		]
	},
	{
		name: "Targetname",
		type: "baseclass",
		fields: [
			{
				name: "targetname",
				desc: "Name",
				type: "target_source"
			}
		]
	},
	{
		name: "Target",
		type: "baseclass",
		fields: [
			{
				name: "target",
				desc: "Target",
				type: "target_destination"
			},
			{
				name: "killtarget",
				desc: "Kill Target",
				type: "target_destination"
			}
		]
	},
	{
		name: "PlayerClass",
		type: "baseclass",
		size: [-16,-16,-24,16,16,32],
		color: [32,192,32],
		/*
		model: {
			path: "models/xbot.fbx"
		}*/
	}
)
class QEntity extends Object implements cerastes.Entity
{
	public var lookupId: String;

	var destroyed = false;
	public var world(get, null): cerastes.c3d.QWorld;
	public var body: cerastes.c3d.BulletBody = null;

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

	function create( def: cerastes.c3d.map.Data.Entity, qworld: QWorld )
	{
		world = qworld;

		if( def.spawnType == EST_ENTITY )
		{
			var origin = def.getProperty('origin');
			var bits = origin.split(" ");

			setPosition(
				-Std.parseFloat(bits[0]),
				Std.parseFloat(bits[1]),
				Std.parseFloat(bits[2])
			);
		}

		onCreated(def.properties);

		if( body != null )
		{
			body.setTransform( new bullet.Point( x, y, z ) );
		}
		world.entityManager.register(this);

	}

	// Called when an entity is created, override this to define entity specific
	// behaviors
	function onCreated( props: Array<Property> ) { }

	// ====================================================================================
	// Static helpers
	// ====================================================================================

	static var classMap: Map<String, Class<Dynamic>>;

	// ------------------------------------------------------------------------------------
	public static function createEntity( def: cerastes.c3d.map.Data.Entity, world: QWorld  )  : Entity
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

