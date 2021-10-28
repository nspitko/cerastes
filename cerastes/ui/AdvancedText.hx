package cerastes.ui;

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

	public var revealed(default, null): Bool = false;
	public var characters(default, set): Int = -1; // -1 -> All, else limit to a specific number

	function set_characters( v: Int )
	{
		rebuild();
		characters = v;
		return v;
	}


	override function initGlyphs( text : String, rebuild = true ) : Void
	{
		if( rebuild )
			glyphs.clear();

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
		var characterIndex: Int = 0;
		while( i < t.length && ( characters == -1 || characterIndex <= characters ) )
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
							colorOverride = Vector.fromColor(0xF7941D);
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
							finalY += Math.sin(time * 10 + x/5) * 2;

						if( colorOverride != null )
							glyphs.addColor(x + offs, finalY, colorOverride.x, colorOverride.y, colorOverride.z, 1.0, e.t);
						else
							glyphs.add(x + offs, finalY, e.t);
					}
					if( y == 0 && e.t.dy < yMin ) yMin = e.t.dy;
					x += esize + letterSpacing;

					characterIndex++;
				}
				prevChar = cc;
			}

			i++;
		}
		if( x > xMax ) xMax = x;

		// @bugbug this will count formatting text...
		revealed = characters >= t.length;

		calcXMin = xMin;
		calcYMin = yMin;
		calcWidth = xMax - xMin;
		calcHeight = y + font.lineHeight;
		calcSizeHeight = y + (font.baseLine > 0 ? font.baseLine : font.lineHeight) + 10;
		calcDone = true;
		if ( rebuild ) needsRebuild = false;
	}

	override function sync( ctx: RenderContext )
	{
		if( rebuildEveryFrame )
		{
			time = ctx.time;
			// @bug? Calling initGlyphs directly avoids child recalc, which we don't need YET.
			// rebuild();
			initGlyphs(text);
		}
		else
		{
			checkText();
			if ( needsRebuild )
				initGlyphs(currentText);
		}
	}
}