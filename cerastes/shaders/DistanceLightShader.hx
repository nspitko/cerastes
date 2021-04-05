package cerastes.shaders;
import h3d.shader.BaseMesh;

class DistanceLightShader extends hxsl.Shader {

	static var SRC = {

		var pixelColor : Vec4;
		var cameraDist: Float;

		var worldDist : Float;

		@global var camera : {
			var view : Mat4;
			var proj : Mat4;
			var position : Vec3;
			var projFlip : Float;
			var projDiag : Vec3;
			var viewProj : Mat4;
			var inverseViewProj : Mat4;
			var zNear : Float;
			var zFar : Float;
			@var var dir : Vec3;
		};

		@global var global : {
			var time : Float;
			var pixelSize : Vec2;
			@perObject var modelView : Mat4;
			@perObject var modelViewInverse : Mat4;
		};

		@input var input : {
			var position : Vec3;
			var normal : Vec3;
		};

		var output : {
			var position : Vec4;
			var color : Vec4;
			var depth : Float;
			var normal : Vec3;
			var worldDist : Float;
		};

		function __init__() {
			worldDist = length(( input.position * global.modelView.mat3x4() ) - camera.position) / camera.zFar;
		}


		function fragment()
		{

			var normalizedDepth = clamp(worldDist * 500,0,1);

			var rampedDepth = 1.0 / (1.0 + 0.2*normalizedDepth + 2.0*(normalizedDepth*normalizedDepth));


			//var adjustedDepth = 1 / ( 10 * worldDist );


			var steppedDepth: Int = int( rampedDepth * 6  );
			var clampedDepth: Float = float( steppedDepth ) / 6.;

			pixelColor.rgb = pixelColor.rgb * clampedDepth;


		}
	}

}