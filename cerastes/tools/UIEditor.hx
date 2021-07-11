
package cerastes.tools;

import h2d.Flow;
import h2d.Bitmap;
import h3d.mat.Texture;
import h2d.Object;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

@:keep
class UIEditor extends ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;

	var preview: h2d.Scene;
	var sceneRT: Texture;
	var sceneRTId: Int;

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");
		viewportWidth = 640;
		viewportHeight = 360;
		if( size != null )
		{
			var p = size.split("x");
			viewportWidth = Std.parseInt(p[0]);
			viewportHeight = Std.parseInt(p[1]);
		}

		preview = new h2d.Scene();
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);

		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );
		sceneRTId = ImGuiDrawableBuffers.instance.registerTexture( sceneRT );

		// TEMP: Populate with some crap

		var ctn = new Object(preview);
		ctn.name = "Test container";
		var spr = new Bitmap( hxd.Res.spr.placeholder.toTile(), ctn );
		spr.name = "placeholder";
		spr.x = 10;
		spr.y = 20;

		var flow = new Flow(ctn);
		var text = new h2d.Text(hxd.Res.fnt.kodenmanhou16.toFont(), flow );
		text.text = "Hello!";

		text = new h2d.Text(hxd.Res.fnt.kodenmanhou16.toFont(), flow );
		text.text = "World?";

	}

	override public function update( delta: Float )
	{
		// UI preview pane
		ImGui.begin("Preview");
		ImGui.image(sceneRTId, { x: viewportWidth, y: viewportHeight } );
		ImGui.end();

		ImGui.begin("UI Editor", null, ImGuiWindowFlags.AlwaysAutoResize);

		ImGui.beginChild("uie_inspector",{x: 200, y: 400}, false, ImGuiWindowFlags.AlwaysAutoResize);

		populateChildren( preview );

		ImGui.endChild();

		ImGui.end();

		// Editor window
	}

	function populateChildren( o: Object )
	{
		for( idx in 0 ... o.numChildren )
		{
			var c = o.getChildAt(idx);

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			if( c.numChildren == 0)
				flags |= ImGuiTreeNodeFlags.Leaf;
			var name = c.name  != null ? c.name : '${Type.getClassName( Type.getClass( c ) )}';

			var isOpen = ImGui.treeNodeEx( name, flags );

			if( isOpen  )
			{
				if( c.numChildren > 0)
				{
					populateChildren(c);
				}
				ImGui.treePop();
			}








		}
	}

	override public function render( e: h3d.Engine)
	{
		sceneRT.clear( 0 );

		e.pushTarget( sceneRT );
		e.clear(0,1);
		preview.render(e);
		e.popTarget();
	}
}