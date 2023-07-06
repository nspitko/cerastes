
package cerastes.tools;


import game.GameState;
import sys.FileSystem;
import hxd.Window;
#if hlimgui
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
import game.GameState.GameActions;
import cerastes.input.ControllerAccess;

@:keepSub
class ImguiTool
{
	public var toolId: Int = 0;
	public var forceFocus: Bool = false;

	public function update( delta: Float ) {}
	public function render( e: h3d.Engine)	{}

	public function destroy() {}

	public function windowID()
	{
		return 'INVALID${toolId}';
	}

	public function getName() {	return "Untitled"; }
}

enum ImGuiPopupType
{
	Info;
	Warning;
	Error;
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

class ImGuiToolManager
{
	static var tools = new Array<ImguiTool>();

	public static var defaultFont: ImFont;
	public static var headingFont: ImFont;
	public static var consoleFont: ImFont;

	public static var scaleFactor: Float = 1;

	public static var toolIdx = 0;

	public static var popupStack: Array<ImGuiPopup> = [];

	public static var enabled(default, set): Bool = false;

	static var sceneRT: Texture;
	static var sceneRTId: Int;

	static var viewportWidth: Int;
	static var viewportHeight: Int;
	static var viewportScale: Int;

	static var previewEvents: SceneEvents;

	static var inputAccess: ControllerAccess<GameActions>;
	static var hasExclusiveAccess = false;

	static var previewScale: Int = 1;
	static var menubarHeight: Float;

	static var nextWindowFocus: String = null;



	static function set_enabled(v)
	{
		enabled = v;
		if( enabled )
		{
			// Temp
			#if hlsdl
			sdl.Sdl.setRelativeMouseMode(false);
			#end
			#if hldx
			@:privateAccess hxd.Window.getInstance().window.clipCursor(false);
			#end

			@:privateAccess hxd.Window.getInstance().window.maximize();
			Main.currentScene.disableEvents();

			hxd.System.setNativeCursor( hxd.Cursor.Default );
		}
		else
		{
			@:privateAccess hxd.Window.getInstance().window.restore();
			Main.currentScene.enableEvents();


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
		var type = Type.resolveClass( "cerastes.tools." + cls);
		Utils.assert( type != null, 'Trying to create unknown tool cerastes.tools.${cls}');


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

	public static function init()
	{
		ImGui.setConfigFlags( DockingEnable );

		scaleFactor = Utils.getDPIScaleFactor();
		if( scaleFactor > 1 )
		{
			var style: ImGuiStyle = ImGui.getStyle();
			style.scaleAllSizes( scaleFactor );
		}

		// Default font
		ImGuiToolManager.defaultFont = ImGuiToolManager.addFont("res/tools/Ruda-Bold.ttf", 14, true);
		ImGuiToolManager.headingFont = ImGuiToolManager.addFont("res/tools/Ruda-Bold.ttf", 21, true);
		ImGuiToolManager.consoleFont = ImGuiToolManager.addFont("res/tools/console.ttf", 14);
		ImGuiToolManager.buildFonts();

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;
		viewportScale = viewportDimensions.scale;

		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		previewEvents = new SceneEvents();



	}

	public static function drawScene()
	{
		if( inputAccess == null )
			inputAccess = GameState.input.createAccess();

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


	public static function update( delta: Float )
	{
		Metrics.begin();

		// Set global font
		ImGui.pushFont( ImGuiToolManager.defaultFont );

		// Menu bar
		if( ImGui.beginMainMenuBar() )
		{
			var size = ImGui.getWindowSize();
			menubarHeight = size.y;
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

				if (ImGui.menuItem("Material Editor"))
					ImGuiToolManager.showTool("MaterialEditor");

				if (ImGui.menuItem("Atlas Builder"))
					ImGuiToolManager.showTool("AtlasBuilder");

				ImGui.endMenu();
			}
			ImGui.endMainMenuBar();
		}

		Metrics.begin("ImGui.showDemoWindow");
		//ImGui.showDemoWindow();
		Metrics.end();

		drawTaskBar();

		// Draw preview window
		ImGuiToolManager.drawScene();

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

		var s2d = Main.currentScene.s2d;
		@:privateAccess
		{
			if( previewEvents.scenes.length == 1 && previewEvents.scenes[0] != s2d )
				previewEvents.removeScene( previewEvents.scenes[0] );

			if( previewEvents.scenes.length == 0 )
				previewEvents.addScene( s2d );
		}



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

		Metrics.begin("Scene Render");
		// Render current scene to texture
		sceneRT.clear( 0 );

		e.pushTarget( sceneRT );
		e.clear(0,1);
		Metrics.begin("currentScene.render");
		Main.currentScene.render(e);

		Metrics.end();
		e.popTarget();
		Metrics.end();
	}

	public static function addFont( file: String, size: Float, includeGlyphs: Bool = false )
	{
		Utils.assert( FileSystem.exists( file ), 'Missing ImGui font ${file}' );


		var dpiScale = Utils.getDPIScaleFactor();
		Utils.info('Add font: ${file} ${size*dpiScale}px');

		var atlas = ImGui.getFontAtlas();
		//atlas.addFontDefault();
		var font = atlas.addFontFromFileTTF(file, size * dpiScale);


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
		atlas.addFontFromFileTTF("res/tools/NotoSansJP-Regular.otf",  size * dpiScale, jpcfg, ranges);
		#end

		if( includeGlyphs )
		{
			facfg.MergeMode = true;
			facfg.GlyphMinAdvanceX = 18 * dpiScale;
			atlas.addFontFromFileTTF("res/tools/fa-regular-400.ttf",  size * dpiScale * 0.8, facfg, ranges);
			atlas.addFontFromFileTTF("res/tools/fa-solid-900.ttf",  size * dpiScale * 0.8, facfg, ranges);
		}
		atlas.build();

		return font;
	}

	public static function buildFonts()
	{
		var fontInfo: ImFontTexData = new ImFontTexData();
		var atlas = ImGui.getFontAtlas();
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

			var scene: h2d.Scene = cast previewEvents.scenes[0];
			if( scene != null )
			{
				var vsx = scene.width / windowSizeX;
				var vsy = scene.height / windowSizeY;
				previewEvents.setMousePos( event.relX * vsx, event.relY * vsy );
			}

		}


		return true;

		//preview.dispatchListeners( event );

		#end
	}
}

#end