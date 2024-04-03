
package cerastes.tools;
import h3d.impl.GlDriver;
import h3d.impl.DirectXDriver;
#if hlimgui
import hl.UI;
import haxe.io.Path;
import cerastes.file.CDPrinter;
import sys.io.File;
import cerastes.file.CDParser;
import sys.FileSystem;
import hxd.Window;

import hxd.Key;
import hxd.SceneEvents;
import cerastes.tools.ImguiTools.IG;
import h3d.Engine;
import h3d.mat.Texture;
import imgui.types.ImFontAtlas.ImFontTexData;
import imgui.ImGui;

import imgui.ImGui.ImFont;
import cerastes.macros.Metrics;
import haxe.rtti.Meta;
import haxe.macro.Expr;
import cerastes.input.ControllerAccess;
import imgui.ImGuiMacro.wref;

@:keepSub
class ImguiTool
{
	public var toolId: Int = 0;
	public var forceFocus: Bool = false;
	public var fileName: String = null;

	public function update( delta: Float ) {}
	public function render( e: h3d.Engine)	{}

	public function destroy() {}

	public function windowID()
	{
		return 'INVALID${toolId}';
	}

	public function getName() {	return "Untitled"; }

	public function openFile( file: String ) {};
}

enum ImGuiPopupType
{
	Info;
	Warning;
	Error;
}

@:structInit class ImGuiToolRegistration
{
	public var extensions: Array<String>;
	public var title: String;
	public var cls: String;
}

@:structInit
class ImGuiPopup
{
	public var title: String = null;
	public var description: String = null;
	public var type: ImGuiPopupType = Info;

	public var spawnTime: Float = 0;
	public var duration: Float = 5;
}

@:structInit
class ImGuiToolManagerState
{
	public var openFiles: Array<String> = [];
	public var previewScale: Int = 1;
}

class ImGuiToolManager
{
	static var tools = new Array<ImguiTool>();

	public static var defaultFont: ImFont;
	public static var headingFont: ImFont;
	public static var consoleFont: ImFont;

	public static var defaultFontSize: Float;
	public static var headingFontSize: Float;
	public static var consoleFontSize: Float;

	public static var scaleFactor: Float = 1;

	public static var toolIdx = 0;

	public static var popupStack: Array<ImGuiPopup> = [];

	public static var enabled(default, set): Bool = false;

	public static var customTools: Array<ImGuiToolRegistration> = [];

	static var sceneRT: Texture;
	static var sceneRTId: Int;

	static var viewportWidth: Int;
	static var viewportHeight: Int;
	static var viewportScale: Int;

	static var previewEvents: SceneEvents;

	static var inputAccess: ControllerAccess<Dynamic>;
	static var hasExclusiveAccess = false;

	static var previewScale: Int = 1;
	static var menubarHeight: Float;

	static var nextWindowFocus: String = null;

	static var styleWindowOpen: Bool = false;

	public static var test: h2d.Scene;

	static var vec2: ImVec2S = {x:0, y:0};

	static var mainWindow: hxd.Window;

	static function set_enabled(v)
	{
		enabled = v;
		if( enabled )
		{
			#if !multidriver

			#if hlsdl
			sdl.Sdl.setRelativeMouseMode(false);
			#end
			#if hldx
			@:privateAccess hxd.Window.getInstance().window.clipCursor(false);
			#end

			@:privateAccess hxd.Window.getInstance().window.maximize();
			cerastes.App.currentScene.disableEvents();

			hxd.System.setNativeCursor( hxd.Cursor.Default );
			#end
		}
		else
		{
			#if !multidriver
			@:privateAccess hxd.Window.getInstance().window.restore();
			cerastes.App.currentScene.enableEvents();
			#end

			// Clear imgui context
			ImGui.newFrame();
			ImGui.render();
		}

		return v;
	}

	public static function showPopup( title: String, desc: String, type: ImGuiPopupType )
	{
		popupStack.push({
			title: title,
			description: desc,
			type: type,
			spawnTime: Sys.time()
		});
	}

	public static function showTool( cls: String )
	{
		var type = null;
		if( cls.indexOf(".") == -1 )
			type = Type.resolveClass( "cerastes.tools." + cls);
		else
			type = Type.resolveClass(cls);

		if( !Utils.verify( type != null, 'Trying to create unknown tool cerastes.tools.${cls}') )
			return null;


		if(Meta.getType(type).multiInstance == null )
		{
			for( t in tools )
			{
				if( Std.isOfType( t, type ) )
					return t;
			}
		}


		var t : ImguiTool = Type.createInstance(type, []);

		t.toolId = toolIdx++;

		tools.push(t);

		return t;
	}

