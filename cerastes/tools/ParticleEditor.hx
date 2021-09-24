
package cerastes.tools;

#if hlimgui

import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

@:keep
class ParticleEditor extends ImguiTool
{

	var dockID : ImGuiID = -1;

	public function new()
	{

	}



	override public function update( delta: Float )
	{
		if( dockID == -1 )
			dockID = ImGui.getID("PEMain");

		ImGui.begin("\uf06d Particle Editor");



		ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.end();
	}
}

#end