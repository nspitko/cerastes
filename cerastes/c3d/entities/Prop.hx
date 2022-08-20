package cerastes.c3d.entities;



import cerastes.c3d.Material.MaterialDef;
import h3d.prim.ModelCache;
import h3d.col.Point;
import h3d.scene.Graphics;
import cerastes.c3d.map.Data.Property;
import cerastes.c3d.QEntity;


import cerastes.c3d.map.SurfaceGatherer;

import cerastes.c3d.BulletWorld.BulletCollisionFilterGroup;
import cerastes.c3d.BulletWorld.BulletCollisionFilterMask;

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
	static var modelCache: ModelCache;

	override function onCreated( def: cerastes.c3d.map.Data.Entity )
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
		name: "prop_test",
		desc: "Test prop",
		type: "PointClass",
		base: ["Angle"],
	}
)
class PropTest extends QEntity
{
	override function onCreated( def: cerastes.c3d.map.Data.Entity )
	{
		super.onCreated( def );

		var g = new Graphics(this);

		g.material.mainPass.setPassName("overlay");
		g.material.mainPass.depthTest = Always;

		var lineSize = 25;
		var arrowSize = 10;
/*
		// X (Red)
		g.lineStyle(1, 0xFF0000, 1);
		g.drawLine(new Point(-lineSize,0,0), new Point(lineSize,0,0));
		g.drawLine(new Point(lineSize,arrowSize,0), new Point(lineSize,-arrowSize,0));

		// Y (Green)
		g.lineStyle(1, 0x00FF00, 1);
		g.drawLine(new Point(0,-lineSize,0), new Point(0,lineSize,0));
		g.drawLine(new Point(arrowSize,lineSize,0), new Point(-arrowSize,lineSize,0));

		// Z (Blue)
		g.lineStyle(1, 0x0000FF, 1);
		g.drawLine(new Point(0,0,-lineSize), new Point(0,0,lineSize));
		g.drawLine(new Point(arrowSize,0,lineSize), new Point(-arrowSize,0,lineSize));
*/
		// physics test
		var radius = 16;
		var sp = new h3d.prim.Sphere(radius, 8, 6);
		sp.addNormals();
		sp.addUVs();
		sp.addTangents();

		var tex = hxd.Res.spr.placeholder.toTexture();
		var mat = h3d.mat.Material.create(tex);
		var mesh = new h3d.scene.Mesh(sp, mat, this );
		mesh.material.shadows = true;

		body = new BulletBody( new bullet.Native.SphereShape(radius), 50, RigidBody );
		body.object = this;
		world.physics.addBody( body, NPC, MASK_NPC );


		//body.applyImpulse(Math.random() * 2000 - 1000,Math.random() * 2000 - 1000,0);
		//body.setRollingFriction(100.0);
	}
}