	public static function closeTool( t: ImguiTool )
	{
		t.destroy();
		tools.remove(t);
	}

	public static function saveState()
	{
		var s: ImGuiToolManagerState = {};
		for( t in tools )
		{
			if( t.fileName != null )
				s.openFiles.push( t.fileName );
		}

		s.previewScale = previewScale;

		sys.io.File.saveContent( "cerastesToolState.sav", CDPrinter.print( s ) );
	}

	public static function restoreState()
	{
		try
		{
			var s  = CDParser.parse( File.getContent( "cerastesToolState.sav" ), ImGuiToolManagerState );
			if( s != null )
			{
				for( f in s.openFiles )
				{
					openAssetEditor( f );
				}
			}
			previewScale = s.previewScale > 0 ? s.previewScale : previewScale;
		}
		catch(e)
		{
			Utils.warning("Failed to restore ImGuiToolManager state.");
		}
	}


	public static function init()
	{
		var io = ImGui.getIO();
		io.ConfigFlags |= DockingEnable;

		#if multidriver
		io.ConfigFlags |= ViewportsEnable;
		io.BackendFlags |= ImGuiBackendFlags.PlatformHasViewports;
		io.BackendFlags |= ImGuiBackendFlags.RendererHasViewports;
		io.BackendFlags |= ImGuiBackendFlags.HasMouseHoveredViewport;

		mainWindow = hxd.Window.getInstance();
		var v = ImGui.viewportSetMainViewport( mainWindow );
		if( v != null )
		{
			var w= mainWindow;
			w.onClose = () -> {
				// @todo: Alignment!!
				v.PlatformRequestClose = true;
				return false;
			}

			w.onMove = () -> {
				v.PlatformRequestMove = true;
			}

			// Get a handle to our drawable and add events. Yes it's gross.
			@:privateAccess
			{
				var d = cerastes.App.instance.drawable;
				w.addEventTarget( ( e: hxd.Event ) -> { d.onMultiWindowEvent( w, e, v ); } );
			}


			w.addResizeEvent(() -> {
				v.PlatformRequestResize = true;
			});



		}


		#if hlsdl
		// This hint allows a focus click to also send events. Without this, you have to click a window
		// once before you can interact with it, which feels really bad.
		sdl.Sdl.setHint("SDL_MOUSE_FOCUS_CLICKTHROUGH", "1");
		io.ConfigDockingTransparentPayload = true;

		for( d in sdl.Sdl.getDisplays() )
		{
			trace(d);
			ImGui.viewportAddMonitor( {
				x: d.right - d.left,
				y: d.bottom - d.top
			}, {
				x: d.left,
				y: d.top
			} );

		}
		#else
		// @todo: need to pass position in.
		for( m in hxd.Window.getMonitors() )
		{
			ImGui.viewportAddMonitor( { x: m.width, y: m.height }, { x: 0, y: 0 } );
		}
		#end

		var ignoreResize = false;
		ImGui.viewportSetPlatformCreateWindow( ( v: ImGuiViewport ) -> {
			@:privateAccess
			{
				#if hldx
				var w = new hxd.Window("ImGui Viewport", 100,100,false);
				var e = new h3d.Engine();
				e.window = w;
				var d3dDriver = new DirectXDriver();
				e.driver = d3dDriver;
				d3dDriver.window = w.window;
				d3dDriver.reset();
				d3dDriver.init(e.onCreate, !e.hardware);
				#elseif hlsdl

				var mainWindow = hxd.Window.inst;
				var w = new hxd.Window("ImGui Viewport", 100,100,false);
				w.displayMode = Borderless;
				var e = h3d.Engine.getCurrent();
				// Disable vsync on these windows; else we end up waiting for vblank for every individual window.
				w.vsync = false;

				@:privateAccess
				{
					w.window.visible = false;
					// !! HACK !!
					// Heaps always creates a new context when you create a window. That's perfectly reasonable
					// if multi driver was what we wanted, but it isn't, so slam the context.
					// Additionally, store off the created context so we can set it back during window destroy
					// since heaps always destroys the context alongside the window
					v.PlatformHandleRaw = w.window.glctx;
					w.window.glctx = mainWindow.window.glctx;

				}

				#end

				w.onClose = () -> {
					// @todo: Alignment!!
					v.PlatformRequestClose = true;
					return false;
				}

				w.onMove = () -> {
					v.PlatformRequestMove = true;
				}

				// Get a handle to our drawable and add events. Yes it's gross.
				@:privateAccess
				{
					var d = cerastes.App.instance.drawable;
					w.addEventTarget( ( e: hxd.Event ) -> { d.onMultiWindowEvent( w, e, v ); } );
				}


				w.addResizeEvent(() -> {
					if( !ignoreResize )
						v.PlatformRequestResize = true;
				});




				v.PlatformHandle = w;

				mainWindow.setCurrent();

			}
		});

		ImGui.viewportSetPlatformDestroyWindow( ( v: ImGuiViewport ) -> {

			@:privateAccess v.PlatformHandle.window.glctx = cast v.PlatformHandleRaw;

			if( v.PlatformHandle != null )
				v.PlatformHandle.close();

			v.RendererUserData = null;
			v.PlatformUserData = null;
			v.PlatformHandle = null;

		});

		ImGui.viewportSetPlatformShowWindow( ( v: ImGuiViewport ) -> {
			#if hlsdl
			@:privateAccess v.PlatformHandle.window.visible = true;
			#end
		});

		ImGui.viewportSetPlatformSetWindowPos( ( v: ImGuiViewport, size: ImVec2 ) -> {
			#if hldx
			var w: dx.Window = @:privateAccess v.PlatformHandle.window;
			w.setPosition( cast size.x, cast size.y );
			#elseif hlsdl
			@:privateAccess v.PlatformHandle.window.setPosition( cast size.x, cast size.y );
			#end
		});

		ImGui.viewportSetPlatformGetWindowPos( ( v: ImGuiViewport, pos: ImGuiVec2Struct ) -> {
			// @todo
			#if hlsdl
			@:privateAccess
			{
				var x = 0;
				var y = 0;
				sdl.Window.winGetPosition( v.PlatformHandle.window.win, x, y );
				pos.x = cast x;
				pos.y = cast y;
			}
			#else
			pos.x = 0;
			pos.y = 0;
			#end
		});

		ImGui.viewportSetPlatformSetWindowSize( ( v: ImGuiViewport, size: ImVec2 ) -> {
			if( v.PlatformHandle.width == size.x && v.PlatformHandle.height == size.y )
				return;
			ignoreResize = true;
			v.PlatformHandle.resize( cast size.x, cast size.y );
			// Hack
			// Currently window will call resize TWICE, once immediately, and a second time after the window event comes in
			// This is a problem for us since we triggered the resize, but imgui doesn't know that.
			new Timer(0.2, () -> { ignoreResize = false; });

		});

		ImGui.viewportSetPlatformGetWindowSize( ( v: ImGuiViewport, size: ImGuiVec2Struct ) -> {

			//var size: ImVec2 = {x: 0, y: 0};
			var window: hxd.Window = v.PlatformHandle;

			if( window != null )
			{
				size.x = window.width;
				size.y = window.height;

			}
			//return size; // @todo
		});

		ImGui.viewportSetPlatformSetWindowFocus( ( v: ImGuiViewport ) -> {
			// @todo
			Utils.warning("STUB: PlatformSetWindowFocus");
		});

		ImGui.viewportSetPlatformGetWindowFocus( ( v: ImGuiViewport ) -> {
			return v.PlatformHandle.isFocused;
		});

		ImGui.viewportSetPlatformGetWindowMinimized( ( v: ImGuiViewport ) -> {
			return false; // @todo
		});

		ImGui.viewportSetPlatformSetWindowTitle( ( v: ImGuiViewport, title: hl.Bytes ) -> {
			var str = @:privateAccess String.fromUTF8( title );
			v.PlatformHandle.title = str;
		});

		ImGui.viewportSetPlatformSetWindowAlpha( ( v: ImGuiViewport, alpha: Single ) -> {
			#if hlsdl
			@:privateAccess v.PlatformHandle.window.opacity = alpha;
			#end
		});

		ImGui.viewportSetRendererRenderWindow( ( v: ImGuiViewport, arg: Dynamic ) -> {

			if( !v.PlatformWindowCreated || v.PlatformHandle == null )
				return;

			Metrics.begin("ImGui.RendererRenderWindow");

			var oldWin = hxd.Window.getInstance();

			var e: h3d.Engine = Engine.getCurrent();
			var w = v.PlatformHandle;

			//@:privateAccess sdl.Window.winRenderTo(null, null);

			//sdl.GL.viewport(0,0,1000,1000);


			@:privateAccess// @:bypassAccessor
			{
				var oldW = e.width;
				var oldH = e.height;
				var oldScaleMode = cerastes.App.instance.s2d.scaleMode;

				w.setCurrent();
				e.window = w;
				e.resize(w.width, w.height);
				//e.clear(0x005533);


				@:privateAccess cerastes.App.instance.s2d.window = w;

				cerastes.App.instance.s2d.width = w.width;
				cerastes.App.instance.s2d.height = w.height;
				cerastes.App.instance.s2d.scaleMode = Fixed(w.width, w.height, 1);

				@:privateAccess cerastes.App.instance.s2d.render( e );

				cerastes.App.instance.s2d.width = oldW;
				cerastes.App.instance.s2d.height = oldH;
				cerastes.App.instance.s2d.scaleMode = oldScaleMode;

				@:privateAccess cerastes.App.instance.s2d.window = oldWin;

				oldWin.setCurrent();
				e.window = oldWin;
				e.resize(oldW, oldH);



			}


			Metrics.end();

		});

		ImGui.viewportSetRendererSwapBuffers( ( v: ImGuiViewport, arg: Dynamic ) -> {

			Metrics.begin("ImGuiToolManager.Present");
			var oldWin = hxd.Window.getInstance();
			var w = v.PlatformHandle;
			w.setCurrent();
			@:privateAccess w.window.present();
			oldWin.setCurrent();
			Metrics.end();
		});

		#end


		scaleFactor = Utils.getDPIScaleFactor();
		if( scaleFactor > 1 )
		{
			var style: ImGuiStyle = ImGui.getStyle();
			style.scaleAllSizes( scaleFactor );
		}

		// Default font
		defaultFontSize = 14 * scaleFactor;
		headingFontSize = 21 * scaleFactor;
		consoleFontSize = 14 * scaleFactor;

		ImGuiToolManager.defaultFont = ImGuiToolManager.addFont("res/tools/Ruda-Bold.ttf", defaultFontSize, true);
		ImGuiToolManager.headingFont = ImGuiToolManager.addFont("res/tools/Ruda-Bold.ttf", headingFontSize, true);
		ImGuiToolManager.consoleFont = ImGuiToolManager.addFont("res/tools/console.ttf", consoleFontSize);
		ImGuiToolManager.buildFonts();

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;
		viewportScale = viewportDimensions.scale;

		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		previewEvents = new SceneEvents();

		// Delay a frame so we get the right sizes
		new Timer(0.1, () -> {
			restoreState();
		});

		//ImGuiToolManager.showTool("TileMapEditor");

	}

