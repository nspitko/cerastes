package cerastes.shaders;

// Dissolve to circles shader
// Adapted from https://www.shadertoy.com/view/WlBfWR

class CircleDisintegrateShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var transp: Vec4;
		@param var color1: Vec4;
		@param var color2: Vec4;

		@param var textureW: Float;
		@param var textureH: Float;

		@param var w: Float; // width of grid (UV coords)
		@param var shrinkSpeed: Float; // shrinking
		@param var lineSpeed: Float; // line scan
		@param var fadeSpeed: Float; // color fade

		@param var time: Float; // animation time

		function randFloat(vec: Vec2, seed: Float) : Float
		{
			return fract(sin(vec.x*99.9+vec.y)*seed);
		}

		function fragment()
		{
			 // sample the texture and convert to YUV color space
			var img = texture.get(input.uv);
			var uv = input.uv;
			//img.w = 0;

			var h: Float = w * ( textureW / textureH );
			uv.x /= w;
			uv.y /= h;

			// Offset rows 3 and 4
			if ( int( uv.y ) % 4 > 1 )
				uv.x += 2.0;

			// Calculate local coordinates in the block
    		// And grid coordinates
    		var local: Vec2 = fract(uv);
    		var xg: Int = int(uv.x);
    		var yg: Int = int(uv.y);

			// Line sweep position
			var line: Float = time * lineSpeed * (1.0/h);

			// Draw
			var color: Vec4 = vec4(0.0,0.0,0.0,0);
			// Above the line, just draw the image
			if ( yg / 2 > int( line / 2.0 ) ) {
				color = img;
			}
			// Below the line, draw pattern
			else if( img.w > 0)
			{
				// Flip local coordinates according to pattern
				var xp: Int = xg % 4;
				var yp: Int = yg % 2;
				if (yp == 0)
				{
					if (xp == 0 || xp == 1) local.y = 1.0 - local.y;
					if (xp == 1 || xp == 2) local.x = 1.0 - local.x;
				}
				else if (yp == 1)
				{
					if (xp == 1 || xp == 2) local.x = 1.0 - local.x;
					if (xp == 2 || xp == 3) local.y = 1.0 - local.y;
				}

				// Get random scale for each main semi-circle
				var rscale: Float = 0.0;
				if (xp < 2)
					rscale = randFloat(vec2(xg,yg/2), 987654.321);
				else
					rscale = randFloat(vec2(xg/2,yg), 987654.321);

				// Get random scale of neighbour semi-circle
				var nrscale: Float = 0.0;
				if (xp < 2)
				{
					if (yp == 1)
					{
						if ((yg/2)%2 == 0)
							nrscale = randFloat(vec2(xg/2+1,yg+1), 987654.321);
						else
							nrscale = randFloat(vec2(xg/2-1,yg+1), 987654.321);
					}
					else
					{
						if ((yg/2)%2 == 0)
							nrscale = randFloat(vec2(xg/2+1,yg-1), 987654.321);
						else
							nrscale = randFloat(vec2(xg/2-1,yg-1), 987654.321);
					}
				}
				else
				{
					if (xp == 2)
						nrscale = randFloat(vec2(xg-1,yg/2), 987654.321);
					else
						nrscale = randFloat(vec2(xg+1,yg/2), 987654.321);
				}

				// Clip scales to range [0,0.5]
				rscale = rscale / 2.0 + 0.5;
				nrscale = nrscale / 2.0 + 0.5;

				// Calculate distance and neighbour distance to center
				var dist: Float = length( local );
				var ndist: Float = length( 1.0 - local );

				// Animate radius
				var radius: Float = 1.0 - time * rscale * shrinkSpeed;
				var nradius: Float = 1.0 - time * nrscale * shrinkSpeed;

				// Time offset for y position
				var t: Float = ((uv.y*h)/lineSpeed);
				radius += t*rscale*shrinkSpeed;
				nradius += t*nrscale*shrinkSpeed;

				// Color fade time
				if (time > t)
					t = (time-t)*fadeSpeed;
				else
					t = 0.0;

				// Draw circles
				if (false && xp < 2)
				{
					if (dist <= radius)
						color += mix(img, color1, t);
					else if (ndist <= nradius)
						color += mix(img, color2, t);
				}
				else
				{
					if (dist <= radius)
						color += mix(img, color2, t);
					else if (ndist <= nradius)
						color += mix(img, color1, t);
				}
			}


			output.color = color * color.a;


		}
	}

}

