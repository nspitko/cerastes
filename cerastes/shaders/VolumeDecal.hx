package cerastes.shaders;

class VolumeDecal extends hxsl.Shader {
	static var SRC = {

		@global var global : {
			var time : Float;
			var pixelSize : Vec2;
			@perObject var modelView : Mat4;
			@perObject var modelViewInverse : Mat4;
		};

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

		var output : {
			color : Vec4
		};

		@const var CENTERED : Bool;

		@global var depthMap : Channel;

		@param var maxAngle : Float;
		@param var fadePower : Float;
		@param var fadeStart : Float;
		@param var fadeEnd : Float;
		@param var emissive : Float;

		@param var colorTexture : Sampler2D;

		var calculatedUV : Vec2;
		var pixelColor : Vec4;
		var pixelTransformedPosition : Vec3;
		var projectedPosition : Vec4;
		var localPos : Vec3;

		function outsideBounds() : Bool {
			return ( localPos.x > 0.5 || localPos.x < -0.5 || localPos.y > 0.5 || localPos.y < -0.5 || localPos.z > 0.5 || localPos.z < -0.5 );
		}

		function fragment() {

			var matrix = camera.inverseViewProj * global.modelViewInverse;
			var screenPos = projectedPosition.xy / projectedPosition.w;
			var depth = depthMap.get(screenToUv(screenPos));
			var ruv = vec4( screenPos, depth, 1 );
			var wpos = ruv * matrix;
			var ppos = ruv * camera.inverseViewProj;

			pixelTransformedPosition = ppos.xyz / ppos.w;
			localPos = (wpos.xyz / wpos.w);
			calculatedUV = localPos.xy;
			var fadeFactor = 1 - clamp( pow( max( 0.0, abs(localPos.z * 2) - fadeStart) / (fadeEnd - fadeStart), fadePower), 0, 1);

			if( CENTERED )
				calculatedUV += 0.5;

			if(	outsideBounds() )
				discard;

			var color = colorTexture.get(calculatedUV);
			pixelColor.rgb = color.rgb + color.rgb * emissive;
			pixelColor.a = max(max(pixelColor.r, pixelColor.g), pixelColor.b) * fadeFactor;
			if( max(max(pixelColor.r, pixelColor.g), pixelColor.b) < 0 )
				discard;
		}
	}

	public function new( ) {
		super();
	}
}