	public static function drawScene()
	{

		if( nextWindowFocus == "root_Scene" )
		{
			nextWindowFocus = null;
			ImGui.setNextWindowFocus();
		}

		ImGui.begin("\uf3fa Scene", null, ImGuiWindowFlags.AlwaysAutoResize );

		if( ImGui.beginCombo("Scale", Std.string('${previewScale}x') ) )
		{
			if( ImGui.selectable( "1x", previewScale == 1 ) ) previewScale = 1;
			if( ImGui.selectable( "2x", previewScale == 2 ) ) previewScale = 2;
			if( ImGui.selectable( "4x", previewScale == 4 ) ) previewScale = 4;

			ImGui.endCombo();
		}

		var pos = ImGui.getCursorPos();
		var windowPos = pos + ImGui.getWindowPos();
		var size: ImVec2S = { x: viewportWidth * previewScale, y: viewportHeight * previewScale };

		ImGui.button("dummy", size );
		ImGui.setCursorPos( pos );
		ImGui.image(sceneRT, size );

		var active = updatePreviewEvents( windowPos, size, previewEvents );

		ImGui.end();

		if( inputAccess != null )
		{
			if( active && hasExclusiveAccess )
			{
				inputAccess.releaseExclusivity();
				hasExclusiveAccess = false;
			}
			else if( !active && !hasExclusiveAccess )
			{
				inputAccess.takeExclusivity();
				hasExclusiveAccess = true;
			}
		}

	}

