package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import bullet.Point;
import h3d.pass.Blur;
import h3d.pass.Shadows.ShadowSamplingKind;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

class Light extends QEntity
{
	var light: h3d.scene.Light;

	override function create( def: EntityData, qworld: World )
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
				light.color.set( Std.parseFloat( bits[0] )/255, Std.parseFloat( bits[1] )/255, Std.parseFloat( bits[2] )/255 );
			}

		}

	}

	public function createLight(def: EntityData)
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
	override function createLight(def: EntityData)
	{
		var l = new h3d.scene.pbr.PointLight( this );
		light = l;
		l.shadows.mode = Mixed;
		l.shadows.samplingKind = ShadowSamplingKind.PCF;
		//l.shadows.pcfScale = 1;
		l.shadows.bias = 0.05;
		l.shadows.pcfQuality = 1;

		l.shadows.blur = new Blur(10);
		l.shadows.blur.quality = 0.5;
		//l.shadows.blur.shader.isDepth = l.shadows.format == h3d.mat.Texture.nativeFormat;
//		l.shadows.

		// @todo we should load defaults from qclass decl here!
		var range = def.getProperty("range");
		if( range != null )
			l.range = Std.parseInt( range );
		else
			l.range = 350;

		//l.shadows.

		var power = def.getProperty("power");
		if( power != null )
			l.power = Std.parseInt( power );
		else
			l.power = 10;

		var ql = def.getPropertyFloat("light", 0);
		if( ql != 0 )
		{
			// Quake light!
			l.range = ql;
		}


		if( spawnFlags & 1 == 1 )
		{
			l.visible = false;
		}



		// DEBUG
		//l.visible = false;

		//DebugDraw.sphere(new Point(x,y,z),15,0xFF0000,-1);
	}

	public override function onInput( source: Entity, port: String )
	{
		if( port == "trigger" )
			light.visible = !light.visible;
	}
}
