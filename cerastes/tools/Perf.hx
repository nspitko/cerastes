
package cerastes.tools;

import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

@:keep
class Perf extends ImguiTool
{
	var fps = new hl.NativeArray<Single>(60);
	var allocs = new hl.NativeArray<Single>(60);
	var allocsLast = new hl.NativeArray<Single>(60);

	//var totalAllocs = new hl.NativeArray<Single>(60);

	var peakDeltaAllocs: Float = 0;

	override public function update( delta: Float )
	{
		var stats = hl.Gc.stats();

		fps.blit(0,fps,1,59);
		fps[59] = hxd.Timer.fps();

		allocs.blit(0,allocs,1,59);
		allocsLast.blit(0,allocsLast,1,59);
		allocsLast[59] = stats.allocationCount;
		allocs[59] = stats.allocationCount - allocsLast[58];


		if( allocs[59] > peakDeltaAllocs )
			peakDeltaAllocs = allocs[59];

		var widgetSize : ImVec2 = {x: 300, y:100};

		ImGui.begin("\uf201 FPS");

		ImGui.plotLines("", fps, 0, 'FPS: ${Math.round( hxd.Timer.fps() * 100 ) / 100.0 }',0,hxd.Timer.wantedFPS * 1.2,widgetSize);
		ImGui.plotLines("", allocs, 0, 'Allocations: ${ Math.round( allocs[59] )}',0,peakDeltaAllocs,widgetSize);
		//ImGui.plotLines("", totalAllocs, 0, 'Total Allocations: ${ Math.round(totalAllocs[59])}',0,peakDeltaTotalAllocs,widgetSize);

		var ramBudget =  4096; // @todo Arbitrary number hello!
		var ramUsage = Gc.stats().currentMemory /1024/1024;

		var usageString = '${ Math.round( ramUsage )}MB allocated';



		ImGui.progressBar( ramUsage / ramBudget,  widgetSize, usageString );

		ImGui.end();
	}
}