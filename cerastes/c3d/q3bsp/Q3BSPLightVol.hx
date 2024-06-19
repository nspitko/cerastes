package cerastes.c3d.q3bsp;

import h3d.Quat;
import cerastes.c3d.entities.Light;
import h3d.Vector;
import h3d.Vector4;
import h3d.Matrix;
import h3d.col.Point;
import cerastes.c3d.Entity.EntityData;
import hxd.PixelFormat;
import h2d.Tile;

import h3d.mat.Texture;
import hxd.Pixels;
import h3d.scene.Object;
import cerastes.c3d.q3bsp.Q3BSPFile.BSPFileDef;

#if hlimgui
import cerastes.tools.ImguiTools.ImGuiTools;
import imgui.ImGui;
#end

class Q3BSPLightVol extends Entity
{
	var bsp: BSPFileDef;

	var texAmbient: Texture;
	var texDirectional: Texture;
	var texDirection: Texture;

	var volShader: cerastes.c3d.q3bsp.shaders.Q3LightVol;

	var debugLightVolumes: Bool = true;


	public override function onCreated( def: EntityData )
	{
		super.onCreated(def);
		this.bsp = def.bsp;

		generateVolTextures();

	}


	public function generateVolTextures()
	{
		/**
		 * nx = floor(models[0].maxs[0] / 64) - ceil(models[0].mins[0] / 64) + 1
		 * ny = floor(models[0].maxs[1] / 64) - ceil(models[0].mins[1] / 64) + 1
		 * nz = floor(models[0].maxs[2] / 128) - ceil(models[0].mins[2] / 128) + 1
		 */
		// Determine level dimensions
		var nx = CMath.floor(bsp.models[0].maxs[0] / 64) - CMath.ceil(bsp.models[0].mins[0] / 64) + 1;
		var ny = CMath.floor(bsp.models[0].maxs[1] / 64) - CMath.ceil(bsp.models[0].mins[1] / 64) + 1;
		var nz = CMath.floor(bsp.models[0].maxs[2] / 128) - CMath.ceil(bsp.models[0].mins[2] / 128) + 1;

		trace('Dimensions: $nx x $ny with height of $nz');

		// Create textures for ambient and directional lights, plus a third for direction vectors

		var ambient = Pixels.alloc(nx,ny * nz, PixelFormat.RGBA );
		var ambientpixels: hxd.impl.UncheckedBytes = ambient.bytes;

		var directional = Pixels.alloc(nx,ny * nz, PixelFormat.RGBA );
		var directionalpixels: hxd.impl.UncheckedBytes = directional.bytes;

		var direction = Pixels.alloc(nx,ny * nz, PixelFormat.RGBA );
		var directionpixels: hxd.impl.UncheckedBytes = direction.bytes;


		// @todo: We could probably stuff direction data into the alpha channels in ambient/directional?
		for ( x in 0...bsp.lightMapVols.length )
		{
			var cursor = x * 4;
			var v = bsp.lightMapVols[x];

			ambientpixels[cursor + 0] = v.ambient[0];
			ambientpixels[cursor + 1] = v.ambient[1];
			ambientpixels[cursor + 2] = v.ambient[2];
			ambientpixels[cursor + 3] = 255;

			directionalpixels[cursor + 0] = v.directional[0];
			directionalpixels[cursor + 1] = v.directional[1];
			directionalpixels[cursor + 2] = v.directional[2];
			directionalpixels[cursor + 3] = 255;

			directionpixels[cursor + 0] = v.dir[0];
			directionpixels[cursor + 1] = v.dir[1];
			directionpixels[cursor + 3] = 255;
		}

		texAmbient = Texture.fromPixels( ambient );
		texDirectional = Texture.fromPixels( directional );
		texDirection = Texture.fromPixels( direction );

		volShader = new cerastes.c3d.q3bsp.shaders.Q3LightVol();

		volShader.volSize.set( nx, ny, nz);
		volShader.volOffset.set( bsp.models[0].mins[0], bsp.models[0].mins[1], bsp.models[0].mins[2] );

		volShader.ambient = texAmbient;
		volShader.directional = texDirectional;
		volShader.direction = texDirection;

	}

