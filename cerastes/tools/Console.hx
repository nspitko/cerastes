
package cerastes.tools;

#if hlimgui
import h3d.Engine;
import hxd.Key;
import h2d.Tile;
import cerastes.macros.Metrics;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTool.ImguiToolManager;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

@:keep
class Console extends ImguiTool
{
	var scaleFactor = Utils.getDPIScaleFactor();

	//var totalAllocs = new hl.NativeArray<Single>(60);

	public var filter: String = "";
	public var command: String = "";

	public var showInfo = true;
	public var showWarn = true;
	public var showErr = true;

	var scrollToBottom = false;
	var autoScroll = true;
	var lastLen = 0;

	override public function update( delta: Float )
	{
		Metrics.begin();

		ImGui.setNextWindowSize( { x: 400, y: 250 }, ImGuiCond.FirstUseEver );
		ImGui.begin("\uf120 Console");

		if( IG.wref( ImGui.inputTextWithHint("##filter","Filter...",_ ), filter ) )
		{
			/// Update filter...
		}

		buttonRow();

		var spaceToReserve = ImGui.getStyle().ItemSpacing.y + ImGui.getFrameHeightWithSpacing();
		ImGui.beginChild("text", {x: 0, y: -spaceToReserve});
		consoleText();
		ImGui.endChild();

		if( IG.wref( ImGui.inputTextWithHint("##command","Command",_ ), command ) )
		{
			/// Update filter...
		}


		ImGui.end();
		Metrics.end();
	}

	@:access(cerastes.Utils)
	function consoleText()
	{
		ImGui.beginTable( "textTable",2 );

		var c: ImVec4 = {x: 0.8, y: 0.8, z: 0.8, w: 1.0 };

		var first = true;
		var precision: Float = 10000;

		ImGui.pushFont( ImguiToolManager.consoleFont );

		ImGui.tableSetupColumn("Timestamp", ImGuiTableColumnFlags.PreferSortAscending | ImGuiTableColumnFlags.WidthFixed, 50 * scaleFactor );
		ImGui.tableSetupColumn("Text", ImGuiTableColumnFlags.WidthStretch );

		ImGui.tableHeadersRow();

		scrollToBottom = autoScroll && Utils.log.length != lastLen;
		lastLen = Utils.log.length;


		for( line in Utils.log )
		{
			switch( line.level )
			{
				case INFO:
					ImGui.pushStyleColor( ImGuiCol.Text, 0xFFDEDEDE );

				case WARNING:
					ImGui.pushStyleColor( ImGuiCol.Text, 0xFFFFFF33 );

				case ERROR:
					ImGui.pushStyleColor( ImGuiCol.Text, 0xFFFF3333 );

				default:
					ImGui.pushStyleColor( ImGuiCol.Text, 0xFFDEDEDE );

			}

			ImGui.tableNextRow();
			ImGui.tableNextColumn();
			ImGui.text('${ Math.round( line.time * precision ) / precision}'  );
			ImGui.tableNextColumn();

			ImGui.textWrapped(line.line  );
			ImGui.popStyleColor();

			first = false;
		}

		ImGui.popFont();

		ImGui.endTable();

		if ( scrollToBottom )
            ImGui.setScrollHereY(1.);

        scrollToBottom = false;
	}

	function buttonRow()
	{
		// Filters
		IG.wref( ImGui.checkbox("Info", _ ), showInfo );
		ImGui.sameLine();
		IG.wref( ImGui.checkbox("Warn", _ ), showWarn );
		ImGui.sameLine();
		IG.wref( ImGui.checkbox("Error", _ ), showErr );

		// Columns
	}


}

#end