	static function drawTaskBar()
	{

		var flags = ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoDocking |
					ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoBackground |
					ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoBringToFrontOnFocus;

		var height = viewportHeight;
		var width = 100 * viewportScale;
		var style = ImGui.getStyle();

		ImGui.setNextWindowPos( {x: 0, y: menubarHeight } );
		//ImGui.setNextWindowSize( { x: width, y: height });
		ImGui.begin("root_taskbar", null, flags );

		ImGui.pushFont( headingFont );

		//ImGui.beginChildFrame(taskbarId, { x: 150 * scaleFactor, y: size.y });

		if( ImGui.button("\uf3fa Scene") )
			nextWindowFocus = "root_Scene";

		for( t in tools )
		{
			if( ImGui.button( t.getName() ) )
			{
				nextWindowFocus = t.windowID();
			}
		}

		ImGui.popFont();

		ImGui.end();

	}

	public static function drawMenuBar()
	{
		// Menu bar
		if( ImGui.beginMenu("Tools", true) )
		{
			if (ImGui.menuItem("Perf", "Alt+P"))
				ImGuiToolManager.showTool("Perf");

			if (ImGui.menuItem("UI Editor", "Alt+U"))
				ImGuiToolManager.showTool("UIEditor");

			if (ImGui.menuItem("Flow Editor", "Alt+U"))
				ImGuiToolManager.showTool("FlowEditor");

			if (ImGui.menuItem("Asset Browser", "Alt+B"))
				ImGuiToolManager.showTool("AssetBrowser");

			if (ImGui.menuItem("Model Editor"))
				ImGuiToolManager.showTool("ModelEditor");

			if (ImGui.menuItem("Material Editor"))
				ImGuiToolManager.showTool("MaterialEditor");

			if (ImGui.menuItem("Atlas Builder"))
				ImGuiToolManager.showTool("AtlasBuilder");

			if (ImGui.menuItem("Tile Map Editor"))
				ImGuiToolManager.showTool("TileMapEditor");


			for( c in customTools )
			{
				if( ImGui.menuItem( c.title ) )
					ImGuiToolManager.showTool(c.cls);
			}

			ImGui.separator();

			if (ImGui.menuItem("Style Editor"))
				styleWindowOpen = !styleWindowOpen;

			ImGui.endMenu();
		}

	}


