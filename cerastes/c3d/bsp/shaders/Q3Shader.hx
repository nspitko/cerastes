package cerastes.c3d.bsp.shaders;


class Q3Shader extends hxsl.Shader {
    static var SRC = {

		@const var additive : Bool;
		@const var killAlpha : Bool = true;
		@range(0,1) @param var killAlphaThreshold : Float = 0.1;

		var calculatedUV : Vec2;
		var calculatedLMUV : Vec2;
		var pixelColor : Vec4;


		@param var texture : Sampler2D;
		@param var lightMapTexture : Sampler2D;


        @input var input : {
			var uv : Vec2;
			var uvlm : Vec2;
		};




			function vertex()
			{
				calculatedUV = input.uv;
				calculatedLMUV = input.uvlm;
			}

			function fragment()
			{
				var c = texture.get( vec2( calculatedUV.x, calculatedUV.y ) );
				var clm = lightMapTexture.get( vec2( calculatedLMUV.x, calculatedLMUV.y ) ) ;
				//if( killAlpha && c.a - killAlphaThreshold < 0 ) discard;
				if( additive )
					pixelColor += c * clm;
				else
					pixelColor *= c * clm;
			}
    };

		public function new(?tex)
		{
			super();
			this.texture = tex;
		}
}