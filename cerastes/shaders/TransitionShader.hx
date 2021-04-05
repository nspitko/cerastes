package cerastes.shaders;


class TransitionShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var transitionTexture : Sampler2D;
		@param var phase : Float;

	
		function fragment() 
		{
			
			 // sample the texture and convert to YUV color space
			var src = texture.get( calculatedUV );
			var step = transitionTexture.get( calculatedUV );
		
			pixelColor = step.r > phase ? src : vec4(0,0,0,0);

	
		}
	}

}