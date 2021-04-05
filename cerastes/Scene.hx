package cerastes;

import cerastes.ui.Console.GlobalConsole;
import hxd.fmt.fbx.BaseLibrary.TmpObject;
import haxe.Constraints;


class Scene
{

    public var app(default,null) : Main;
    public var engine(default,null) : h3d.Engine;
	public var s3d(default,null) : h3d.scene.Scene;
	public var s2d(default,null) : h2d.Scene;

    public function new( a : Main )
    {
        app = a;
        s3d = new h3d.scene.Scene();
        s2d = new h2d.Scene();
    }


    /**
     *  Called before the scene is presented, to allow assets to be loaded before enter()
     */
    public function preload()
    {

    }

    /**
     *  Called when rendering is handed off to this scene
     */
    public function enter()
    {
        app.sevents.addScene(this.s2d);
        app.sevents.addScene(this.s3d);
        GlobalConsole.instance.currentScene = this;

        s2d.defaultSmooth = false;
		s2d.scaleMode = ScaleMode.LetterBox(1280, 720,false,Center,Center);

    }

    /**
     *  Logic update loop.
     *  @param delta - Delta time since last call.
     */
    public function tick( delta:Float )
    {
        s2d.checkResize();
    }

    /**
     *  Actual render frame function
     *  @param e - Engine
     */
    public function render(e:h3d.Engine)
    {
        s3d.render(e);
        s2d.render(e);

    }

    /**
     *  Called before rendering has been handed off to another scene.
     */
    public function exit()
    {
        app.sevents.removeScene(this.s3d);
        app.sevents.removeScene(this.s2d);
    }

    /**
     *  Called after the scene is about to be dereferenced.
     */
    public function unload()
    {

    }

    /**
     *  Called when an external resource has changed.
     */
    public function contentChanged()
    {

    }

    public function switchToScene( other:Scene )
    {
        // @todo Move preload into another function, allow current scene to spin until target is ready
        other.preload();
        this.exit();
        Main.currentScene = other;
        other.enter();
        this.unload();
    }

    public function switchToNewScene( className: String )
    {

        var type = Type.resolveClass( "game.scenes." + className);

        var other: Scene = Type.createInstance(type, [app]);
        other.preload();
        this.exit();
        Main.currentScene = other;
        other.enter();


        this.unload();
    }


}