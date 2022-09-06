package cerastes.c3d.q3bsp;

import h3d.Vector;
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

class Q3BSPLightVol extends h3d.scene.fwd.Light
{
	var bsp: BSPFileDef;

	var texAmbient: Texture;
	var texDirectional: Texture;
	var texDirection: Texture;

	var volShader: cerastes.c3d.q3bsp.shaders.Q3LightVol;


	//public override function onCreated( def: EntityData )
	public function new( def: EntityData )
	{

		this.bsp = def.bsp;

		generateVolTextures();

		super( volShader );

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

		shader = volShader = new cerastes.c3d.q3bsp.shaders.Q3LightVol();

		volShader.volSize.set( nx, ny, nz);
		volShader.volOffset.set( bsp.models[0].mins[0], bsp.models[0].mins[1], bsp.models[0].mins[2] );

		volShader.ambient = texAmbient;
		volShader.directional = texDirectional;
		volShader.direction = texDirection;


		//debugDrawVolLights();
	}

	function debugDrawVolLights()
	{
		var nx = CMath.floor(bsp.models[0].maxs[0] / 64) - CMath.ceil(bsp.models[0].mins[0] / 64) + 1;
		var ny = CMath.floor(bsp.models[0].maxs[1] / 64) - CMath.ceil(bsp.models[0].mins[1] / 64) + 1;
		var nz = CMath.floor(bsp.models[0].maxs[2] / 128) - CMath.ceil(bsp.models[0].mins[2] / 128) + 1;

		for( z in 0 ... nz )
		{
			for( y in 0 ... ny )
			{
				//var y = ny - fy - 1;
				for( x in 0 ... nx )
				{
					var scale = 2;
					var idx = x + y * nx + z * ( nx * ny );

					var v = bsp.lightMapVols[idx];
					var col = CMath.floor( scale * v.ambient[0] ) << 16 | CMath.floor( scale *v.ambient[1] ) << 8 | CMath.floor( scale * v.ambient[2] );
					var cold = 0;// CMath.floor( scale * v.directional[0] ) << 16 | CMath.floor( scale *v.directional[1] ) << 8 | CMath.floor( scale * v.directional[0] );

					var pos = new Point( (x + 0.5 ) * 64 + bsp.models[0].mins[0], (y + 0.5) * 64 + bsp.models[0].mins[1], ( 0.5 + z ) * 128 + bsp.models[0].mins[2] );
					DebugDraw.box( pos, new Point(10,10,10), col + cold, -1 );

					var mat = new Matrix();
					var angX = ( v.dir[0] / 255 ) * 6.28319;// - 1.5708 ; // byte to radian
					var angY = ( v.dir[1] / 255 ) * 6.28319 + 1.5708; // byte to radian


/*
					var norm = new Vector(0,1,0);
					mat.initRotationAxis(new Vector(0,0,1), angY);
					norm.transform(mat);

*/

					var norm = new Vector(0,0,1);
					mat.initRotationAxis(new Vector(0,1,0), angY);
					norm.transform(mat);

					mat.initRotationAxis(new Vector(1,0,0), angX);
					norm.transform(mat);



					DebugDraw.line( pos, pos.add( norm.toPoint().multiply(32) ),0xFF0000,-1 );


				}
			}
		}


	}

	/*
	public override function imguiUpdate()
	{
		ImGui.begin("lightvols");

		ImGuiTools.image( Tile.fromTexture( texAmbient ), {x: 8, y: 8} );
		ImGui.sameLine();
		ImGuiTools.image( Tile.fromTexture( texDirectional ), {x: 8, y: 8} );
		ImGui.end();
	}
	*/
}