package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import bullet.Point;
import h3d.pass.Blur;
import h3d.pass.Shadows.ShadowSamplingKind;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

class Light extends Entity
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

		// debug
		DebugDraw.sphere(new Point(x,y,z),15,0xFF0000,-1);

	}

	public function createLight(def: EntityData)
	{
	}
}

@qClass(
	{
		name: "light",
		desc: "Makes your day brighter.",
		type: "PointClass",
		base: ["LightBase", "Target"],
		fields: [
			{
				name: "light",
				desc: "Light Intensity",
				type: "int",
				def: "300"
			},
			{
				name: "radius",
				desc: "Spotlight Radius",
				tt: "Only affects spotlights.",
				type: "int",
				def: "64"
			},
			{
				name: "scale",
				desc: "Intensity Scale",
				tt: "Override intensity scale.",
				type: "float",
				def: "1"
			},
			{
				name: "fade",
				desc: "Linear Fade",
				tt: "Only affects linear lights",
				type: "float",
				def: "1"
			},
			{
				name: "spawnflags",
				type: "flags",
				opts: [
					{ f: 1, d: "Linear falloff", v: 0 },
					{ f: 2, d: "No angle attenuation", v: 0 },
					{ f: 16, d: "Not dynamic", v: 0 }
				]
			}
		]
	}
)
class PointLight extends Light
{
	override function createLight(def: EntityData)
	{

		var intensity = def.getPropertyFloat("light", 300);
#if pbr
		var l = new h3d.scene.pbr.PointLight( this );
		l.shadows.mode = Dynamic;
		l.shadows.samplingKind = ShadowSamplingKind.PCF;
		//l.shadows.pcfScale = 1;
		l.shadows.bias = 0.05;
		l.shadows.pcfQuality = 1;

		l.shadows.blur = new Blur(10);
		l.shadows.blur.quality = 0.5;

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
			l.power = 30;

		var ql = def.getPropertyFloat("light", 0);
		if( ql != 0 )
		{
			// Quake light!
			l.range = ql;
		}
#else
		var l = new h3d.scene.fwd.PointLight( this );


		l.params.z /= intensity * 100;

#end
		light = l;


		//l.shadows.blur.shader.isDepth = l.shadows.format == h3d.mat.Texture.nativeFormat;
//		l.shadows.




		if( spawnFlags & 1 == 1 )
		{
			light.visible = false;
		}



		// DEBUG
		l.visible = false;

		DebugDraw.sphere(new Point(x,y,z),15,0x00FF00,-1);


	}

	public override function onInput( source: Entity, port: String )
	{
		if( port == "trigger" )
			light.visible = !light.visible;
	}
}
