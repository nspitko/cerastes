package cerastes.shaders;

class PBRDepth extends hxsl.Shader {
	static var SRC = {

		@param var heightMap : Sampler2D;


		var calculatedUV : Vec2;
		var depth : Float;
		var emissive : Float;

		function __init__fragment() {
			{
				var v = heightMap.get(calculatedUV);
				depth = v.r;

				emissive = 1;
			}
		}

		function fragment() {
			emissive = 1;
		}
	}

	public function new(?t) {
		super();
		this.heightMap = t;
	}
}