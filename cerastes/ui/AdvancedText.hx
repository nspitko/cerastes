package cerastes.ui;

import h2d.TileGroup;
import h2d.RenderContext;
import h3d.Vector;

enum TextEffect {
	None;
	Sine;
}

@:keep
class AdvancedText extends h2d.Text
{
	var rebuildEveryFrame : Bool = false;
	var time : Float = 0;

	public var revealed(default, null): Bool = false;
	public var characters(default, set): Int = -1; // -1 -> All, else limit to a specific number
	public var ellipsis: Bool = false;
	public var maxLines(default, set): Int = 0;

	public var boldFont(default, set) : h2d.Font;
	var boldGlyphs : h2d.TileGroup;
	public var desiredColor: Vector = new Vector(1,1,1,1);

	public var displayedText: String;

	function set_boldFont(font)
	{
		if( boldFont == font )
			return font;

		boldFont = font;
		if ( font != null )
		{
			switch( font.type )
			{
				case BitmapFont:
					if ( sdfShader != null )
					{
						removeShader(sdfShader);
						sdfShader = null;
					}
				case SignedDistanceField(channel, alphaCutoff, smoothing):
					if ( sdfShader == null )
					{
						sdfShader = new h3d.shader.SignedDistanceField();
						addShader(sdfShader);
					}
					// Automatically use linear sampling if not designated otherwise.
					if (smooth == null)
						smooth = true;

					sdfShader.alphaCutoff = alphaCutoff;
					sdfShader.smoothing = smoothing;
					sdfShader.channel = channel;
					sdfShader.autoSmoothing = smoothing == -1;
			}
		}
		if( boldGlyphs != null )
			boldGlyphs.remove();

		boldGlyphs = new TileGroup(font == null ? null : font.tile, this);
		boldGlyphs.visible = false;
		rebuild();

		return font;
	}

	function set_characters( v: Int )
	{
		rebuild();
		characters = v;
		return v;
	}

	function stripText( text: String )
	{
		var r = ~/☃[A-z0-9]{6}(.*)☃/gm;
		text = r.replace(text,"$1");

		return text;
	}

	/**
	 * This was a mistake.
	 * @param text
	 * @param leftMargin = 0.
	 * @param afterData = 0.
	 * @param font
	 * @param sizes
	 * @param prevChar
	 */
	override function splitRawText( text : String, leftMargin = 0., afterData = 0., ?font : h2d.Font, ?sizes:Array<Float>, ?prevChar:Int = -1 )
	{
		var maxWidth = realMaxWidth;
		if( maxWidth < 0 )
		{
			if ( sizes == null )
				return text;
			else
				maxWidth = Math.POSITIVE_INFINITY;
		}
		if ( font == null ) font = this.font;
		var lines = [], restPos = 0;
		var x = leftMargin;
		var i = 0;


		var inSnowman = false;
		var isBold = false;
		var skipChars = 0;

		//while( i < text.length )
		for( i in 0 ... text.length)
		{
			var cc = text.charCodeAt(i);

			if( cc == '☃'.code)
			{
				if( !inSnowman )
				{
					inSnowman = true;
					skipChars = 7;
				}
				else
				{
					inSnowman = false;
					skipChars = 1;
				}
			}

			if( cc == '☄'.code && boldGlyphs != null )
			{
				isBold = !isBold;
			}

			if( skipChars > 0 )
			{
				skipChars--;
				continue;
			}

			var curFont = isBold ? boldFont : font;

			var e = curFont.getChar(cc);
			var newline = cc == '\n'.code;
			var esize = e.width + e.getKerningOffset(prevChar);
			var nc = text.charCodeAt(i+1);
			if( curFont.charset.isBreakChar(cc) && (nc == null || !curFont.charset.isComplementChar(nc)) )
			{
				if( lines.length == 0 && leftMargin > 0 && x > maxWidth )
				{
					lines.push("");
					if ( sizes != null ) sizes.push(leftMargin);
					x -= leftMargin;
				}
				var size = x + esize + letterSpacing; /* TODO : no letter spacing */
				var k = i + 1, max = text.length;
				var prevChar = prevChar;
				var breakFound = false;
				while( size <= maxWidth && k < max )
				{
					var cc = text.charCodeAt(k++);
					if( lineBreak && (curFont.charset.isSpace(cc) || cc == '\n'.code ) )
					{
						breakFound = true;
						break;
					}

					var e = curFont.getChar(cc);
					size += e.width + letterSpacing + e.getKerningOffset(prevChar);
					prevChar = cc;
					var nc = text.charCodeAt(k+1);
					if( curFont.charset.isBreakChar(cc) && (nc == null || !curFont.charset.isComplementChar(nc)) ) break;
				}
				if( lineBreak && (size > maxWidth || (!breakFound && size + afterData > maxWidth)) )
				{
					newline = true;
					if( curFont.charset.isSpace(cc) )
					{
						lines.push(text.substr(restPos, i - restPos));
						e = null;
					}
					else
					{
						lines.push(text.substr(restPos, i + 1 - restPos));
					}
					restPos = i + 1;
				}
			}
			if( e != null && cc != '\n'.code )
				x += esize + letterSpacing;
			if( newline )
			{
				if ( sizes != null ) sizes.push(x);
				x = 0;
				prevChar = -1;
			}
			else
				prevChar = cc;

		}
		if( restPos < text.length )
		{
			if( lines.length == 0 && leftMargin > 0 && x + afterData - letterSpacing > maxWidth )
			{
				lines.push("");
				if ( sizes != null ) sizes.push(leftMargin);
					x -= leftMargin;
			}
			lines.push(text.substr(restPos, text.length - restPos));
			if ( sizes != null ) sizes.push(x);
		}
		return lines.join("\n");
	}

