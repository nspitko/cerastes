package cerastes.c3d.entities;

import h3d.col.Point;
import h3d.scene.Graphics;
import cerastes.c3d.map.Data.Property;
import cerastes.c3d.Entity;

@qClass(
	{
		name: "info_player_start",
		desc: "Player Start",
		type: "PointClass",
		base: ["PlayerClass", "Angle"],
	}
)
class PlayerStart extends Entity
{
	override function onCreated( props: Array<Property> )
	{
		super.onCreated( props );

		var g = new Graphics(this);

		g.material.mainPass.setPassName("overlay");
		g.material.mainPass.depthTest = Always;

		var lineSize = 25;
		var arrowSize = 10;

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
	}
}
