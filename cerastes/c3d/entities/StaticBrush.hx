package cerastes.c3d.entities;


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
	},
	{
		name: "func_wall", // https://quakewiki.org/wiki/func_wall
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
	/*
	@todo
	override function createBody(shape: bullet.Native.ConvexTriangleMeshShape )
	{
		var b = new cerastes.c3d.BulletBody( shape, 0, GhostObject );
		b.addTo(world.physics, WORLD, MASK_WORLD );
		b.object = this;
		return b;
	}
	*/
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
