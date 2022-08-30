package cerastes.c3d.entities;



import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;
import hxd.Key;
import imgui.ImGui;
import h3d.scene.fwd.PointLight;
import cerastes.c3d.Entity.EntityData;
import cerastes.c3d.Material.MaterialDef;
import h3d.prim.ModelCache;
import h3d.col.Point;
import h3d.scene.Graphics;
import cerastes.c3d.Entity;
import imgui.ImGuiMacro;


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
		name: "prop_test",
		desc: "Test prop",
		type: "PointClass",
		base: ["Angle"],
	}
)
class PropTest extends Entity
{
	static var l: PointLight;

	var bsp: BSPFileDef;
	override function onCreated( def: EntityData )
	{
		super.onCreated( def );
		bsp = def.bsp;


		// physics test
		var radius = 16;
		var sp = new h3d.prim.Sphere(radius, 8, 6);
		sp.addNormals();
		sp.addUVs();
		sp.addTangents();

		var tex = hxd.Res.spr.placeholder.toTexture();
		var mat = h3d.mat.Material.create(tex);
		var mesh = new h3d.scene.Mesh(sp, mat, this );

		mat.shadows = false;
		mat.mainPass.enableLights = true;


		body = new BulletBody( new bullet.Native.SphereShape(radius), 50, RigidBody );
		body.object = this;
		body.addTo(world.physics, NPC, MASK_NPC);
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

		if( false )
		{

			var wx = bsp.models[0].maxs[0] - bsp.models[0].mins[0];
			var wy = bsp.models[0].maxs[1] - bsp.models[0].mins[1];
			var wz = bsp.models[0].maxs[2] - bsp.models[0].mins[2];

			var nx = CMath.floor(bsp.models[0].maxs[0] / 64) - CMath.ceil(bsp.models[0].mins[0] / 64) + 1;
			var ny = CMath.floor(bsp.models[0].maxs[1] / 64) - CMath.ceil(bsp.models[0].mins[1] / 64) + 1;
			var nz = CMath.floor(bsp.models[0].maxs[2] / 128) - CMath.ceil(bsp.models[0].mins[2] / 128) + 1;

			var volSize = new Point( nx, ny, nz );
			var volScale = new Point( 64, 64, 128 );
			var volOffset = new Point( bsp.models[0].mins[0], bsp.models[0].mins[1], bsp.models[0].mins[2] );
			var position = new Point(x,y,z);

			var volSpace = new Point( ( position.x - volOffset.x ) / 64, ( position.y - volOffset.y ) / 64, ( position.z - volOffset.z ) / 128 );

			var zPos = volSpace.z;
			var zIdx = Math.floor(zPos);

			volSpace = CMath.pointDivide( volSpace,  volSize);

			var ly = volSpace.y / volSize.z;
			ly += ( 1 / volSize.z ) * zIdx;

			var idx = CMath.floor( volSpace.x * nx ) + Math.floor( ly * nx * ny);

			//DebugDraw.box( out, 20, 0xFF0000 );
		}




	}


}