	public static function update( delta: Float )
	{
		Metrics.begin();

		// Set global font
		ImGui.pushFont( ImGuiToolManager.defaultFont );


		Metrics.begin("ImGui.showDemoWindow");
		//ImGui.showDemoWindow();
		if( styleWindowOpen )
			ImGui.showStyleEditor();

		Metrics.end();



		#if !multidriver
		var size = ImGui.getWindowSize();
		menubarHeight = size.y;
		if( ImGui.beginMainMenuBar() )
		{
			drawMenuBar();
			ImGui.endMainMenuBar();
		}
		drawTaskBar();

		// Draw preview window
		ImGuiToolManager.drawScene();
		#end

		// Make sure there aren't any tool ID collisions
		var toolMap: Map<String, ImguiTool> = [];
		var toolCopy = tools.copy();
		for( i in 0 ... toolCopy.length )
		{
			var tool = toolCopy[i];
			if( toolMap.exists( tool.windowID() ) )
			{
				toolMap.get(tool.windowID()).forceFocus = true;
				tools.remove(tool);
				continue;
			}

			toolMap.set(tool.windowID(), tool);

			if( nextWindowFocus == tool.windowID() )
			{
				ImGui.setNextWindowFocus();
				nextWindowFocus = null;
			}
			tool.update( delta );
		}

		var offset: Float = 0;

		var i = popupStack.length;
		while( i-- > 0 )
		{
			var popup = popupStack[i];
			if( popup.spawnTime + popup.duration < Sys.time() )
			{
				popupStack.splice(i,1);
				i--;
			}

			offset = renderPopup( popup, i, offset );
		}

		#if !multidriver
		var s2d = cerastes.App.currentScene.s2d;
		@:privateAccess
		{
			if( previewEvents.scenes.length == 1 && previewEvents.scenes[0] != s2d )
				previewEvents.removeScene( previewEvents.scenes[0] );

			if( previewEvents.scenes.length == 0 )
				previewEvents.addScene( s2d );
		}
		#end



		ImGui.popFont();

		Metrics.end();
	}

