package cerastes;

import cerastes.Entity.EntityManager;
import h3d.impl.TextureCache;
import h3d.mat.DepthBuffer;
import h3d.mat.Texture;
import h2d.Bitmap;
import h2d.RenderContext;
import h3d.scene.*;
import cerastes.shaders.DitherShader;
import cerastes.ui.Console;
import h2d.Scene.ScaleModeAlign;

class PSXScene extends cerastes.Scene
{
	var texSceneRT: Texture;
	var depthSceneRT: DepthBuffer;
	var s2dDither : h2d.Scene;

	public function new( a : Main )
    {
		super( a );



		texSceneRT = new Texture(265,135, [Target] );
		depthSceneRT = new DepthBuffer(265, 135 );
		texSceneRT.depthBuffer = depthSceneRT;

		s2d.scaleMode  = LetterBox(640,360,true,ScaleModeAlign.Top, ScaleModeAlign.Left);
		s2d.defaultSmooth = false;



		var bmp = new Bitmap( h2d.Tile.fromTexture( texSceneRT ) );

		bmp.scale(2);
		bmp.x = 69;
		bmp.y = 14;
		//bmp.filter = new cerastes.pass.DitherFilter();
		s2d.addChild(bmp);


		s3d.lightSystem.ambientLight.set(1, 1, 1);

    }

	public override function enter()
	{
		super.enter();
		@:privateAccess EntityManager.instance = new EntityManager();

		GlobalConsole.currentScene = this;
	}



	public override function render(e:h3d.Engine)
    {
		// Prep
		//texSceneRT.clear( 0 );


		// Render 3d scene
		app.engine.pushTarget( texSceneRT );
		app.engine.clear(0,1);
        s3d.render(e);
		app.engine.popTarget();

		// Render 2d scene

		s2d.render(e);

    }



}