	function debugDrawVolLights()
	{
		var nx = CMath.floor(bsp.models[0].maxs[0] / 64) - CMath.ceil(bsp.models[0].mins[0] / 64) + 1;
		var ny = CMath.floor(bsp.models[0].maxs[1] / 64) - CMath.ceil(bsp.models[0].mins[1] / 64) + 1;
		var nz = CMath.floor(bsp.models[0].maxs[2] / 128) - CMath.ceil(bsp.models[0].mins[2] / 128) + 1;

		var size = new Vec3(
			bsp.models[0].maxs[0] - bsp.models[0].mins[0],
			bsp.models[0].maxs[1] - bsp.models[0].mins[1],
			bsp.models[0].maxs[2] - bsp.models[0].mins[2],
		);

		DebugDraw.box(
			new Vec3(
				bsp.models[0].mins[0] + size.x / 2,
				bsp.models[0].mins[1] + size.y / 2,
				bsp.models[0].mins[2] + size.z / 2
			),
			size, 0xFFFF00
		);

		for( z in 0 ... nz )
		{
			for( y in 0 ... ny )
			{
				//var y = ny - fy - 1;
				for( x in 0 ... nx )
				{
					var scale = 2;

					// Correct for z flip
					var lx = nx - x - 1;

					var idx = lx + y * nx + z * ( nx * ny );

					var v = bsp.lightMapVols[idx];
					var col = CMath.floor( scale * v.ambient[0] ) << 16 | CMath.floor( scale *v.ambient[1] ) << 8 | CMath.floor( scale * v.ambient[2] );
					var cold =  CMath.floor( scale * v.directional[0] ) << 16 | CMath.floor( scale *v.directional[1] ) << 8 | CMath.floor( scale * v.directional[0] );

					var pos = new Point( (x ) * 64 + bsp.models[0].mins[0], (y) * 64 + bsp.models[0].mins[1], (  z ) * 128 + bsp.models[0].mins[2] );
					DebugDraw.box( pos, new Point(10,10,10), col );

					var mat = new Matrix();
					var phi = ( 270 - ( v.dir[0] / 255 ) * 360 ) * 0.0174533;
					var theta = ( ( v.dir[1] / 255 ) * 360 ) * 0.0174533;

					var q = new Quat();
					q.initDirection(new Vector(0,1,0));


					var norm = new Vector(1,0,0);



					mat.initRotationAxis(new Vector(0,0,1), theta );
					norm.transform(mat);

					mat.initRotationAxis(new Vector(1,0,0), phi);
					norm.transform(mat);

					//norm = getDirectionFromPitchYaw(v.dir[0], v.dir[1]);

					if( cold != col )
						DebugDraw.line( pos, pos.add( norm.toVector() * 32 ), cold);


				}
			}
		}


	}

	function getDirectionFromPitchYaw( pitch: Int, yaw: Int )
	{
		// Rescale pitch/yaw from 0-255 range to 0-360 degrees
		var pitchDegrees = pitch * 360.0 / 255.0;
		var yawDegrees = yaw * 360.0 / 255.0;

		pitchDegrees = 270 - pitchDegrees;

		// Define initial view and up vectors
		var viewX = 1.0, viewY = 0.0, viewZ = 0.0;
		var upX = 0.0, upY = 1.0, upZ = 0.0;

		// Rotate view vector around up vector by yaw
		var yawRad = yawDegrees * 0.0174533;
		var cosYaw = Math.cos(yawRad);
		var sinYaw = Math.sin(yawRad);
		var xzyaw = viewX * cosYaw + viewZ * sinYaw;
		var zyaw = -viewX * sinYaw + viewZ * cosYaw;

		// Rotate resulting vector around view vector by pitch
		var pitchRad = pitchDegrees * 0.0174533;
		var cosPitch = Math.cos(pitchRad);
		var sinPitch = Math.sin(pitchRad);
		var dirX = xzyaw;
		var dirY = viewY * cosPitch - zyaw * sinPitch;
		var dirZ = viewY * sinPitch + zyaw * cosPitch;

		return new Vector(dirX, dirY, dirZ);
	}

#if hlimgui

	var imSlice: Int = 0;
	var imScale: Int = -1;
	public override function imguiUpdate()
	{
		ImGui.begin("Light Debugger");

		var nx = CMath.floor(bsp.models[0].maxs[0] / 64) - CMath.ceil(bsp.models[0].mins[0] / 64) + 1;
		var ny = CMath.floor(bsp.models[0].maxs[1] / 64) - CMath.ceil(bsp.models[0].mins[1] / 64) + 1;
		var nz = CMath.floor(bsp.models[0].maxs[2] / 128) - CMath.ceil(bsp.models[0].mins[2] / 128) + 1;

		ImGui.text('Light volume dimensions: $nx, $ny, $nz');
		ImGui.checkbox("Debug Volumes", debugLightVolumes );
		ImGui.checkbox("Debug Lights", Light.debugLights );
		ImGui.inputInt("Z",imSlice,1,5);
		imSlice = CMath.iclamp(imSlice,0,nz-1);

		var sliceSize = 1/nz;

		if( imScale == -1 )
			imScale = Math.floor( 400 / CMath.imax(nx, ny) );

		ImGui.text("Ambient");
		ImGui.image(texAmbient,{ x: nx * imScale, y: ny * imScale }, {x: 0, y: imSlice * sliceSize}, {x: 1, y: sliceSize * (imSlice+1)}, new ImVec4(1,1,1,1), new ImVec4(1,1,1,1));
		ImGui.text("Directional");
		ImGui.image(texDirectional,{ x: nx * imScale, y: ny * imScale }, {x: 0, y: imSlice * sliceSize}, {x: 1, y: sliceSize * (imSlice+1)}, new ImVec4(1,1,1,1), new ImVec4(1,1,1,1));

		if( debugLightVolumes )
			debugDrawVolLights();

	}
#end

}