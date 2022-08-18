package cerastes.c3d.entities;

import cerastes.c3d.map.SurfaceGatherer;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

@qClass(
	{
		name: "Prop",
		desc: "A Prop",
		type: "baseclass",
		fields: [
			{
				name: "model",
				desc: "Model",
				type: "studio"
			}
		]
	},
	{
		name: "prop_static",
		desc: "A static prop in the world",
		type: "PointClass",
		base: ["Prop"]
	}
)
class Prop extends QEntity
{
}

@qClass(
	{
		name: "prop_physics",
		desc: "Happy little physics prop",
		type: "PointClass",
		base: ["Prop"],
	}
)
class PropPhysics extends Prop
{

}
