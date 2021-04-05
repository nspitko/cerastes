package cerastes.shaders;

class FixedPointShader extends hxsl.Shader {
    static var SRC = {

		var relativePosition : Vec3;
		var transformedPosition : Vec3;

		@global var global : {
			var time : Float;
			var pixelSize : Vec2;
			@perObject var modelView : Mat4;
			@perObject var modelViewInverse : Mat4;
		};
	
        @input var input : { 
			var position : Vec3;
			
		};



			function vertex()
			{
				//transformedPosition = input.position;
				//transformedPosition.xyz = input.position * global.modelView.mat3x4();
				//var modelviewposition = vec4( transformedPosition, 0.3) * global.modelViewInverse;
				//transformedPosition.xyz = floor(transformedPosition.xyz/transformedPosition.w*(1./4.))*4.*transformedPosition.w;

				//Vertex snapping
				var snapToPixel = vec4( input.position, 1) * global.modelView;
				var point : Vec4 = snapToPixel;
				point.xyz = snapToPixel.xyz / snapToPixel.w;
				point.x = floor(160 * point.x) / 160;
				point.y = floor(120 * point.y) / 120;
				point.xyz *= snapToPixel.w;
				transformedPosition = point.xyz;
			}


		
    };
}