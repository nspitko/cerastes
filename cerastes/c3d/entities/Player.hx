package cerastes.c3d.entities;


import cerastes.c3d.entities.ThirdPersonCameraController.ThirdPersonPlayerController;
import cerastes.c3d.Entity.EntityData;
import bullet.Constants.CollisionFlags;
import h3d.Vector;
import h3d.scene.RenderContext;
import h3d.col.Point;

@qClass(
	{
		name: "info_player_start_generic",
		desc: "Player Start",
		type: "PointClass",
		base: ["PlayerClass", "Angle"],
		fields: [
			{
				name: "playertype",
				type: "choices",
				opts: [
					{ v: 0, d: "Generic FPS"  },
					{ v: 1, d: "Generic Third Person"  }
				]
			}

		]
	}
)
class PlayerStart extends Entity
{
	override function onCreated( def: EntityData )
	{
		super.onCreated( def );

		var p = world.createEntityClass( Player, def );
		var pos = new bullet.Point(x,y,z);

	}
}



class Player extends Actor
{
	var controller: PlayerController;

	var eyePos: Vector;

	public override function onCreated(  def: EntityData )
	{
		super.onCreated( def );

		eyePos = new Vector(0,0,32);


		var playerType = def.getPropertyInt("playertype");

		var d: EntityData = {};

		if( controller == null )
		{
			switch( playerType )
			{
				case 1:
					controller = cast world.createEntityClass( FPSPlayerController, d );

				case 0:
					controller = cast world.createEntityClass( ThirdPersonPlayerController, d );

				default:
					Utils.error('info_player_start has invalid player type ${playerType}; no player will spawn!');
					return;
			}
		}

		controller.initialize(this);


	}

	override function createBody( def: EntityData )
	{
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
