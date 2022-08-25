package cerastes.shaders;

import h3d.shader.pbr.Light;

class LightMap extends hxsl.Shader {

	static var SRC = {
		@input var input : {
			var lightmapuv : Vec2;
		};


		@param var lightmap : Sampler2D;

		var calculatedLMUV : Vec2;

		var pixelColor : Vec4;


		function vertex() {
			calculatedLMUV = input.lightmapuv;
		}

		function fragment() {
			var intensity = lightmap.get(calculatedLMUV);
			//intensity += 0.4;

			pixelColor.rgb *= intensity.rgb;
		}

	}

	public function new(?tex) {
		this.lightmap = tex;
		super();
	}

}