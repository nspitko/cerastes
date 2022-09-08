package cerastes.c3d.entities;


import cerastes.c3d.Entity.EntitySubclassData;
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


@:structInit
class PlayerSubclassData extends EntitySubclassData
{
	public var speed: Float = 100;
}


class Player extends KinematicActor
{
	var controller: PlayerController;

	var eyePos: Vector;

	public override function onCreated(  def: EntityData )
	{
		super.onCreated( def );

		eyePos = new Vector(0,0,32);

		//var d = getSubclassData();
		//trace(d.speed);


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



	public override function sync( ctx: RenderContext )
	{
		super.sync(ctx);

		//world.getScene().camera.mcam.setPosition( body.position.toVector().add(eyePos) );

		//world.getScene().camera.mcam
	}


}
