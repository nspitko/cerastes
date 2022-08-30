package cerastes.c3d.q3bsp;

import haxe.rtti.Meta;
import cerastes.c3d.Entity.EntityData;
import h3d.scene.Object;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import cerastes.c3d.World.BaseWorld;

abstract class Q3BSPWorld extends BaseWorld
{
	static var classMap: Map<String, Class<Dynamic>>;

	public override function createEntityClass( cls: Class<Dynamic>, def: EntityData ) : Entity
	{
		var entity: Entity = Type.createInstance(cls,[]);
		@:privateAccess entity.create(def, cast this);
		addChild(entity);

		return entity;
	}

	public override function createEntity( def: EntityData )
	{
		ensureClassMap();

		var className = def.getProperty("classname");
		if( className == null )
		{
			Utils.warning('Entity def missing classname!!!');
			return null;
		}


		trace('found entity ${className}');


		var cls: Class<Dynamic> = classMap.get( className );

		if( cls != null )
		{
			var entity: Entity = Type.createInstance(cls,[]);
			@:privateAccess entity.create(def, cast this);
			addChild(entity);



			return entity;
		}

		Utils.warning('Could not find class def for ${className}');
		return null;
	}

	function ensureClassMap()
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
