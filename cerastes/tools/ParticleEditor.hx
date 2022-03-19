
package cerastes.tools;

import hl.Ref;
#if hlimgui

import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import imgui.NodeEditor;

import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImGuiNodes;

@:keep
class ParticleEditor extends ImguiTool
{

	var dockID : ImGuiID = -1;

	var nodes : ImGuiNodes;

	public function new()
	{
		nodes = new ImGuiNodes();
	}



	override public function update( delta: Float )
	{
		if( dockID == -1 )
			dockID = ImGui.getID("PEMain");

		ImGui.begin("\uf06d Particle Editor");



		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		nodes.render();




		ImGui.end();
	}


}

#end