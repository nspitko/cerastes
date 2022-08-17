package cerastes.c3d;

import h3d.prim.Polygon;
import h3d.prim.Sphere;
import h3d.prim.Primitive;
import h3d.col.Point;
import h3d.Vector;
import h3d.scene.Graphics;

@:structInit
class DebugLine
{
	public var start: Point;
	public var end: Point;
	public var color: Int;
	public var time: Float;
	public var alpha: Float;
	public var thickness: Float;
}

class DebugDraw
{
	public static var g: Graphics;

	static var lines: Array<DebugLine> = [];
	static var dirty = false;

	static var cube: Polygon;
	static var ball: Polygon;

	public static function tick( delta: Float )
	{
		if( g == null )
		{
			g = new Graphics();

			g.material.mainPass.setPassName("overlay");
			g.material.mainPass.depthTest = Always;

			cube = new h3d.prim.Cube(1,1,1,true);
			ball = new h3d.prim.Sphere(1);
		}

		var i = lines.length - 1;
		while( i >= 0 )
		{
			var line = lines[i];
			if( line.time < hxd.Timer.lastTimeStamp )
			{
				lines.splice(i,1);
				dirty = true;
			}
			i--;
		}

		if( dirty )
			rebuildLines();
	}

	static function rebuildLines()
	{
		g.clear();
		for( l in lines )
		{
			g.lineStyle(l.thickness, l.color, l.alpha);
			g.drawLine(l.start, l.end);
		}
	}

	public static function line(source: Vector, target: Vector, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		addLine( source, target, color, duration, thickness );
	}

	public static function box( position: Vector, size: Float = 15, color: Int = 0xFFFFFF, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		polygon(cube, new Point( position.x, position.y, position.z), size, color, duration, alpha, thickness );
	}

	public static function sphere( position: Vector, size: Float = 15, color: Int = 0xFFFFFF, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		polygon(ball, new Point( position.x, position.y, position.z), size, color, duration, alpha, thickness );
	}

	public static function polygon( polygon: Polygon, position: Point, size, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		var i = 0;
		while( i < polygon.idx.length )
		{
			var idx = polygon.idx[i];
			var idxn = polygon.idx[i+1];
			addLinePoint( polygon.points[idx].multiply(size).add( position ), polygon.points[idxn].multiply(size).add( position ), color, duration, alpha, thickness );
			i++;
			if( i % 3 == 2 ) i++;
		}
	}

	public static function drawAxis(position: Vector, size: Float = 15, duration: Float = 0 )
	{
		var lineSize = size;
		var arrowSize = size * 0.25;

		// x (Red)
		addLinePoint(new Point( position.x + -lineSize, position.y + 0, position.z + 0), new Point( position.x + lineSize, position.y + 0, position.z + 0),0xFF0000, duration);
		addLinePoint(new Point( position.x + lineSize, position.y + arrowSize, position.z + 0), new Point( position.x + lineSize, position.y + -arrowSize, position.z + 0),0xFF0000, duration);

		// Y (Green)
		addLinePoint(new Point( position.x + 0, position.y + -lineSize, position.z + 0), new Point( position.x + 0, position.y + lineSize, position.z + 0),0x00FF00, duration);
		addLinePoint(new Point( position.x + arrowSize,lineSize, position.z + 0), new Point( position.x + -arrowSize,lineSize, position.z + 0),0x00FF00, duration);

		// Z (Blue)
		addLinePoint(new Point( position.x + 0, position.y + 0, position.z + -lineSize), new Point( position.x + 0, position.y + 0, position.z + lineSize),0x0000FF, duration);
		addLinePoint(new Point( position.x + arrowSize, position.y + 0, position.z + lineSize), new Point( position.x + -arrowSize, position.y + 0, position.z + lineSize),0x0000FF, duration);

	}

	static function addLine( source: Vector, target: Vector, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		dirty = true;
		lines.push({
			start: new Point( source.x, source.y, source.z),
			end: new Point( target.x, target.y, target.z),
			color: color,
			time: hxd.Timer.lastTimeStamp + duration,
			thickness: thickness,
			alpha: alpha
		});
	}

	static function addLinePoint( source: Point, target: Point, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		dirty = true;
		lines.push({
			start: source,
			end: target,
			color: color,
			time: hxd.Timer.lastTimeStamp + duration,
			thickness: thickness,
			alpha: alpha
		});
	}
}