package cerastes.c3d.entities;

import cerastes.c3d.map.SurfaceGatherer;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

@qClass(
	{
		name: "LightBase",
		desc: "A light",
		type: "baseclass",
		size: [-8,-8,-8,8,8,8],
		color: [200,200,16],
		fields: [
			{
				name: "_color",
				desc: "Color",
				type: "color1"
			}
		]
	}
)
class Light extends QEntity
{
	var light: h3d.scene.Light;

	override function create( def: cerastes.c3d.map.Data.Entity, qworld: QWorld )
	{
		super.create(def, qworld);

		createLight(def);

		if( light != null )
		{
			var color = def.getProperty("_color");
			if( color != null )
			{
				// @todo make this a function this
				var bits = color.split(" ");
				light.color.set( Std.parseFloat( bits[0] ), Std.parseFloat( bits[1] ), Std.parseFloat( bits[2] ) );
			}
		}

	}

	public function createLight(def: cerastes.c3d.map.Data.Entity)
	{
	}
}

@qClass(
	{
		name: "light",
		desc: "Standard point light",
		type: "PointClass",
		base: ["LightBase"],
		fields: [
			{
				name: "power",
				desc: "Power",
				type: "int",
				def: "8"
			},
			{
				name: "range",
				desc: "Range",
				type: "int",
				def: "128"
			}
		]
	}
)
class PointLight extends Light
{
	override function createLight(def: cerastes.c3d.map.Data.Entity)
	{
		var l = new h3d.scene.pbr.PointLight( this );
		light = l;

		// @todo we should load defaults from qclass decl here!
		var range = def.getProperty("range");
		if( range != null )
			l.range = Std.parseInt( range );
		else
			l.range = 128;

		var power = def.getProperty("power");
		if( power != null )
			l.power = Std.parseInt( power );
		else
			l.power = 8;

	}
}
