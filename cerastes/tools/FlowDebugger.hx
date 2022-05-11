
package cerastes.tools;

import cerastes.flow.Flow.FlowRunner;
import cerastes.flow.Flow.FlowNode;
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
import cerastes.data.Nodes;

@:structInit
class FlowHistoryElement
{
	public var file: String;
	public var fromNode: FlowNode;
	public var toNode: FlowNode;
	public var fromPin: PinId32;
}

@:keep
class FlowDebugger extends ImguiTool
{

	var scaleFactor = Utils.getDPIScaleFactor();

	static var flowHistory: List<FlowHistoryElement> = new List<FlowHistoryElement>();


	override public function update( delta: Float )
	{
		Metrics.begin();

		ImGui.begin("\uf1de Flow debugger");

		ImGui.end();
		Metrics.end();
	}

	public static function addHistory(runner: FlowRunner, from: FlowNode, to: FlowNode, fromPin: PinId32)
	{
		flowHistory.add({
			file: @:privateAccess runner.file,
			fromNode: from,
			toNode: to,
			fromPin: fromPin,
		});
	}

}

#end