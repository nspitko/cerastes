package cerastes.shaders;

class ScreenSpaceShader extends hxsl.Shader {
    static var SRC = {

		@const var additive : Bool;
		@const var killAlpha : Bool = true;
		@range(0,1) @param var killAlphaThreshold : Float = 0.1;

		var zOffset : Float;

		var screenPos : Vec3;


		var pixelColor : Vec4;


		@param var texture : Sampler2D;
		@param var blendmix : Float;

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

				//var transformedPosition = input.position * global.modelView.mat3x4();
				//var projectedPosition = vec4(transformedPosition, 1) * camera.viewProj;
				//zOffset = projectedPosition.z;

				//worldDist = length(transformedPosition - camera.position) / camera.zFar;

				//calculatedUV = input.uv;
				//calculatedUV  *= worldDist + (projectedPosition.w) / worldDist  / 2;
				//transformedNormal = vec3( worldDist + (projectedPosition.w) / worldDist  / 2 );
				var transformedPosition = input.position;
				transformedPosition = transformedPosition * global.modelView.mat3x4();
				transformedPosition = transformedPosition * camera.viewProj.mat3x4();

				var modelviewposition = transformedPosition.xyz;

				screenPos = modelviewposition.xyz;
			}

			function fragment()
			{
				var screenUV = (screenPos.xy / screenPos.z) * 0.5 + 0.5;
				var base = pixelColor;
				var blend = texture.get( screenUV );



				var pass1 = vec4(
					((blend.r < 0.5) ? (2.0 * base.r * blend.r + base.r * base.r * (1.0 - 2.0 * blend.r)) : (sqrt(base.r) * (2.0 * blend.r - 1.0) + 2.0 * base.r * (1.0 - blend.r))),
					((blend.g < 0.5) ? (2.0 * base.g * blend.g + base.g * base.g * (1.0 - 2.0 * blend.g)) : (sqrt(base.g) * (2.0 * blend.g - 1.0) + 2.0 * base.g * (1.0 - blend.g))),
					((blend.b < 0.5) ? (2.0 * base.b * blend.b + base.b * base.g * (1.0 - 2.0 * blend.b)) : (sqrt(base.b) * (2.0 * blend.b - 1.0) + 2.0 * base.b * (1.0 - blend.b))),
					blend.a
				);




				pixelColor = mix( pixelColor, pass1, blendmix );

				//if( killAlpha && c.a - killAlphaThreshold < 0 ) discard;
				//if( additive )
					//pixelColor -= vec4( c.rgb * c.w, 1);
					//pixelColor = c;
				//else
				//	pixelColor *= c;
			}
    };

		public function new(?tex)
		{
			super();
			this.texture = tex;
		}
}