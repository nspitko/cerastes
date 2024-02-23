package cerastes;

import cerastes.Tickable.TimeManager;
import hxd.BitmapData;
import cerastes.fmt.CUIResource;
import hxd.SceneEvents;
import cerastes.SoundManager;
import cerastes.collision.CollisionManager;
import cerastes.macros.Metrics;
import cerastes.bulletml.BulletManager;
#if hlsdl
import sdl.Sdl;
#end
import hxd.Window;
import hxd.System;
import h3d.mat.Texture;
import h2d.Object;
import cerastes.butai.Debug;
import h3d.Engine;
import h2d.Bitmap;
#if client
import cerastes.ui.Console;
#end
import hxd.res.Loader;

import cerastes.InputManager;
import cerastes.Entity.EntityManager;

import cerastes.Tween;
import cerastes.Timer;
import hxd.Key;
import hxd.fmt.pak.FileSystem;
import hxd.fs.BytesFileSystem.BytesFileEntry;
import cerastes.Utils;

import cerastes.Utils.info;

#if localserver
import sys.io.Process;
import haxe.io.Eof;
import sys.io.Process;
import sys.thread.Thread;
#end

#if butai
import cerastes.butai.ButaiNodeManager;
#end

#if js
import js.Browser;
#end

#if hlimgui
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import cerastes.tools.ImguiTool;
import cerastes.tools.ImguiTools;
#end

class App extends hxd.App {

	public static var currentScene : cerastes.Scene;

	public static var cursor: h2d.Bitmap;
	public static var useScanlines = true;

	public static var instance: App;
	public static var defaultFont: h2d.Font;

	#if network
	public static var client: client.ClientConnection;
	#end

	#if localserver
	public static var serverProcess : Process = null;
	#end

	#if hlimgui
	var drawable:ImGuiDrawable;
	var containerImgui: Object;



	// This MUST BE static! Memory referenced here can never go away or bad things happen
	static var ranges: hl.NativeArray<hl.UI16>;

	public var sceneEvents: SceneEvents;

	#end


	public static var launchOptions: Map<String, String> = [];

	public static var saveload: cerastes.SaveLoad;



	function new()
	{
		super();
	}

	override function init()
	{
		saveload = new cerastes.SaveLoad();
		#if sys
		parseArgs();
		#end
		defaultFont = hxd.res.DefaultFont.get();

		hxd.Window.getInstance().vsync = true;
		#if hlimgui
		drawable = new ImGuiDrawable(this.s2d, false);


		ImGuiToolManager.init();

		sceneEvents = new SceneEvents();

		#end


		cerastes.c2d.DebugDraw.init();
		cerastes.c3d.DebugDraw.init();

		cerastes.EntityBuilder.init( ["data/entities.def"] );


		/*

		cursor = new Bitmap( hxd.Res.spr.atlas.get("cursor") , s2d );
		cursor.visible = false;


   		// Setup our cursor
		//var bmp = hxd.Res.spr.cursor.toBitmap();
		//var overrideCursor:hxd.Cursor = Custom(new hxd.Cursor.CustomCursor([bmp], 0, 0, 0));
		var overrideCursor:hxd.Cursor = Hide;

		hxd.System.setCursor = function( cur : hxd.Cursor ) {
				hxd.System.setNativeCursor(overrideCursor);
		}

		*/

		@:privateAccess hxd.Window.inst.onClose = function(){
			cleanupAndExit();

			return true;
		}

		Debug.init();


//        sevents.removeScene(this.s3d);
//        sevents.removeScene(this.s2d);

		currentScene = new cerastes.Scene( this );
		currentScene.preload();

		engine.backgroundColor = 0x0;
		onResize();

		#if network
		client = new client.ClientConnection("127.0.0.1", 9000);
		client.connect();
		#end


		#if tools
		// Allow CLI override for testing
		var noTools = false;
		for( arg in Sys.args())
		{
			if( arg == "notools")
				noTools = true;
		}
		//hxd.Window.getInstance().displayMode = Borderless;
		#end

		#if hlimgui

		if( !noTools )
			ImGuiToolManager.enabled = !ImGuiToolManager.enabled;

		
		ImGuiToolManager.showTool("Perf");
		ImGuiToolManager.showTool("AssetBrowser");
		ImGuiToolManager.showTool("Console");
		#end
	}




