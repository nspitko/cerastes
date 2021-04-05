package cerastes.ui;

import tweenxcore.Tools.Easing;
import h2d.RenderContext;
import h3d.Vector;

enum TextEffect {
	None;
	Sine;
}

class AdvancedText extends h2d.Text
{
	var rebuildEveryFrame : Bool = false;
	var time : Float = 0;
	public var speed : Float = 0.15;
	public var xOffset : Int = 1620;

	var tweens = new Array<Tween>();
	public var animate = true;

	override function set_text(t : String) {
		var t = t == null ? "null" : t;
		if( t == this.text ) return t;

		if( this.text != null && t.length < this.text.length )
		{
			tweens = [];
			animate = true;
		}


		this.text = t;
		rebuild();
		return t;
	}

	override function initGlyphs( text : String, rebuild = true ) : Void
	{
		if( rebuild )
		{
			glyphs.clear();
			rebuildEveryFrame = false;
		}
		var x = 0., y = 0., xMax = 0., xMin = 0., yMin = 0., prevChar = -1, linei = 0;
		var align = textAlign;
		var lines = new Array<Float>();
		var dl = font.lineHeight + lineSpacing;
		var t = splitRawText(text, 0, 0, lines);

		for ( lw in lines ) {
			if ( lw > x ) x = lw;
		}
		calcWidth = x;

		switch( align ) {
		case Center, Right, MultilineCenter, MultilineRight:
			var max = if( align == MultilineCenter || align == MultilineRight ) hxd.Math.ceil(calcWidth) else realMaxWidth < 0 ? 0 : hxd.Math.ceil(realMaxWidth);
			var k = align == Center || align == MultilineCenter ? 0.5 : 1;
			for( i in 0...lines.length )
				lines[i] = Math.ffloor((max - lines[i]) * k);
			x = lines[0];
			xMin = x;
		case Left:
			x = 0;
		}

		var colorOverride :Vector = null;
		var mode = None;

		var i: Int = 0;

		while( i < t.length )
		{
			var c = t.substr(i,1);
			var cc = t.charCodeAt(i);
			var e = font.getChar(cc);
			var offs = e.getKerningOffset(prevChar);
			var esize = e.width + offs;

			// if the next word goes past the max width, change it into a newline

			if( cc == '\n'.code ) {
				if( x > xMax ) xMax = x;
				switch( align ) {
				case Left:
					x = 0;
				case Right, Center, MultilineCenter, MultilineRight:
					x = lines[++linei];
					if( x < xMin ) xMin = x;
				}
				y += dl;
				prevChar = -1;
			} else {
			if( e != null )
				{
					if( c == "#" )
					{
						if( colorOverride == null )
							colorOverride = Vector.fromColor(0xed79ab);
						else
							colorOverride = null;

						// @todo support multiple colors
						i++;
						continue;
					}
					if( c == "&" )
					{
						if( mode == None )
						{
							rebuildEveryFrame = true;
							mode = Sine;
						}
						else
							mode = None;

						// @todo support multiple effects
						i++;
						continue;
					}

					if( rebuild )
					{
						var finalY = y;


						if( mode == Sine )
							finalY += Math.sin(time * 5 + x) * 2;

						if( colorOverride != null )
							glyphs.addColor(x + offs, finalY, colorOverride.x, colorOverride.y, colorOverride.z, 1., e.t);
						else
							glyphs.add(x + offs, finalY, e.t);


					}
					if( y == 0 && e.t.dy < yMin ) yMin = e.t.dy;
					x += esize + letterSpacing;
				}
				prevChar = cc;
			}

			i++;
		}
		if( x > xMax ) xMax = x;

		calcXMin = xMin;
		calcYMin = yMin;
		calcWidth = xMax - xMin;
		calcHeight = y + font.lineHeight;
		calcSizeHeight = y + (font.baseLine > 0 ? font.baseLine : font.lineHeight);
		calcDone = true;
	}

	override function sync( ctx: RenderContext )
	{
		if( rebuildEveryFrame || true )
		{
			time = ctx.time;
			// @bug? Calling initGlyphs directly avoids child recalc, which we don't need YET.
			// rebuild();
			initGlyphs(text);
		}
	}
}