package cerastes.c3d.entities;


import bullet.Constants.CollisionFlags;
import h3d.Vector;
import h3d.scene.RenderContext;
import h3d.col.Point;

import cerastes.c3d.map.Data.Property;


class FPSPlayer extends Actor
{
	var controller: FPSPlayerController;

	public var eyePos: Vector;

	override function initializeBody()
	{
		controller = cast QEntity.createEntityClass( FPSPlayerController, world );
		controller.initialize(this);
	}

	public override function onCreated(  def: cerastes.c3d.map.Data.Entity )
	{
		super.onCreated( def );

		eyePos = new Vector(0,0,32);

		//body = new BulletBody( new bullet.Native.CapsuleShape(16,32), 50, RigidBody );
		var shape = new bullet.Native.CapsuleShape(8,16);
		body = new BulletBody( shape, 50, PairCachingGhostObject );
		body.object = this;
		world.physics.addBody( body, PLAYER, MASK_PLAYER );
		body.setRollingFriction(100);
		body.setFriction(100);
		body.slamRotation = false;



		body.collisionFlags |= CollisionFlags.CF_CHARACTER_OBJECT ;


	}

	public override function sync( ctx: RenderContext )
	{
		super.sync(ctx);

		//world.getScene().camera.mcam.setPosition( body.position.toVector().add(eyePos) );

		//world.getScene().camera.mcam
	}


}
