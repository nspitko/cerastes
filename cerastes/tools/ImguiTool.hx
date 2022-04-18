
package cerastes.tools;

#if hlimgui
import imgui.ImGui;

import imgui.ImGui.ImFont;
import cerastes.macros.Metrics;
import haxe.rtti.Meta;
import haxe.macro.Expr;

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

class ImguiToolManager
{
	static var tools = new Array<ImguiTool>();

	public static var defaultFont: ImFont;
	public static var headingFont: ImFont;
	public static var consoleFont: ImFont;

	public static var scaleFactor = Utils.getDPIScaleFactor();

	public static var toolIdx = 0;

	public static var popupStack: Array<ImGuiPopup> = [];

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

	public static function update( delta: Float )
	{
		Metrics.begin();

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
	}
}

#end