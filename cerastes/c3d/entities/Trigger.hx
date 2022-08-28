package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;


@qClass(
	{
		name: "trigger_multiple",
		desc: "A trigger that fires multiple times",
		type: "SolidClass"
	}
)
class Trigger extends Brush
{
	var target: String;

	override function onCreated( def: EntityData )
	{
		target = def.getProperty("target");
		super.onCreated( def );
	}
/*
	override function createBody(shape: bullet.Native.ConvexTriangleMeshShape )
	{
		//debugDrawSurfaceDetails
		var b = new cerastes.c3d.BulletBody( shape, 0, GhostObject );
		b.addTo(world.physics, TRIGGER, MASK_TRIGGER );
		b.object = this;
		return b;
	}

	override function buildBrush( def: MapEntityData )
	{
		// Don't.
	}
*/
	override function onCollide( manifold: bullet.Native.PersistentManifold, body: BulletBody, other: Entity, otherBody: BulletBody )
	{
		fireInput(other, "trigger");
	}

	override function onInput( source: Entity, port: String )
	{
		if( target != null )
			fireOutput(target, port );
	}

	public override function tick( d: Float )
	{
		//for( b in bodies )
		//	debugDrawBody(b);
	}
}

@qClass(
	{
		name: "trigger_once",
		desc: "A trigger that only triggers once",
		type: "SolidClass"
	}
)
class TriggerOnce extends Trigger
{
	var hasTriggered = false;


	override function onInput( source: Entity, port: String )
	{
		if( hasTriggered )
			return;

		hasTriggered = true;
		super.onInput(source, port);
	}

}

@qClass(
	{
		name: "trigger_counter",
		desc: "A trigger that only triggers after a certain number of inputs",
		type: "SolidClass",
		fields: [
			{
				name: "count",
				desc: "Triggers before firing output",
				type: "int",
				def: "1"
			}
		]
	}
)
class TriggerCounter extends Trigger
{
	var count: Int;
	var triggerCount: Int;

	override function onCreated( def: EntityData )
	{
		count = def.getPropertyInt("count");
		super.onCreated( def );
	}

	override function onInput( source: Entity, port: String )
	{
		triggerCount++;

		if( triggerCount == count )
			super.onInput(source, port);
	}
}