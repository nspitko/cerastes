
package cerastes.tools;


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
class Console extends ImguiTool
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

	public override function getName() { return "\uf120 Console"; }

	override public function update( delta: Float )
	{
		Metrics.begin();

		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);


		ImGui.setNextWindowSize( { x: 400, y: 250 }, ImGuiCond.FirstUseEver );
		if( ImGui.begin("\uf120 Console", isOpenRef) )
		{

			if( wref( ImGui.inputTextWithHint("##filter","Filter...",_ ), filter ) )
			{
				/// Update filter...
			}

			buttonRow();

			var spaceToReserve = ImGui.getStyle().ItemSpacing.y + ImGui.getFrameHeightWithSpacing();
			ImGui.beginChild("text", {x: 0, y: -spaceToReserve});
			consoleText();
			ImGui.endChild();

			var command = "";

			var flags = ImGuiInputTextFlags.CallbackCompletion | ImGuiInputTextFlags.EnterReturnsTrue | ImGuiInputTextFlags.CallbackHistory;
			if( wref( ImGui.inputTextWithHint("##command","Command",_, flags, commandHint ), command ) )
			{
				runCommand( command );
				ImGui.setKeyboardFocusHere(-1);
			}

		}
		ImGui.end();
		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}
		Metrics.end();
	}


	@:access(h2d.Console)
	function commandHint( data: ImGuiInputTextCallbackData )
	{
		switch( data.eventFlag )
		{
			case ImGuiInputTextFlags.CallbackCompletion:

				var gc = GlobalConsole.instance.console;
				var str = @:privateAccess String.fromUTF8(data.buf);

                // Locate beginning of current word
                var wordEnd = data.cursorPos;
                var wordStart = wordEnd;
                while (wordStart > 0)
                {
                    var c = str.charAt(wordStart);
                    if (c == ' ' || c == '\t' || c == ',' || c == ';')
                        break;
                    wordStart--;
                }

				var word = str.substr( wordStart, wordEnd - wordStart ).toLowerCase();

                // Build a list of candidates
                var candidates = [];
                for( cmd => cmdData in gc.commands )
                    if ( cmd.substr( 0, wordEnd - wordStart ).toLowerCase() == word )
                        candidates.push( cmd );

                if (candidates.length == 0)
                {
                    // No match
                    Utils.info('No match for $word');
                }
                else if (candidates.length == 1)
                {
                    // Single match. Delete the beginning of the word and replace it entirely so we've got nice casing.
					data.deleteChars( wordStart, wordEnd - wordStart );
                    data.insertChars( data.cursorPos, candidates[0] );
                    data.insertChars( data.cursorPos, " " );
                }
                else
                {
                    // Multiple matches. Complete as much as we can..
                    // So inputing "C"+Tab will complete to "CL" then display "CLEAR" and "CLASSIFY" as matches.
                    var matchLen = (wordEnd - wordStart);
                    while( true )
                    {
                        var c = "";
                        var allCandidatesMatches = true;
						var i = 0;
                        while ( i < candidates.length && allCandidatesMatches)
						{
                            if (i == 0)
                                c = candidates[i].charAt(matchLen).toUpperCase();
                            else if ( c != candidates[i].charAt(matchLen).toUpperCase() )
                                allCandidatesMatches = false;
							i++;
						}
                        if (!allCandidatesMatches)
                            break;
                        matchLen++;
                    }

                    if (matchLen > 0)
                    {
                        data.deleteChars(wordStart, wordEnd - wordStart);
                        data.insertChars(data.cursorPos, candidates[0].substr(0,matchLen));
                    }

                    // List matches
                    Utils.info("Possible matches:");

                    for ( i in 0 ... candidates.length )
                        Utils.info('- ${candidates[i]}' );
                }
			case ImGuiInputTextFlags.CallbackHistory:
				var lastHistoryPos = historyPos;
				if( data.eventKey == ImGuiKey.UpArrow )
				{
					if( historyPos == -1 )
						historyPos = history.length - 1;
					else if( historyPos > 0 )
						historyPos --;
				}
				if( data.eventKey == ImGuiKey.DownArrow )
				{
					if( historyPos != -1 )
						if( ++historyPos >= history.length )
							historyPos = -1;
				}

				if( lastHistoryPos != historyPos )
				{
					var historyStr = ( historyPos >= 0 ) ? history[historyPos] : "";
					data.deleteChars(0, data.bufTextLen );
					data.insertChars(0, historyStr);
				}

			default:

		}

		return 0;
	}

	@:access(h2d.Console)
	function runCommand( c: String )
	{
		history.push(c);
		var gc = GlobalConsole.instance.console;
		gc.runCommand( c );
	}

	@:access(cerastes.Utils)
	function consoleText()
	{
		if( ImGui.beginTable( "textTable", 3, ImGuiTableFlags.Resizable | ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.Hideable ) )
		{
			var c: ImVec4 = {x: 0.8, y: 0.8, z: 0.8, w: 1.0 };

			var first = true;
			var precision: Float = 10000;

			ImGui.pushFont( ImGuiToolManager.consoleFont );


			//ImGui.tableSetColumnEnabled( 0, showTime );
			ImGui.tableSetupColumn("Timestamp", ImGuiTableColumnFlags.WidthFixed, 50 * scaleFactor );
			//var flags = ImGui.tableGetColumnFlags();

			//ImGui.tableSetColumnEnabled( 1, showPos );
			ImGui.tableSetupColumn("Pos", ImGuiTableColumnFlags.WidthFixed | ImGuiTableColumnFlags.DefaultHide , 175 * scaleFactor );
			//var flags = ImGui.tableGetColumnFlags();

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

					case ALWAYS:
						ImGui.pushStyleColor( ImGuiCol.Text, 0xFFFFFFFF );

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
				var p = line.pos.fileName.lastIndexOf('/');
				ImGui.text('${line.pos.fileName.substr(p+1)}:${line.pos.lineNumber}' );
				var flags = ImGui.tableGetColumnFlags();

				ImGui.tableNextColumn();
				ImGui.textWrapped(line.line  );

				ImGui.popStyleColor();

				if( flags | ImGuiTableColumnFlags.IsVisible != 0 && ImGui.isItemHovered() )
					ImGui.setTooltip('${line.pos.fileName}:${line.pos.lineNumber}\n${line.pos.className}::${line.pos.methodName}()');



				first = false;
			}

			ImGui.popFont();

			ImGui.endTable();

			if ( scrollToBottom )
				ImGui.setScrollHereY(1.);

			scrollToBottom = false;
		}
	}

	function buttonRow()
	{
		// Filters
		wref( ImGui.checkbox("Info", _ ), showInfo );
		ImGui.sameLine();
		wref( ImGui.checkbox("Warn", _ ), showWarn );
		ImGui.sameLine();
		wref( ImGui.checkbox("Error", _ ), showErr );

		ImGui.sameLine();

		// Columns
		wref( ImGui.checkbox("Time", _ ), showTime );
		ImGui.sameLine();
		wref( ImGui.checkbox("Pos", _ ), showPos );

		// Columns
	}


}

#end