	public static function renderPopup( popup: ImGuiPopup, idx: Int, offset: Float )
	{
		var windowFlags = ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoDecoration | ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.NoSavedSettings | ImGuiWindowFlags.NoFocusOnAppearing | ImGuiWindowFlags.NoNav;

		var padding: Float = 10 * scaleFactor;
		var height: Float = 0;

		ImGui.setNextWindowBgAlpha(0.350); // Transparent background
		ImGui.setNextWindowPos({x: 10, y: 50 + offset }, ImGuiCond.Always);
		//ImGui.setNextWindowSize(null, ImGuiCond.Always);
		if (ImGui.begin('${popup.title}##${idx}', null, windowFlags))
		{
			ImGui.pushTextWrapPos( 200 * scaleFactor );
			switch( popup.type )
			{
				case Info:
					ImGui.pushFont( headingFont );
					ImGui.text( '\uf05a ${popup.title}');
					ImGui.popFont();

				case Warning:
					ImGui.pushFont( headingFont );
					ImGui.textColored( {x: 1.0, y: 1.0, z: 0, w: 1.0}, '\uf071 ${popup.title}');
					ImGui.popFont();

				case Error:
					ImGui.pushFont( headingFont );
					ImGui.textColored( {x: 1.0, y: 0, z: 0, w: 1.0}, '\uf1e2 ${popup.title}');
					ImGui.popFont();
			}

			ImGui.separator();
			ImGui.dummy({x:10,y:5 * scaleFactor});
			ImGui.text(popup.description);
			height = ImGui.getWindowHeight();

			ImGui.popTextWrapPos();

		}

		ImGui.end();



		return offset + height + padding;
	}

	public static function render( e: h3d.Engine )
	{
		Metrics.begin();
		for( t in tools )
			t.render( e );
		Metrics.end();

		#if !multidriver

		Metrics.begin("Scene Render");
		// Render current scene to texture
		sceneRT.clear( 0 );
		e.pushTarget( sceneRT );
		e.clear(0xFF000000,1);

		var oldW = e.width;
		var oldH = e.height;

		@:privateAccess// @:bypassAccessor
		{
			e.width = sceneRT.width;
			e.height = sceneRT.height;


			Metrics.begin("currentScene.render");
			cerastes.App.currentScene.s2d.setElapsedTime( ImGui.getIO().DeltaTime );
			cerastes.App.currentScene.render(e);
			Metrics.end();

			e.width = oldW;
			e.height = oldH;
		}


		e.popTarget();
		Metrics.end();
		#end
	}

	public static function addFont( file: String, size: Float, includeGlyphs: Bool = false )
	{
		Utils.assert( FileSystem.exists( file ), 'Missing ImGui font ${file}' );


		var dpiScale = Utils.getDPIScaleFactor();
		Utils.info('Add font: ${file} ${size}px');


		var atlas = ImGui.getIO().Fonts;
		//atlas.addFontDefault();
		var font = atlas.addFontFromFileTTF(file, size);


		var facfg = new ImFontConfig();

		#if imjp
		var ranges = new hl.NativeArray<hl.UI16>(11);
		// fa
		ranges[0] = 0xf000;
		ranges[1] = 0xf6ff;
		// hira
		ranges[2] = 0x3040;
		ranges[3] = 0x309f;
		// kata
		ranges[4] = 0x30A0;
		ranges[5] = 0x30FF;
		// Half
		ranges[6] = 0xFF00;
		ranges[7] = 0xFFEF;
		// CJK
		ranges[8] = 0x4e00;
		ranges[9] = 0x9FAF;
		ranges[10] = 0;

		var jpcfg = new ImFontConfig();
		jpcfg.MergeMode = true;
		#else
		var ranges = new hl.NativeArray<hl.UI16>(3);
		// fa
		ranges[0] = 0xf000;
		ranges[1] = 0xf6ff;
		ranges[2] = 0;
		#end

		#if imjp
		atlas.addFontFromFileTTF("res/tools/NotoSansJP-Regular.otf",  size, jpcfg, ranges);
		#end

		if( includeGlyphs )
		{
			facfg.MergeMode = true;
			facfg.GlyphMinAdvanceX = 18 * dpiScale;
			atlas.addFontFromFileTTF("res/tools/fa-regular-400.ttf",  size * 0.8, facfg, ranges);
			atlas.addFontFromFileTTF("res/tools/fa-solid-900.ttf",  size * 0.8, facfg, ranges);
		}
		atlas.build();

		return font;
	}

