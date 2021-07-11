
package cerastes.tools;

import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

@:keep
class Perf extends ImguiTool
{
	var fps = new hl.NativeArray<Single>(60);

	override public function update( delta: Float )
	{

		fps.blit(0,fps,1,59);
		fps[59] = hxd.Timer.fps();

		ImGui.begin("FPS");

		ImGui.plotLines("", fps, 0, 'FPS: ${hxd.Timer.fps()}',0,hxd.Timer.wantedFPS,{x: 300, y:100});

		ImGui.end();
	}
}