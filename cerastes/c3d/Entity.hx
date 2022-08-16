
package cerastes.c3d;

import haxe.rtti.Meta;
import cerastes.c3d.map.Data.Property;
import h3d.scene.Object;
import cerastes.Entity;

/**
 * h3d scene object version of entity. This is specifically means for use with QMap
 * but should also work jut fine without it as of the time of writing.
 */

@:keepSub
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
class Entity extends Object implements cerastes.Entity
{
	public var lookupId: String;

	var destroyed = false;

	public function new( ?parent: Object )
	{
		super( parent );
	}

	public function isDestroyed() { return destroyed; }

	public function destroy() {
		destroyed = true;
	}

	public function tick( delta: Float )
	{
	}

	// Called automatically when our world changes.
	public function setWorld( newWorld: World )
	{
	}

	function create( def: cerastes.c3d.map.Data.Entity )
	{
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
	}

	// Called when an entity is created, override this to define entity specific
	// behaviors
	function onCreated( props: Array<Property> ) { }

	// ====================================================================================
	// Static helpers
	// ====================================================================================

	static var classMap: Map<String, Class<Dynamic>>;

	// ------------------------------------------------------------------------------------
	public static function createEntity( def: cerastes.c3d.map.Data.Entity, ?parent: Object  )  : Entity
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
			var entity: Entity = Type.createInstance(cls,[]);
			entity.create(def);
			parent.addChild(entity);

			return entity;
		}

		Utils.warning('Could not fine class def for ${className}');
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

