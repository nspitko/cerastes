package cerastes.shaders;

class LightMap extends hxsl.Shader {

	static var SRC = {
		@input var input : {
			var lightmapuv : Vec2;
		};

		@param var lightmap : Sampler2D;

		var lightColor : Vec3;
		var lightPixelColor : Vec3;
		var pixelColor : Vec4;

		var calculatedLMUV : Vec2;


		function vertex() {
			calculatedLMUV = input.lightmapuv;
		}

		function fragment() {
			var intensity = lightmap.get(calculatedLMUV);
			intensity += 0.4;
			pixelColor.rgb = saturate( pixelColor.rgb* intensity.r );
		}

	}

	public function new(?tex) {
		this.lightmap = tex;
		super();
	}

}