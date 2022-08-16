package cerastes.c3d.entities;

import cerastes.c3d.Entity;

@qClass(
	{
		name: "worldspawn",
		desc: "World Entity",
		type: "SolidClass",
	},
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
		name: "func_detail_illusory",
		desc: "Brush group, but without collision",
		type: "SolidClass",
	},
	{
		name: "func_illusory",
		desc: "Single brush without collision",
		type: "SolidClass",
	},
	{
		name: "func_detail_wall",
		desc: "Back compat; don't use",
		type: "SolidClass",
	}
)
class StaticGeo extends Entity
{

}