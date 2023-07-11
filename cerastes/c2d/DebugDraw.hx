package cerastes.c2d;


import h2d.col.Bounds;
import h2d.Object;
import hxd.res.DefaultFont;

import h2d.Graphics;

@:structInit
class DebugLine
{
	public var start: Vec2;
	public var end: Vec2;
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

	static var textLines: Array<DebugText> = [];
	static var textDirty = false;

	public static var colorAdd = 0;

	public static function tick( delta: Float )
	{
		if( g == null )
		{
			g = new Graphics();
			t = new h2d.Text( DefaultFont.get(), g );
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

		// Hack: Ensure we're at the top
		if( g.parent != null )
		{
			var pos = g.parent.getChildIndex(g);
			if( pos < g.parent.numChildren - 1 )
				g.parent.addChild(g);
		}


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
			g.moveTo(l.start.x, l.start.y);
			g.lineTo(l.end.x, l.end.y);
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

	public static function line(source: Vec2, target: Vec2, color: Int = 0xFF0000, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		addLine( source, target, color, duration, thickness );
	}

	public static function box(p1: Vec2, p3: Vec2, color: Int = 0xFF0000, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		var p2: Vec2 = {x: p3.x, y: p1.y };
		var p4: Vec2 = {x: p1.x, y: p3.y };

		addLine( p1, p2, color, duration, thickness );
		addLine( p2, p3, color, duration, thickness );
		addLine( p3, p4, color, duration, thickness );
		addLine( p4, p1, color, duration, thickness );
	}

	public static function bounds(bounds: Bounds, color: Int = 0xFF0000, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
	{
		var p1: Vec2 = bounds.getMin();
		var p3: Vec2 = bounds.getMax();
		var p2: Vec2 = {x: p3.x, y: p1.y };
		var p4: Vec2 = {x: p1.x, y: p3.y };

		addLine( p1, p2, color, duration, thickness );
		addLine( p2, p3, color, duration, thickness );
		addLine( p3, p4, color, duration, thickness );
		addLine( p4, p1, color, duration, thickness );
	}

	static function addLine( source: Vec2, target: Vec2, color: Int, duration: Float = 0, alpha: Float = 1, thickness: Float = 1 )
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