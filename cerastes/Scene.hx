package cerastes;

import cerastes.macros.Callbacks.ClassKey;
import cerastes.ui.Console.GlobalConsole;
import hxd.fmt.fbx.BaseLibrary.TmpObject;
import haxe.Constraints;

class Scene
{

    public var app(default,null) : Main;
    public var engine(default,null) : h3d.Engine;
	public var s3d(default,null) : h3d.scene.Scene;
	public var s2d(default,null) : h2d.Scene;

    var trackedCallbacks = new Array<(ClassKey -> Bool)>();

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

    function trackCallback( success: Bool, unregisterFunction: ( ClassKey -> Bool ) )
    {
        if( success )
            trackedCallbacks.push( unregisterFunction );
    }

    /**
     *  Called when rendering is handed off to this scene
     */
    public function enter()
    {
        cerastes.c3d.DebugDraw.tick(0); // Hack
        s3d.addChild( cerastes.c3d.DebugDraw.g );
        s2d.addChild( cerastes.c3d.DebugDraw.t );
        #if hlimgui
        if( Main.instance.showTools)
        {
            Main.instance.sceneEvents.removeScene( s2d );
            Main.instance.sceneEvents.removeScene( s3d );
        }
        else
        #end
        {
            enableEvents();
        }

        GlobalConsole.instance.currentScene = this;

        s2d.defaultSmooth = false;

        var size = haxe.macro.Compiler.getDefine("windowSize");
        var scale = haxe.macro.Compiler.getDefine("renderScale");
        var viewportScale = 1;
		var viewportWidth = 640;
		var viewportHeight = 480;
		if( size != null )
		{
			var p = size.split("x");
			viewportWidth = Std.parseInt(p[0]);
			viewportHeight = Std.parseInt(p[1]);
		}
        if( scale != null ) viewportScale = Std.parseInt(scale);

		s2d.scaleMode = ScaleMode.Stretch(Math.floor( viewportWidth / viewportScale ), Math.floor( viewportHeight / viewportScale ));
    }

    public function disableEvents()
    {
        app.sevents.removeScene(this.s3d);
        app.sevents.removeScene(this.s2d);
    }

    public function enableEvents()
    {
        app.sevents.addScene(this.s2d);
        app.sevents.addScene(this.s3d);
    }

    /**
     *  Logic update loop.
     *  @param delta - Delta time since last call.
     */
    public function tick( delta:Float )
    {
        s2d.setElapsedTime(delta);
        s3d.setElapsedTime(delta);
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
        for( cb in trackedCallbacks )
            cb( this );



        app.sevents.removeScene(this.s3d);
        app.sevents.removeScene(this.s2d);

        #if hlimgui
        if( Main.instance.showTools)
        {
            Main.instance.sceneEvents.removeScene( s2d );
            Main.instance.sceneEvents.removeScene( s3d );
        }
        #end

        s2d.dispose();
        s3d.dispose();
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

    /**
     * Called when the app has been resized
     */
    public function resized()
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
        #if butai
        var type = Type.resolveClass( "game.scenes." + className);
        #else
        var type = Type.resolveClass( className);
        #end

        var other: Scene = Type.createInstance(type, [app]);
        other.preload();
        this.exit();
        Main.currentScene = other;
        other.enter();


        this.unload();
    }


}