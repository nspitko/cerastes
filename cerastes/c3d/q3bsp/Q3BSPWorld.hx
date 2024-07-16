package cerastes.c3d.q3bsp;

import cerastes.Entity.EntityDef;
import haxe.rtti.Meta;
import cerastes.c3d.Entity.EntityData;
import h3d.scene.Object;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import cerastes.c3d.World.BaseWorld;

abstract class Q3BSPWorld extends BaseWorld
{
	static var classMap: Map<String, Class<Dynamic>>;

	public override function createEntityClass( cls: Class<Dynamic>, data: EntityData, ?parent: h3d.scene.Object ) : Entity
	{
		var entity: Entity = Type.createInstance(cls,[]);
		@:privateAccess entity.create(data, cast this);
		if( parent != null )
			parent.addChild(entity);
		else
			addChild(entity);

		return entity;
	}

	public override function createEntity( data: EntityData, ?parent: h3d.scene.Object )
	{
		ensureClassMap();

		var className = data.getProperty("classname");
		if( className == null )
		{
			Utils.warning('Entity def missing classname!!!');
			return null;
		}

		var cls: Class<Dynamic> = classMap.get( className );

		if( cls != null )
		{
			return createEntityClass(cls, data, parent);
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
