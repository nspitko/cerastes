
package cerastes.tools;


import cerastes.StrictInterp.InterpVariable;
import cerastes.flow.Flow.FlowRunner;
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

	static var saveSlot: Int = -1;

	var runner: FlowRunner;
	var defs: Array<InterpVariable>;

	public override function getName() { return '\uf328 Variables'; }

	public function setup( r: FlowRunner, d: Array<InterpVariable> )
	{
		runner = r;
		defs = d;
	}

	override public function update( delta: Float )
	{
		Metrics.begin();

		ImGui.setNextWindowSize( { x: 400, y: 250 }, ImGuiCond.FirstUseEver );
		if( ImGui.begin("\uf328 Variables") )
		{
			wref( ImGui.inputTextWithHint("##filter","Filter...",_ ), filter );

			if( ImGui.beginCombo( "Save slot", saveSlot != -1 ? 'Slot ${saveSlot}' : "Select..." ) )
			{
				for( i in 0 ... 5 )
				{
					if( ImGui.selectable('Slot ${i}', i == saveSlot ))
					{
						Utils.info('Loading dev save ${i}');
						cerastes.App.saveload.load(i,Dev);
						saveSlot = i;
					}
				}
				ImGui.endCombo();
			}

			ImGui.sameLine();

			if( saveSlot != -1 && ImGui.button("Write") )
			{
				cerastes.App.saveload.save(saveSlot, Dev);
			}

			ImGui.separator();

			buttonRow();

			var spaceToReserve = ImGui.getStyle().ItemSpacing.y + ImGui.getFrameHeightWithSpacing();
			ImGui.beginChild("text", {x: 0, y: -spaceToReserve});
			variableList();
			ImGui.endChild();


			ImGui.end();
		}
		Metrics.end();
	}

	var editorField: String = null;

	@:access(cerastes.Utils)
	function variableList()
	{
		if(runner == null)
			return;

		final ttw = 300;


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

		var keys = [ for(k in defs) k.name ];
		keys.sort( (a: String, b: String ) -> { return a < b ? -1 : 1; } );

		var kv = @:privateAccess runner.context.interp.variables;

		for( k in keys )
		{
			var v = kv[k];

			if( filter != null && filter.length > 0)
			{
				if( !StringTools.contains(k, filter) )
					continue;
			}

			ImGui.tableNextRow();

			ImGui.tableNextColumn();

			ImGui.text( k );

			if( ImGui.isItemHovered() )
			{
				var cs = getCommentString(k);
				if( cs != null )
				{
					ImGui.setNextWindowSize( {x: ttw * scaleFactor, y: 0 } );
					ImGui.beginTooltip();
					ImGui.textMarkdown( cs );
					ImGui.endTooltip();
				}
			}

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
							kv[k] = r.get();

					case TFloat:
						var r = v;
						if( ImGui.inputDouble( '##${k}', r ) )
							kv[k] = r.get();

					case TBool:
						var r = v;
						if( ImGui.checkbox( '##${k}', r ) )
							kv[k] = r.get();

					case TClass( String ):
						var r: Ref<String> = v;
						if( ImGui.inputText( '##${k}', r ) && r != null )
							kv[k] = r.get();

					case _:
						Utils.info('Unhandled type ${Type.typeof( v )}');
				}
			}
			else
			{
				var displayStr: Dynamic = v;
				if( v == "" )
					displayStr = "<Unset>";

				ImGui.text( Std.string( displayStr )  );
			}

			if( ImGui.isItemHovered() )
			{
				var cs = getCommentString(k);
				if( cs != null )
				{
					ImGui.setNextWindowSize( {x: ttw * scaleFactor, y: 0 } );
					ImGui.beginTooltip();
					ImGui.textMarkdown( cs );
					ImGui.endTooltip();
				}
			}



			first = false;

			if( ImGui.isItemClicked( ImGuiMouseButton.Left ) && ImGui.isMouseDoubleClicked( ImGuiMouseButton.Left ) )
			{
				editorField = k;
			}
		}


		ImGui.endTable();

	}

	function getCommentString( k: String )
	{
		var d = getDef( k );
		var comment: String = null;

		if( d != null && d.comment != null )
		{
			var bits = d.comment.split("\n");
			for( i in 0 ... bits.length )
				bits[i] = StringTools.trim(bits[i]);
			comment = bits.join("\n");
		}

		return comment;
	}

	function getDef( k: String )
	{
		for( def in defs)
		{
			if( def.name == k )
				return def;
		}

		return null;
	}

	function buttonRow()
	{

	}


}

#end