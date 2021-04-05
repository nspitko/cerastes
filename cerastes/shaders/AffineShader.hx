package cerastes.shaders;

class AffineShader extends hxsl.Shader {
    static var SRC = {

		@const var additive : Bool;
		@const var killAlpha : Bool = true;
		@range(0,1) @param var killAlphaThreshold : Float = 0.1;

		var zOffset : Float;

		var calculatedUV : Vec2;

		var pixelColor : Vec4;


		@param var texture : Sampler2D;

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
			var uv : Vec2; 
			var normal: Vec3;
			var position : Vec3;
			
		};





			function vertex()
			{
				//transformedPosition = input.position;
				//transformedPosition.xyz = input.position * global.modelView.mat3x4();
				//var modelviewposition = vec4( transformedPosition, 0.3) * global.modelViewInverse;
				//transformedPosition.xyz = floor(transformedPosition.xyz/transformedPosition.w*(1./4.))*4.*transformedPosition.w;

				//Vertex snapping
//				var distance = length(  projectedPosition * global.modelView.mat3x4() );

				// Affine texture mapping

				// https://stackoverflow.com/questions/14942210/opengl-shading-language-transform-tex
				// #define TRANSFORM_TEX(tex,name) (tex.xy * name##_ST.xy + name##_ST.zw)
				// calculatedUV  = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				//calculatedUV  *= distance + (worldPosition.w*(UNITY_LIGHTMODEL_AMBIENT.a * 8)) / distance / 2;
				//calculatedNormal = distance + (worldPosition.w*(UNITY_LIGHTMODEL_AMBIENT.a * 8)) / distance / 2;

				var transformedPosition = input.position * global.modelView.mat3x4();
				var projectedPosition = vec4(transformedPosition, 1) * camera.viewProj;
				zOffset = projectedPosition.z;

				//worldDist = length(transformedPosition - camera.position) / camera.zFar;

				//calculatedUV = input.uv;
				//calculatedUV  *= worldDist + (projectedPosition.w) / worldDist  / 2;
				//transformedNormal = vec3( worldDist + (projectedPosition.w) / worldDist  / 2 );

				calculatedUV = input.uv * zOffset;
			}

			function fragment()
			{
				var c = texture.get( calculatedUV.xy/zOffset );
				if( killAlpha && c.a - killAlphaThreshold < 0 ) discard;
				if( additive )
					pixelColor += c;
				else
					pixelColor *= c;
			}		
    };

		public function new(?tex) 
		{
			super();
			this.texture = tex;
		}
}