	public static function buildFonts()
	{
		var fontInfo: ImFontTexData = new ImFontTexData();
		var atlas = ImGui.getIO().Fonts;

		atlas.getTexDataAsRGBA32( fontInfo );

		// create font texture
		var textureSize = fontInfo.width * fontInfo.height * 4;
		var fontTexture = Texture.fromPixels(new hxd.Pixels(
			fontInfo.width,
			fontInfo.height,
			fontInfo.buffer.toBytes(textureSize),
			hxd.PixelFormat.RGBA));

		atlas.setTexId( fontTexture );
		Utils.info('Font atlas built: ${fontInfo.width}x${fontInfo.height}');
	}

	static var g: h2d.Graphics;

	public static function updatePreviewEvents( startPos: ImVec2S, size: ImVec2S, previewEvents: SceneEvents )
	{
		#if hlimgui
		var hovered = ImGui.isItemHovered( ImGuiHoveredFlags.AllowWhenBlockedByActiveItem );

		if( !hovered )
			return false;


		var style = ImGui.getStyle();

		var mouseX = Window.getInstance().mouseX;
		var mouseY = Window.getInstance().mouseY;


		var scaleX = Engine.getCurrent().width / size.x;
		var scaleY = Engine.getCurrent().height / size.y;

		if( mouseX < startPos.x || mouseY < startPos.y )
			return false;

		if( mouseX > startPos.x + size.x || mouseY > startPos.y + size.y )
			return false;

		var mouseScenePos = {x: mouseX - startPos.x, y: mouseY - startPos.y };


		mouseScenePos.x *= scaleX;
		mouseScenePos.y *= scaleY;


		var windowSizeX = Engine.getCurrent().width;
		var windowSizeY = Engine.getCurrent().height;





		var event = new hxd.Event(EMove, mouseScenePos.x, mouseScenePos.y);


		if( ImGui.isMouseClicked( ImGuiMouseButton.Left ) )
		{
			event.kind = EPush;
			event.button = 0;
		}
		else if( ImGui.isMouseClicked( ImGuiMouseButton.Right ) )
		{
			event.kind = EPush;
			event.button = 1;
		}
		else if( ImGui.isMouseReleased( ImGuiMouseButton.Left ) )
		{
			event.kind = ERelease;
			event.button = 0;
		}
		else if( ImGui.isMouseReleased( ImGuiMouseButton.Right ) )
		{
			event.kind = ERelease;
			event.button = 1;
		}
		if( Key.isPressed( Key.MOUSE_WHEEL_DOWN ) )
		{
			event.kind = EWheel;
			event.wheelDelta = 1;
		}
		else if( Key.isPressed( Key.MOUSE_WHEEL_UP ) )
		{
			event.kind = EWheel;
			event.wheelDelta = -1;
		}


		@:privateAccess {

			var propagate = true;

			if( previewEvents.currentDrag != null && (previewEvents.currentDrag.ref == null || previewEvents.currentDrag.ref == event.touchId) )
			{
				event.propagate = true;
				event.cancel = false;
				previewEvents.currentDrag.f(event);
				event.relX = event.relX;
				event.relY = event.relY;
				if( !event.propagate )
					propagate = false;
			}

			if( propagate )
				previewEvents.emitEvent( event );

			var scene: h2d.Scene = Std.downcast( previewEvents.scenes[0], h2d.Scene );
			if( scene != null )
			{
				var vsx = scene.width / windowSizeX;
				var vsy = scene.height / windowSizeY;
				previewEvents.setMousePos( event.relX * vsx, event.relY * vsy );
			}
			else
			{

				var scene: h3d.scene.Scene = Std.downcast( previewEvents.scenes[0], h3d.scene.Scene );
				if( scene != null )
				{
					// @todo
				}
			}

		}


		return true;

		//preview.dispatchListeners( event );

		#end
	}

	public static function openAssetEditor( file: String )
	{
		var ext = Path.extension( file );
		switch( ext )
		{
			#if cannonml
			case "cml":
				var t: BulletEditor = cast ImGuiToolManager.showTool("BulletEditor");
				t.openFile( file );
			case "cbl":
				var t: BulletLevelEditor = cast ImGuiToolManager.showTool("BulletLevelEditor");
				t.openFile( file );
			#end
			case "ui":
				var t: UIEditor = cast ImGuiToolManager.showTool("UIEditor");
				t.openFile( file );
			#if spritemeta
			case "csd":
				var t: SpriteEditor = cast ImGuiToolManager.showTool("SpriteEditor");
				t.openFile( file );
			#end
			case "atlas":
				var t: AtlasBrowser = cast ImGuiToolManager.showTool("AtlasBrowser");
				t.openFile( file );
			case "catlas":
				var t: AtlasBuilder = cast ImGuiToolManager.showTool("AtlasBuilder");
				t.openFile( file );
			case "flow":
				var t: FlowEditor = cast ImGuiToolManager.showTool("FlowEditor");
				t.openFile( file );
			case "audio":
				var t: AudioEditor = cast ImGuiToolManager.showTool("AudioEditor");
				t.openFile( file );
			case "material":
				var t: MaterialEditor = cast ImGuiToolManager.showTool("MaterialEditor");
				t.openFile( file );
			case "model":
				var t: ModelEditor = cast ImGuiToolManager.showTool("ModelEditor");
				t.openFile( file );
			case "wav" | "ogg" | "mp3":
				hxd.Res.load( file ).toSound().play();
		}
	}

