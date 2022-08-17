package cerastes.c3d.entities;

import cerastes.c3d.QEntity;

/**
 * Worldspawn is the root entity for a map. It contains all the physics for
 * the world and manages all entities.
 */

@qClass(
	{
		name: "worldspawn",
		desc: "World Entity",
		type: "SolidClass",
	}
)
class Worldspawn extends QEntity
{
}