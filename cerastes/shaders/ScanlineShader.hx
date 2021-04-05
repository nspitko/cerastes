package cerastes.shaders;

class ScanlineShader extends h3d.shader.ScreenShader {

	static var SRC = {

		@param var texture : Sampler2D;
		@param var transitionTexture : Sampler2D;
		@param var phase : Float;
		@highp var idx : Float;

	
		function fragment() 
		{
			idx = calculatedUV.y * 720.;
			// int mod required GLES 3.0, use floats and floor...
			//var y : Int = int( idx );
			
			var amt = 0.8;
			var c = texture.get( calculatedUV );
			if( floor( idx ) % 2 == 1 )
			{
				c.r *= amt;
				c.g *= amt;
				c.b *= amt;
			}
			
		
			pixelColor = c;

	
		}
	}

}