	public static function renderElement( field: String, type: String, args: Array<String>, fnGet: (String) -> Any, fnSet: (String, Any) -> Void, ?tooltip: String )
	{
		var changed = false;
		switch( type )
		{
			case "Bool":
				var val = fnGet(field);
				if( val == null ) val = 0;
				if( wref( ImGui.checkbox(args[0], _ ), val ) )
				{
					fnSet(field, val);

					changed = true;
				}

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

			case "Int":
				var val = fnGet(field);
				if( val == null ) val = 0;
				if( wref( ImGui.inputInt(args[0], _ ), val ) )
				{
					fnSet(field, val);
					changed = true;
				}

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

			case "String" | "LocalizedString":
				var val = fnGet(field);
				if( val == null ) val = "";
				var ret = IG.textInput(args[0],val);
				if( ret != null )
					fnSet(field, ret);

				changed = ret != null;

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

			case "StringMultiline" | "LocalizedStringMultiline":
				var val = fnGet(field);
				if( val == null ) val = "";
				var ret = IG.textInputMultiline(args[0],val,{x: -1, y: 300 * Utils.getDPIScaleFactor()}, ImGuiInputTextFlags.Multiline | ImGuiInputTextFlags.CallbackAlways ,1024*8);
				if( ret != null )
					fnSet(field, ret);

				changed = ret != null;

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

			case "Tile":
				var val = fnGet(field);
				if( val == null ) val = "";
				var ret = IG.inputTile(args[0],val);
				if( ret != null )
					fnSet(field, ret);

				changed = ret != null;

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);


			case "File":
				var val = fnGet(field);
				if( val == null ) val = "";
				var ret = IG.textInput(args[0],val);
				if( ret != null )
					fnSet(field, ret);

				changed = ret != null;

				if( ImGui.beginDragDropTarget( ) )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && StringTools.endsWith(payload, "flow") )
					{
						fnSet( field, payload );
						changed = true;
					}
				}

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);


				if( ImGui.button("Select...") )
				{
					var file = UI.loadFile({
						title:"Select file",
						filters:[
						{name:"Cerastes flow files", exts:["flow"]},
						],
						filterIndex: 0
					});
					if( file != null )
					{
						fnSet( field, file );
						changed = true;
					}
				}
/*
			case "ComboString":
				var val = Reflect.getProperty(obj,field);
				var opts = getOptions( field );
				var idx = opts.indexOf( val );
				if( ImGui.beginCombo( args[0], val ) )
				{
					for( opt in opts )
					{
						if( ImGui.selectable( opt, opt == val ) )
						{
							Reflect.setField( obj, field, opt );
							changed = true;
						}
					}
					ImGui.endCombo();
				}

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);
*/
			case "Array":
				ImGui.text(args[0]);

				if (tooltip != null && ImGui.isItemHovered(ImGuiHoveredFlags.AllowWhenDisabled))
					ImGui.setTooltip(tooltip);

				var val:Array<String> = fnGet(field);
				switch( args[2] )
				{
					case "String":
						if( val != null )
						{
							for( idx in 0 ... val.length )
							{
								ImGui.pushID('idx${idx}');
								if( val[idx] == null ) val[idx] = "";
								changed = wref( ImGui.inputText( '${idx}', _), val[idx] );

								if( ImGui.button("Del") )
									val.splice(idx,1);

								ImGui.popID();
							}
						}
						if( ImGui.button("Add") )
						{
							if( val == null )
								fnSet( field, [""] );
							else
								val.push("");
						}
				}



			default:
				ImGui.text('UNHANDLED!!! ${field} -> ${args[0]} of type ${args[1]}');
		}

		return changed;
	}
}

#end