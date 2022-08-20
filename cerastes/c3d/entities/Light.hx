package cerastes.c3d.entities;

import h3d.pass.Shadows.ShadowSamplingKind;
import cerastes.c3d.map.SurfaceGatherer;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

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
			},
			{
				name: "spawnflags",
				type: "flags",
				opts: [
					{ f: 1, d: "Starts off", v: 0 },
				]
			}
		]
	},
	// Aliases
	{
		name: "light_fluoro",
		desc: "hack",
		type: "PointClass",
		base: ["LightBase"],
	},
	{
		name: "light_fluorospark",
		desc: "hack",
		type: "PointClass",
		base: ["LightBase"],
	}
)
class PointLight extends Light
{
	override function createLight(def: cerastes.c3d.map.Data.Entity)
	{
		var l = new h3d.scene.pbr.PointLight( this );
		light = l;
		l.shadows.mode = Static;
		l.shadows.samplingKind = ShadowSamplingKind.ESM;
		l.shadows.pcfScale = QWorld.METERS_TO_QU;
		l.shadows.bias = 1 * QWorld.METERS_TO_QU;
//		l.shadows.

		// @todo we should load defaults from qclass decl here!
		var range = def.getProperty("range");
		if( range != null )
			l.range = Std.parseInt( range );
		else
			l.range = 200;

		var power = def.getProperty("power");
		if( power != null )
			l.power = Std.parseInt( power );
		else
			l.power = 10;


		if( spawnFlags & 1 == 1 )
		{
			l.visible = false;
		}
	}

	public override function onInput( source: QEntity, port: String )
	{
		if( port == "trigger" )
			light.visible = !light.visible;
	}
}