	function slamColor()
	{
		if( color.r != 1 || color.g != 1 || color.b != 1 )
		{

			desiredColor = color.clone();
			color.r = 1;
			color.g = 1;
			color.b = 1;
			initGlyphs(text, true);
		}
	}


	override function initGlyphs( text : String, rebuild = true ) : Void
	{
		if( rebuild )
			text = wrapText(text);


		if( rebuild )
		{
			glyphs.clear();

			if( boldGlyphs != null )
				boldGlyphs.clear();
		}

		var x = 0., y = 0., xMax = 0., xMin = 0., yMin = 0., prevChar = -1, linei = 0;
		var align = textAlign;
		var lines = new Array<Float>();
		var dl = font.lineHeight + lineSpacing;
		var bdl = dl;
		var t = splitRawText( text, 0, 0, lines);

		var boldLine = false;

		if( boldGlyphs != null)
			bdl = boldFont.lineHeight + lineSpacing;

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

		// hack
		if( ellipsis )
		{
			trace(ellipsis);
			if( maxLines >0 )
			{
				var i = 0;
				var pos = t.indexOf("\n");
				while( ++i < maxLines && pos > -1 )
				{
					pos = t.indexOf("\n",pos+1);
				}
				var begin = t.substr(0,pos);
				var end = t.substr(pos);
				t = '${begin}${StringTools.replace(end,"\n"," ")}';
			}
			else
			{
				t = StringTools.replace(text,"\n","");
			}

		}

		var colorOverride :Vector = null;
		var mode = None;

		var i: Int = 0;
		var characterIndex: Int = 0;
		var isBold = false;
		var hasBold = false;
		var curGlyphs = glyphs;
		var curFont = font;
		var lineCount = 0;

		while( i < t.length && ( characters == -1 || characterIndex < characters ) )
		{
			var c = t.substr(i,1);
			var cc = t.charCodeAt(i);
			var e = curFont.getChar(cc);
			var offs = e.getKerningOffset(prevChar);
			var esize = e.width + offs;

			// if the next word goes past the max width, change it into a newline

			if( cc == '\n'.code && (maxLines == 0 #if js || maxLines == null #end || lineCount < maxLines-1) ) {
				if( x > xMax ) xMax = x;
				switch( align ) {
				case Left:
					x = 0;
				case Right, Center, MultilineCenter, MultilineRight:
					x = lines[++linei];
					if( x < xMin ) xMin = x;
				}
				if( boldLine )
					y += bdl;
				else
					y += dl;

				boldLine = false;
				lineCount++;

				prevChar = -1;
			} else {
				if( e != null )
				{
					if( c == "☃" )
					{
						if( colorOverride == null )
						{
							var color = t.substr(i+1,6);
							i+= 6;
							colorOverride = Vector.fromColor( Std.parseInt('0x${color}') );
						}
						else
							colorOverride = null;

						i++;
						continue;
					}
					else if ( c == "☄" && boldGlyphs != null )
					{
						boldLine = true;
						hasBold = true;
						isBold = !isBold;
						curFont = isBold ? boldFont : font;
						curGlyphs = isBold ? boldGlyphs : glyphs;

						i++;
						continue;
					}
					else if( c == "🥐" )
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
							curGlyphs.addColor(x + offs, finalY, colorOverride.x, colorOverride.y, colorOverride.z, 1.0, e.t);
						else
							curGlyphs.addColor(x + offs, finalY, desiredColor.x, desiredColor.y, desiredColor.z, 1.0, e.t);
							//curGlyphs.add(x + offs, finalY, e.t);
					}
					if( y == 0 && e.t.dy < yMin ) yMin = e.t.dy;
					x += esize + letterSpacing;

					characterIndex++;
				}
				prevChar = cc;
			}

			i++;
			trace(y);
		}
		if( x > xMax ) xMax = x;

		// @bugbug this will count formatting text...
		revealed = characters >= t.length;

		var lineHeight: Float = (font.baseLine > 0 ? font.baseLine : font.lineHeight);
		if( hasBold )
			lineHeight = Math.max( lineHeight, (boldFont.baseLine > 0 ? boldFont.baseLine : boldFont.lineHeight) );

		calcXMin = xMin;
		calcYMin = yMin;
		calcWidth = xMax - xMin;
		calcHeight = y + font.lineHeight;
		calcSizeHeight = y + lineHeight;
		calcDone = true;
		if ( rebuild ) needsRebuild = false;
	}


	override function sync( ctx: RenderContext )
	{
		slamColor();

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

	function set_maxLines( v: Int )
	{
		maxLines = v;

		return v;
	}

	override function set_text(t : String) {
		var t = t == null ? "null" : t;
		return super.set_text(t);
	}

	override function set_textColor(c: Int)
	{
		desiredColor.setColor( c );
		initGlyphs(text, true);
		return c;
	}

	public function wrapText(t: String)
	{
		//return t;
		if( ellipsis && maxWidth > 0 )
		{
			t = StringTools.trim( t );

			// chunk by word to find what fits
			var w: Float = calcTextWidth( t );
			var lastSpace = t.lastIndexOf(" ");
			while( w > realMaxWidth && lastSpace > 0 )
			{
				t = LocalizationManager.localize("ellipsis", t.substr(0, lastSpace ) );
				w = calcTextWidth( t );
				lastSpace = t.lastIndexOf(" ");
			}
		}
		return t;
	}

	override function draw(ctx:RenderContext)
	{
		super.draw(ctx);

		if( boldGlyphs != null )
			@:privateAccess boldGlyphs.drawWith(ctx,this);
	}
}