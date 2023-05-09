
package cerastes.tools;


import game.GameState;
import cerastes.ui.Console.GlobalConsole;
#if hlimgui
import h2d.Console.ConsoleArg;
import h3d.Engine;
import hxd.Key;
import h2d.Tile;
import cerastes.macros.Metrics;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTool.ImGuiToolManager;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

import imgui.ImGuiMacro.wref;

@:keep
class VariableEditor extends ImguiTool
{
	var scaleFactor = Utils.getDPIScaleFactor();

	//var totalAllocs = new hl.NativeArray<Single>(60);

	public var filter: String = "";
	public var command: String = "";

	public var showInfo = true;
	public var showWarn = true;
	public var showErr = true;

	public var showPos = true;
	public var showTime = true;

	var scrollToBottom = false;
	var autoScroll = true;
	var lastLen = 0;

	var historyPos: Int = -1;
	var history: Array<String> = [];

	override public function update( delta: Float )
	{
		Metrics.begin();

		ImGui.setNextWindowSize( { x: 400, y: 250 }, ImGuiCond.FirstUseEver );
		ImGui.begin("\uf328 Variables");

		if( wref( ImGui.inputTextWithHint("##filter","Filter...",_ ), filter ) )
		{
			/// Update filter...
		}

		buttonRow();

		var spaceToReserve = ImGui.getStyle().ItemSpacing.y + ImGui.getFrameHeightWithSpacing();
		ImGui.beginChild("text", {x: 0, y: -spaceToReserve});
		variableList();
		ImGui.endChild();


		ImGui.end();
		Metrics.end();
	}

	var editorField: String = null;

	@:access(cerastes.Utils)
	function variableList()
	{


		ImGui.beginTable( "textTable", 3, ImGuiTableFlags.Resizable | ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.Hideable );

		var c: ImVec4 = {x: 0.8, y: 0.8, z: 0.8, w: 1.0 };

		var first = true;
		var precision: Float = 10000;


		//ImGui.tableSetColumnEnabled( 0, showTime );
		ImGui.tableSetupColumn("Name", ImGuiTableColumnFlags.WidthFixed, 150 * scaleFactor );
		//var flags = ImGui.tableGetColumnFlags();

		ImGui.tableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch );

		ImGui.tableHeadersRow();

		scrollToBottom = autoScroll && Utils.log.length != lastLen;
		lastLen = Utils.log.length;


		for( k => v in GameState.data.kv )
		{

			ImGui.tableNextRow();

			ImGui.tableNextColumn();
			ImGui.text( k );

			if( ImGui.isItemClicked( ImGuiMouseButton.Left ) && ImGui.isMouseDoubleClicked( ImGuiMouseButton.Left ) )
			{
				editorField = k;
			}

			ImGui.tableNextColumn();

			if( editorField == k )
			{
				switch ( Type.typeof( v ) )
				{
					case TInt:
						var r = v;
						if( ImGui.inputInt( '##${k}', r ) )
							GameState.data.kv[k] = r.get();

					case TFloat:
						var r = v;
						if( ImGui.inputDouble( '##${k}', r ) )
							GameState.data.kv[k] = r.get();

					case TBool:
						var r = v;
						if( ImGui.checkbox( '##${k}', r ) )
							GameState.data.kv[k] = r.get();

					case _:
						trace('Unhandled type ${Type.typeof( v )}');
				}
			}
			else
			{
				ImGui.text( Std.string( v )  );
			}

			//if( flags | ImGuiTableColumnFlags.IsVisible != 0 && ImGui.isItemHovered() )
			//	ImGui.setTooltip('${line.pos.fileName}:${line.pos.lineNumber}\n${line.pos.className}::${line.pos.methodName}()');



			first = false;

			if( ImGui.isItemClicked( ImGuiMouseButton.Left ) && ImGui.isMouseDoubleClicked( ImGuiMouseButton.Left ) )
			{
				editorField = k;
			}
		}


		ImGui.endTable();

	}

	function buttonRow()
	{

	}


}

#end