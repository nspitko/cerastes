package cerastes.c3d;

import cerastes.c2d.Vec2.CVec2;
import cerastes.c3d.Vec3.CVec3;
import h3d.Matrix;
import h2d.Object;
import hxd.res.DefaultFont;
import h3d.prim.Polygon;
import h3d.prim.Sphere;
import h3d.prim.Primitive;
import h3d.col.Point;
import h3d.Vector4;
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
	public var position: CVec2;
}

@:structInit class DebugState
{
	public var g: Graphics = null;
	public var t: h2d.Object = null;

	public var lines: Array<DebugLine> = [];
	public var linesDirty = false;

	public var colorAdd = 0;

	public var textLines: Array<DebugText> = [];
	public var textDirty = false;

}

class DebugDraw
{
	public static var state: DebugState = {};
	static var stateStack: Array<DebugState> = [];

	static var cube: Polygon;
	static var ball: Polygon;

	public static function pushState( s: DebugState )
	{
		stateStack.push(state);
		state = s;
	}

	public static function popState()
	{
		state = stateStack.pop();
	}

	public static function init()
	{
		if( state.g == null )
		{
			state.g = new Graphics();

			#if debugUseOverlay
			state.g.material.mainPass.setPassName("overlay");
			state.g.material.mainPass.depthTest = Always;
			#end
			state.g.material.mainPass.depthTest = Always;
			state.g.material.mainPass.layer = 1;
			//state.g.material.mainPass.depthTest = Equal;

			state.t = new h2d.Object();
		}
		if( cube == null )
		{
			cube = new h3d.prim.Cube(1,1,1,true);
			ball = new h3d.prim.Sphere(1,5,4);
		}

	}

	public static function tick( delta: Float )
	{


		var i = state.lines.length - 1;
		while( i >= 0 )
		{
			var line = state.lines[i];
			if( line.rendered && line.time >= 0 && line.time < hxd.Timer.lastTimeStamp )
			{
				state.lines.splice(i,1);
				state.linesDirty = true;
			}
			i--;
		}

		if( state.linesDirty )
			rebuildLines();


		var i = state.textLines.length - 1;
		while( i >= 0 )
		{
			var line = state.textLines[i];
			if( line.rendered && line.time >= 0 && line.time < hxd.Timer.lastTimeStamp )
			{
				state.textLines.splice(i,1);
				state.textDirty = true;
			}
			i--;
		}

		if( state.textDirty )
			rebuildText();


	}

	static function rebuildText()
	{
		var i = state.t.numChildren-1;
		while( i >= 0 )
		{
			var to: h2d.Text = cast state.t.getChildAt(i);
			var ti = state.textLines[i];
			i--;
			if( ti == null )
			{
				to.remove();
				continue;
			}

			ti.rendered = true;
			to.text = ti.text;
			to.setPosition( ti.position.x, ti.position.y );
		}
		if( state.textLines.length > state.t.numChildren )
		{
			for( i in state.t.numChildren ... state.textLines.length )
			{
				var nt = new h2d.Text( DefaultFont.get(), state.t );
				var ti = state.textLines[i];
				nt.text = ti.text;
				nt.setPosition( ti.position.x, ti.position.y );
			}
		}
	}

	static function rebuildLines()
	{
		state.g.clear();
		for( l in state.lines )
		{
			state.g.lineStyle(l.thickness, l.color, l.alpha);
			state.g.drawLine(l.start, l.end);
			l.rendered = true;
		}
	}

	public static function text( text: String, pos: Vec3, color: Int = 0xFFFFFF, duration: Float = 0, alpha: Float = 1 )
	{
		state.textDirty=true;

		var scene3d = state.g.getScene();
		var scene2d = state.t.getScene();
		if( !Utils.verify( scene3d != null && scene3d != null, "Tried to place text inside debug text when it's not in a scene!" ) )
			return;

		var pos: Vec3 = scene3d.camera.project( pos.x, pos.y, pos.z, scene2d.width, scene2d.height );

		state.textLines.push({
			text: text,
			color: color,
			time: duration >= 0 ? hxd.Timer.lastTimeStamp + duration : duration,
			alpha: alpha,
			position: { x: pos.x, y: pos.y }
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
		state.linesDirty = true;
		state.lines.push({
			start: source,
			end: target,
			color: color + state.colorAdd,
			time: duration >= 0 ? hxd.Timer.lastTimeStamp + duration : duration,
			thickness: thickness,
			alpha: alpha
		});
	}
}