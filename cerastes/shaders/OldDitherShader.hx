package cerastes.shaders;

// Generic dither shader
// ref http://alex-charlton.com/posts/Dithering_on_the_GPU/

class OldDitherShader extends h3d.shader.ScreenShader {

	static var SRC = {


		@param @const var Colors : Int;
		@param var palette : Sampler2D;
		@param var texture : Sampler2D;
		@param var ditherTable : Sampler2D;
											


		function indexValue() : Float
		{
			var x: Int = int(mod(calculatedUV.x, 4));
			var y: Int = int(mod(calculatedUV.y, 4));
			return ( ditherTable.get(vec2(( x + y * 4) / 16,0)).r * 256) / 16.0;
		}

		function hueDistance(h1: Float, h2: Float): Float 
		{
			var diff: Float = abs((h1 - h2));
			return min(abs((1.0 - diff)), diff);
		}

		//function closestColors(hue: Float): Array<Float3,2>
		function dither(color: Vec3): Vec3 
		{
			//

			var hsl = rgbToHsl(color);
			var hue = hsl.x;

			//
			var closest = vec3(-2, 0, 0);
			var secondClosest = vec3(-2, 0, 0);
			var temp: Vec3;
			for (i in 0 ... 256) 
			{
				// @fixme
				temp = palette.get( vec2(i/256.0,0.5 ) ).rgb;
				var tempDistance = hueDistance(temp.x, hue);
				if (tempDistance < hueDistance(closest.x, hue)) {
					secondClosest = closest;
					closest = temp;
				} else {
					if (tempDistance < hueDistance(secondClosest.x, hue)) {
						secondClosest = temp;
					}
				}
			}
			//return hslToRgb( closest );

			//ret[0] = closest;
			//ret[1] = secondClosest;
		
		/*	return ret;
		}

		function dither(color: Vec3): Vec3 
		{*/
			
	
			var d = indexValue();
			var hueDiff = hueDistance(hsl.x, closest.x) /
							hueDistance(secondClosest.x, closest.x);
			return hslToRgb(hueDiff < d ? closest : secondClosest);
		}

		// Helpers

		function RGBtoHCV(RGB: Vec3): Vec3
		{
			// Based on work by Sam Hocevar and Emil Persson
			var P = (RGB.g < RGB.b) ? vec4(RGB.bg, -1.0, 2.0/3.0) : vec4(RGB.gb, 0.0, -1.0/3.0);
			var Q = (RGB.r < P.x) ? vec4(P.xyw, RGB.r) : vec4(RGB.r, P.yzx);
			var C = Q.x - min(Q.w, Q.y);
			var H = abs((Q.w - Q.y) / (6 * C + 1e-10) + Q.z);
			return vec3(H, C, Q.x);
		}

		function HUEtoRGB(H: Float): Vec3
		{
			var R = abs(H * 6 - 3) - 1;
			var G = 2 - abs(H * 6 - 2);
			var B = 2 - abs(H * 6 - 4);
			return clamp(vec3(R,G,B), 0, 1);
		}

		function rgbToHsl(RGB: Vec3): Vec3
		{
			var HCV = RGBtoHCV(RGB);
			var L = HCV.z - HCV.y * 0.5;
			var S = HCV.y / (1 - abs(L * 2 - 1) + 1e-10);
			return vec3(HCV.x, S, L);
		}

		function hslToRgb(HSL: Vec3): Vec3
		{
			var RGB = HUEtoRGB(HSL.x);
			var C = (1 - abs(2 * HSL.z - 1)) * HSL.y;
			return (RGB - 0.5) * C + HSL.z;
		}							 



		
		function fragment() 
		{
				
			pixelColor = vec4(dither(texture.get( calculatedUV ).rgb ), 1);
	
		}
	}

}