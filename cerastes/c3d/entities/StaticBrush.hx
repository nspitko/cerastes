package cerastes.c3d.entities;

import cerastes.c3d.map.SurfaceGatherer;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

@qClass(
	{
		name: "func_group",
		desc: "Group (used internally by some map editors)",
		type: "SolidClass",
	},
	{
		name: "func_detail",
		desc: "Brush group",
		type: "SolidClass",
	},
	{
		name: "func_detail_wall",
		desc: "Back compat; don't use",
		type: "SolidClass",
	}
)
class StaticBrush extends Brush
{
}

@qClass(
	{
		name: "func_detail_illusory",
		desc: "Brush group, but without collision",
		type: "SolidClass",
	},
	{
		name: "func_illusory",
		desc: "Single brush without collision",
		type: "SolidClass",
	}
)
class IllusoryBrush extends Brush
{
	override function createBody(shape: bullet.Native.ConvexTriangleMeshShape )
	{
		var b = new cerastes.c3d.BulletBody( shape, 0, GhostObject );
		b.addTo(world.physics, WORLD, MASK_WORLD );
		b.object = this;
		return b;
	}
}


@qClass(
	{
		name: "func_mover_test",
		desc: "Silly moving brush",
		type: "SolidClass",
		fields: [
			{
				name: "height",
				desc: "How many units to move up",
				type: "integer"
			}
		]
	}
)
class FuncMoverTest extends Brush
{
	var startingHeight:Float = 0;
	var maxHeight:Float = 0;
	var dir: Float = 1;

	override function onCreated( def: cerastes.c3d.map.Data.Entity )
	{
		maxHeight = Std.parseFloat( def.getProperty("height") );
		startingHeight = z;
	}

	public override function tick( delta: Float )
	{
		var body = bodies[0];
		z = body.position.z;
		if( dir > 0 && z >= startingHeight + maxHeight )
			dir = -1;
		else if( dir < 0 && z <= startingHeight )
			dir = 1;

		// @todo unfuck this
		z += dir * delta * 100;

		body.setTransform(new h3d.col.Point( body.position.x, body.position.y, z ) );

	}
}
