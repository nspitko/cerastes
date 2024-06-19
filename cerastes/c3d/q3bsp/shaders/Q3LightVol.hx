package cerastes.c3d.q3bsp.shaders;

class Q3LightVol extends hxsl.Shader {

	static var SRC = {

		//
		@param var volSize : Vec3;
		@param var volOffset : Vec3;

		@param var ambient : Sampler2D;
		@param var directional : Sampler2D;
		@param var direction : Sampler2D;

		@global var camera : {
			var position : Vec3;
		};


		var lightColor : Vec3;
		var lightPixelColor : Vec3;
		var transformedPosition : Vec3;
		var pixelTransformedPosition : Vec3;
		var transformedNormal : Vec3;
		var specPower : Float;
		var specColor : Vec3;

		function rotation3d(axis: Vec3, angle: Float): Mat4
		{
			axis = normalize(axis);
			var s: Float = sin(angle);
			var c: Float = cos(angle);
			var oc: Float = 1.0 - c;

			return mat4(
				vec4( oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0 ),
				vec4( oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0 ),
				vec4( oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0 ),
				vec4( 0.0,                                0.0,                                0.0,                                1.0 )
			);
		  }

		function rotate(v: Vec3, axis: Vec3, angle: Float): Vec3
		{

			return ( vec4(v, 1.0) * rotation3d(axis, angle) ).xyz;
		}


		function calcLighting( position : Vec3 ) : Vec3 {

			// Map our local pos into texture space

			var volSpace = vec3( ( position.x - volOffset.x ) / 64, ( position.y - volOffset.y ) / 64, ( position.z - volOffset.z ) / 128 );

			var zPos = volSpace.z;
			var zIdx = floor(zPos);

			volSpace /= volSize;

			var ly = volSpace.y / volSize.z;
			ly +=  ( 1 / volSize.z ) * zIdx;

			var alv = ambient.get( vec2( volSpace.x, ly ) );

			var ambient = alv.rgb * vec3( ( 255/63 ) );
			//return ambient;

			// Now do directional
			var directionalv = directional.get( vec2( volSpace.x, ly ) );
			var dirv = direction.get( vec2( volSpace.x, ly ) );

			//return vec3(dirv.x, dirv.y, 0);



			var dirX = dirv.x * 6.28319 ;
			var dirY = dirv.y * 6.28319 - 1.5708;

			var lightDir = vec3(0,0,1);// rotate(, vec3(0,0,1), dirY);
			lightDir = rotate(lightDir, vec3(0,1,0), dirY);
			lightDir = rotate(lightDir, vec3(1,0,0), dirX);

			lightDir = lightDir.normalize();

			// @todo probably a less dumb solution here... Sorry GPU-kun!
			lightDir = vec3( -lightDir.x, -lightDir.y, -lightDir.z);

			var diff = max(dot(transformedNormal, lightDir), 0.0);

			return diff * ( directionalv.rgb *  ( 255/63 ) ) + ambient;




			return alv.rgb * vec3( ( 255/63 ) * 2 ) ;


		}

		function vertex() {
			//lightColor.rgb += calcLighting(transformedPosition);
		}

		function fragment() {
			// Disabled for now.
			//lightPixelColor.rgb += calcLighting(pixelTransformedPosition);
		}

	};

	public function new() {
		super();
	}

}