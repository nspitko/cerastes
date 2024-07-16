package cerastes.c3d.entities;



import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import hxd.Key;
import h3d.scene.fwd.PointLight;
import cerastes.c3d.Entity.EntityData;
import cerastes.c3d.Material.MaterialDef;
import h3d.prim.ModelCache;
import h3d.col.Point;
import h3d.scene.Graphics;
import cerastes.c3d.Entity;
#if hlimgui
import imgui.ImGui;
import imgui.ImGuiMacro;
#end

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

class Prop extends Entity
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
	static var modelCache: ModelCache;

	override function onCreated( def: EntityData )
	{
		super.onCreated( def );

		if( modelCache == null  )
			modelCache = new ModelCache();

		var model = def.getProperty("model");
		if( model != null )
		{
			model = StringTools.replace(model,"\\","/");
			var mdl = hxd.Res.loader.load( model ).toModel();
			var lib = modelCache.loadLibrary( mdl );
			var mesh = lib.makeObject( );
			addChild(mesh);

		}
	}

}

@qClass(
	{
		name: "prop_testF",
		desc: "Test prop",
		type: "PointClass",
		base: ["Angle"],
	}
)
class PropTest extends Entity
{
	static var l: PointLight;

	override function onCreated( def: EntityData )
	{
		super.onCreated( def );


		// physics test
		var radius = 16;
		var sp = new h3d.prim.Sphere(radius, 8, 6);
		sp.addNormals();
		sp.addUVs();
		sp.addTangents();

		var tex = Utils.invalidTexture();
		var mat = h3d.mat.Material.create(tex);
		var mesh = new h3d.scene.Mesh(sp, mat, this );

		// @todo there's a better way to do this surely....
		mat.mainPass.addShader( cerastes.c3d.q3bsp.Q3BSPEntities.lightShader.volShader );

		mat.shadows = false;
		mat.mainPass.enableLights = true;


		body = new BulletBody( new bullet.Native.SphereShape(radius), 50, RigidBody );
		body.object = this;
		body.addTo(world.physics, PROP, MASK_ALL);
		//world.physics.addBody( body, NPC, MASK_NPC );
	}

	public override function tick( delta: Float )
	{
		super.tick(delta);
		if( false )
		{
			var speed = 100 * delta;
			if( Key.isDown( Key.W ) )
				setAbsOrigin( x - speed, y, z );
			if( Key.isDown( Key.A ) )
				setAbsOrigin( x , y + speed, z );
			if( Key.isDown( Key.S ) )
				setAbsOrigin( x + speed, y, z );
			if( Key.isDown( Key.D ) )
				setAbsOrigin( x , y - speed, z );

			if( Key.isDown( Key.E ) )
				setAbsOrigin( x , y, z + speed );
			if( Key.isDown( Key.Q ) )
				setAbsOrigin( x , y , z - speed );
		}

	}


}
