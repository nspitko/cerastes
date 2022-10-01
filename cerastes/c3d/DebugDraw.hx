package cerastes.c3d;

import h3d.Matrix;
import h2d.Object;
import hxd.res.DefaultFont;
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
	public var rendered: Bool = false;
}

@:structInit
class DebugText
{
	public var text: String;
	public var color: Int;
	public var time: Float;
	public var alpha: Float;
	public var rendered: Bool = false;
}

class DebugDraw
{
	public static var g: Graphics;
	public static var t: h2d.Text;

	static var lines: Array<DebugLine> = [];
	static var linesDirty = false;

	static var cube: Polygon;
	static var ball: Polygon;


	static var textLines: Array<DebugText> = [];
	static var textDirty = false;

	public static var colorAdd = 0;

	public static function tick( delta: Float )
	{
		if( g == null )
		{
			g = new Graphics();

			#if debugUseOverlay
			g.material.mainPass.setPassName("overlay");
			#end
			g.material.mainPass.depthTest = Always;

			cube = new h3d.prim.Cube(1,1,1,true);
			ball = new h3d.prim.Sphere(1);

			t = new h2d.Text( DefaultFont.get() );
		}

		var i = lines.length - 1;
		while( i >= 0 )
		{
			var line = lines[i];
			if( line.rendered && line.time >= 0 && line.time < hxd.Timer.lastTimeStamp )
			{
				lines.splice(i,1);
				linesDirty = true;
			}
			i--;
		}

		if( linesDirty )
			rebuildLines();


		var i = textLines.length - 1;
		while( i >= 0 )
		{
			var line = textLines[i];
			if( line.rendered && line.time >= 0 && line.time < hxd.Timer.lastTimeStamp )
			{
				textLines.splice(i,1);
				textDirty = true;
			}
			i--;
		}

		if( textDirty )
			rebuildText();


	}

	static function rebuildText()
	{
		var str = "";
		for( t in textLines )
		{
			str += '${t.text}\n';
			t.rendered = true;
		}
		t.text = str;
	}

	static function rebuildLines()
	{
		g.clear();
		for( l in lines )
		{
			g.lineStyle(l.thickness, l.color, l.alpha);
			g.drawLine(l.start, l.end);
			l.rendered = true;
		}
	}

	public static function text( text: String, color: Int = 0xFFFFFF, duration: Float = 0, alpha: Float = 1 )
	{
		textDirty=true;
		textLines.push({
			text: text,
			color: color,
			time: duration >= 0 ? hxd.Timer.lastTimeStamp + duration : duration,
			alpha: alpha
		});
	}

	public static inline function lineV(source: Vector, target: Vector, color: Int = 0xFF0000, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		line( source.toPoint(), target.toPoint(), color, duration, alpha, thickness );
	}

	public static function line(source: Point, target: Point, color: Int = 0xFF0000, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		addLine( source, target, color, duration, thickness );
	}

	public static function box( position: Point, size: Point, color: Int = 0xFFFFFF, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		polygon(cube, position, size, color, duration, alpha, thickness );
	}

	public static function sphere( position: Point, size: Float = 15, color: Int = 0xFFFFFF, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		var s = new Point(size, size, size);
		polygon(ball, position, s, color, duration, alpha, thickness );
	}

	public static function polygon( polygon: Polygon, position: Point, size: Point, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		var i = 0;
		while( i < polygon.idx.length )
		{
			var idx = polygon.idx[i];
			var idxn = polygon.idx[i+1];
			addLine( CMath.pointMultiply( polygon.points[idx],size ).add( position ), CMath.pointMultiply( polygon.points[idxn],size ).add( position ), color, duration, alpha, thickness );
			i++;
			if( i % 3 == 2 ) i++;
		}
	}

	public static function drawAxis(position: Vector, size: Float = 15, duration: Float = 0 )
	{
		var lineSize = size;
		var arrowSize = size * 0.25;

		// x (Red)
		addLine(new Point( position.x + -lineSize, position.y + 0, position.z + 0), new Point( position.x + lineSize, position.y + 0, position.z + 0),0xFF0000, duration);
		addLine(new Point( position.x + lineSize, position.y + arrowSize, position.z + 0), new Point( position.x + lineSize, position.y + -arrowSize, position.z + 0),0xFF0000, duration);

		// Y (Green)
		addLine(new Point( position.x + 0, position.y + -lineSize, position.z + 0), new Point( position.x + 0, position.y + lineSize, position.z + 0),0x00FF00, duration);
		addLine(new Point( position.x + arrowSize,lineSize, position.z + 0), new Point( position.x + -arrowSize,lineSize, position.z + 0),0x00FF00, duration);

		// Z (Blue)
		addLine(new Point( position.x + 0, position.y + 0, position.z + -lineSize), new Point( position.x + 0, position.y + 0, position.z + lineSize),0x0000FF, duration);
		addLine(new Point( position.x + arrowSize, position.y + 0, position.z + lineSize), new Point( position.x + -arrowSize, position.y + 0, position.z + lineSize),0x0000FF, duration);

	}

	public static function drawAxisM(matrix: Matrix, size: Float = 15, duration: Float = 0 )
	{
		var lineSize = size;
		var arrowSize = size * 0.25;

		var center = matrix.getPosition().toPoint();

		var fwd = new Point(lineSize,0,0);
		fwd.transform(matrix);

		var side = new Point(0,lineSize,0);
		side.transform(matrix);

		var up = new Point(0,0,lineSize);
		up.transform(matrix);

		// x (Red)
		addLine( center, fwd, 0xFF0000, duration);

		// Y (Green)
		addLine( center, side, 0x00FF00, duration);

		// Z (Blue)
		addLine( center, up, 0x0000FF, duration);

	}

	static function addLine( source: Point, target: Point, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		linesDirty = true;
		lines.push({
			start: source,
			end: target,
			color: color + colorAdd,
			time: duration >= 0 ? hxd.Timer.lastTimeStamp + duration : duration,
			thickness: thickness,
			alpha: alpha
		});
	}
}