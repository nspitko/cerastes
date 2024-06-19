package cerastes.c3d.q3bsp.shaders;


class Q3PBRLightmapShader extends hxsl.Shader {
    static var SRC = {

		@const var additive : Bool;
		@const var killAlpha : Bool = true;
		@range(0,1) @param var killAlphaThreshold : Float = 0.1;

		var calculatedUV : Vec2;
		var calculatedLMUV : Vec2;
		var pixelColor : Vec4;


		@param var texture : Sampler2D;
		//@param var lightMapTexture : Sampler2D;

		//var pbrLightColor : Vec3;


        @input var input : {
			var uv : Vec2;
			var uvlm : Vec2;
		};

		// ???
		var lightPixelColor : Vec3;




		function vertex()
		{
			calculatedLMUV = input.uvlm;
		}

		function fragment()
		{

			var clm = texture.get( vec2( calculatedLMUV.x, calculatedLMUV.y ) ) ;

			// q3a lightmaps only
			//clm.rgb *= vec3(4.0477);

			// 20% overbright
			clm.rgb *= vec3(2);

			//if( killAlpha && c.a - killAlphaThreshold < 0 ) discard;

			// Lightmaps are greyscale; but there's a weird bug where the r channel is getting
			// polluted (maybe bad RGBA<->ARGB conversion?), so use G instead.
			//pixelColor.rgb *= clm.g;
			lightPixelColor.rgb += clm.g;
		}
    };

	public function new(?tex)
	{
		super();
		this.texture = tex;
	}
}