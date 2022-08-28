package cerastes.c3d.entities;

import cerastes.c3d.Entity.EntityData;
import cerastes.Entity.EntityManager;
import format.swf.Data.PlaceObject;
import h3d.col.Point;
import h3d.scene.Graphics;
import cerastes.c3d.Entity;

@qClass(
	{
		name: "info_player_start",
		desc: "Player Start",
		type: "PointClass",
		base: ["PlayerClass", "Angle"],
		fields: [
			{
				name: "playertype",
				type: "choices",
				opts: [
					{ v: 0, d: "FPS"  }
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

		var playerType = def.getPropertyInt("playertype");

		switch( playerType )
		{
			//case 0:
				// @todo
				//var p = QEntity.createEntityClass( FPSPlayer, world, def );
				//var pos = new bullet.Point(x,y,z);

			default:
				Utils.error('info_player_start has invalid player type ${playerType}; no player will spawn!');
		}

	}
}
