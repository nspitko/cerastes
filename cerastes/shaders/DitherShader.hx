package cerastes.shaders;

// PSX style dither shader
// Adapted from https://github.com/jmickle66666666/PSX-Dither-Shader/blob/master/PSX%20Dither.shader

class DitherShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var textureW : Float;
		@param var textureH : Float;

		@param var ditherPattern : Sampler2D;
		@param var colors : Float;
		@param var ditherPatternW : Float;
		@param var ditherPatternH : Float;

		function channelError(col: Float, colMin: Float, colMax: Float): Float
		{
			var range: Float = abs(colMin - colMax);
			var aRange: Float = abs(col - colMin);
			return  aRange / range;
		}

		function ditheredChannel( err: Float, ditherBlockUV: Vec2, ditherSteps: Float): Float
		{
			err = floor(err * ditherSteps) / ditherSteps;

			var ditherUV = vec2(err, 0);
			ditherUV.x += ditherBlockUV.x;
			ditherUV.y = ditherBlockUV.y;

			return ditherPattern.get(ditherUV).x;
		}

		function mix_unused(a: Float, b: Float, amt: Float): Float
		{
			return ((1.0 - amt) * a) + (b * amt);
		}

		/// YUV/RGB color space calculations

		function RGBtoYUV(rgba: Vec4): Vec4
		{
			var yuva: Vec4;
			yuva.r = rgba.r * 0.2126 + 0.7152 * rgba.g + 0.0722 * rgba.b;
			yuva.g = (rgba.b - yuva.r) / 1.8556;
			yuva.b = (rgba.r - yuva.r) / 1.5748;
			yuva.a = rgba.a;

			// Adjust to work on GPU
			yuva.gb += 0.5;

			return yuva;
		}

		function YUVtoRGB(yuva: Vec4 ) : Vec4 {
                yuva.gb -= 0.5;
                return vec4(
                    yuva.r * 1 + yuva.g * 0 + yuva.b * 1.5748,
                    yuva.r * 1 + yuva.g * -0.187324 + yuva.b * -0.468124,
                    yuva.r * 1 + yuva.g * 1.8556 + yuva.b * 0,
                    yuva.a);
            }

		function UVtoRGB(yuva: Vec4): Vec4
		{
			yuva.gb -= 0.5;
			return vec4(
				yuva.r * 1 + yuva.g * 0 + yuva.b * 1.5748,
				yuva.r * 1 + yuva.g * -0.187324 + yuva.b * -0.468124,
				yuva.r * 1 + yuva.g * 1.8556 + yuva.b * 0,
				yuva.a);
		}

		function fragment()
		{

			 // sample the texture and convert to YUV color space
			var col = texture.get( calculatedUV );
			var yuv = RGBtoYUV( col );

			// Clamp the YUV color to specified color depth (default: 32, 5 bits per channel, as per playstation hardware)
			var col1 = floor(yuv * colors) / colors;
			var col2 = ceil(yuv * colors) / colors;

			// Calculate dither texture UV based on the input texture
			var ditherSize = ditherPatternH;
			var ditherSteps = ditherPatternW/ditherSize;

			var ditherBlockUV = calculatedUV;

			var dw = ditherSize / textureW;
			var dh = ditherSize / textureH;

			ditherBlockUV.x %= dw;
			ditherBlockUV.x /= dw;
			ditherBlockUV.y %= dh;
			ditherBlockUV.y /= dh;
			ditherBlockUV.x /= ditherSteps;

			// Dither each channel individually

			yuv.x = mix(col1.x, col2.x, ditheredChannel(channelError(yuv.x, col1.x, col2.x), ditherBlockUV, ditherSteps));
			yuv.y = mix(col1.y, col2.y, ditheredChannel(channelError(yuv.y, col1.y, col2.y), ditherBlockUV, ditherSteps));
			yuv.z = mix(col1.z, col2.z, ditheredChannel(channelError(yuv.z, col1.z, col2.z), ditherBlockUV, ditherSteps));

			pixelColor = YUVtoRGB(yuv);


		}
	}

}