	function cleanupAndExit()
	{
		#if localserver
		serverProcess.kill();
		#end
		#if hl
		trace("Requested system exit.");
		#if butai
		if(Debug.debugSocket != null )
		{
			trace("Closing debug socket");
			Debug.debugSocket.close();
		}
		#end

		#if hlimgui
		cerastes.tools.ImGuiToolManager.saveState();
		#end


		hxd.System.exit();
		#end
	}



	override function loadAssets( onReady: Void->Void )
	{
		onReady();
	}


	override function update(dt:Float)
	{
		Metrics.endFrame();
		Metrics.begin();

		#if hlimgui
		if( Key.isPressed( Key.PAUSE_BREAK ) )
		{
			ImGuiToolManager.enabled = !ImGuiToolManager.enabled;
		}

		if(!ImGuiToolManager.enabled)
		{
			// Allow showing tiny popups
			Metrics.begin("ImGui.newFrame");
			ImGui.newFrame();
			drawable.update(dt);
			Metrics.end();
		}
		#end

		// limits update cycle to 10ms, then yields to render loop. May need tuning.
		#if network
		Metrics.begin("Network::Client.updateTimeout");
		client.updateTimeout(0.010);
		Metrics.end();
		#end

		TimerManager.instance.tick(dt);

		Metrics.begin("currentScene.tick");
		currentScene.tick(dt);
		Metrics.end();

		TweenManager.instance.tick(dt);
		EntityManager.instance.tick(dt);
		#if cannonml
		BulletManager.tick(dt);
		#end
		// Sync sends outbount crap
		#if network
		Metrics.begin("Network::Client.sync");
		client.sync();
		Metrics.end();
		#end

		Metrics.begin("SoundManager::Tick");
		SoundManager.tick(dt);
		Metrics.end();

		Metrics.begin("TimeManager::Tick");
		TimeManager.tick(dt);
		Metrics.end();

		cerastes.c2d.DebugDraw.tick(dt);
		cerastes.c3d.DebugDraw.tick(dt);

		//cursor.x = s2d.mouseX;
		//cursor.y = s2d.mouseY;

		#if sys

		if( Key.isPressed( Key.F5  ) )
			cleanupAndExit();
		#end

		#if hlwwise
		Metrics.begin("wwise::Update");
		wwise.Api.update();
		Metrics.end();
		#end




		#if hlimgui
		if( ImGuiToolManager.enabled )
		{
			//currentScene.s2d.scaleMode = ScaleMode.LetterBox(Math.floor( viewportWidth / viewportScale ), Math.floor( viewportHeight / viewportScale ),false,Center,Center);

			Metrics.begin("ImGuiDrawable.update");
			drawable.update(dt);
			Metrics.end();

			ImGui.newFrame();

			ImGuiToolManager.update(dt);


		}
		else
		{
			//ImGui.end();
		}
		#end
		Metrics.end(); // Update

	}

	override function render(e:h3d.Engine)
	{
		Metrics.begin();

		#if hlimgui
		if( ImGuiToolManager.enabled )
		{
			Metrics.begin("ImGui.render");
			ImGui.render();
			Metrics.end();

			Metrics.begin("ImGuiToolManager.Render");
			ImGuiToolManager.render(e);
			Metrics.end();

			// Everything else
			s2d.render(e);


		}
		else
		{
			Metrics.begin("ImGui.render");
			ImGui.render();
			Metrics.end();
			#end

			Metrics.begin("currentScene.render");
			currentScene.render(e);
			Metrics.end();
			Metrics.begin("s2d.render");
			s2d.render(e);
			Metrics.end();
		#if hlimgui
		}
		#end

		Metrics.end();
	}

	#if sys
	function parseArgs()
	{
		var args = Sys.args();
		//var key: String = null;
		for( a in args )
		{
			if( StringTools.startsWith(a,'-') )
			{
				var kv = a.substr(1).split("=");
				var val: String = null;
				if( kv.length > 0 )
					val = kv[1];

				launchOptions.set(kv[0], val);
			}
		}

	}
	#end
}
