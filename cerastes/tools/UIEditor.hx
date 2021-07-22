
package cerastes.tools;

import hxd.BytesBuffer;
import h2d.Text;
import hl.Ref;
import cerastes.fmt.CUIResource;
import cerastes.fmt.CUIResource.CUIElementDef;
import h2d.Flow;
import h2d.Bitmap;
import h3d.mat.Texture;
import h2d.Object;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;

@:keep
class UIEditor extends ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;

	var preview: h2d.Scene;
	var sceneRT: Texture;
	var sceneRTId: Int;

	var fileName: String;
	var def: CUIElementDef;

	var treeIdx = 0;
	var inspectorTreeSelected: CUIElementDef;

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
		fileName = "ui/test.cui";

		try
		{
			var res = new cerastes.fmt.CUIResource( hxd.Res.loader.load("ui/test.cui").entry );
			def = res.getData().root;
			updateScene();
		} catch(e)
		{
			// do nothing
		}

	}

	function updateScene()
	{
		preview.removeChildren();
		cerastes.fmt.CUIResource.recursiveCreateObjects(def, preview);
	}

	function inspectorColumn()
	{
		ImGui.beginChild("uie_inspector",{x: 200, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize);

		populateInspector();

		ImGui.endChild();
	}

	function editorColumn()
	{
		ImGui.beginChild("uie_editor",{x: 300, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize);

		if( inspectorTreeSelected == null )
		{
			ImGui.text("No item selected...");
		}
		else
		{
			populateEditor();
		}

		ImGui.endChild();
	}

	function menuBar()
	{
		if( ImGui.beginMainMenuBar() )
			{
				if( ImGui.beginMenu("File", true) )
				{
					if (ImGui.menuItem("Open", "Ctrl+O"))
					{
						//ImguiToolManager.showTool("Perf");
					}
					if (ImGui.menuItem("Save", "Ctrl+S"))
					{
						//ImguiToolManager.showTool("UIEditor");
					}
					if (ImGui.menuItem("Save As..."))
					{
						//ImguiToolManager.showTool("UIEditor");
					}

					ImGui.endMenu();
				}
				ImGui.endMainMenuBar();
			}
	}

	override public function update( delta: Float )
	{
		// UI preview pane
		//ImGui.begin("Preview");
		//
		//ImGui.end();

		ImGui.begin("UI Editor", null, ImGuiWindowFlags.AlwaysAutoResize);

		menuBar();

		inspectorColumn();

		ImGui.sameLine();

		// Preview
		ImGui.image(sceneRTId, { x: viewportWidth, y: viewportHeight } );

		ImGui.sameLine();

		editorColumn();

		ImGui.end();

		// Editor window
	}

	function populateInspector()
	{
		if( def == null )
			return;
		// @todo this is dumb.
		var dd: CUIElementDef = {
			type:"dummy",
			name:"dummy",
			props: [],
			children: [def]
		};
		treeIdx = 0;
		populateChildren(dd);

		// Buttons
		ImGui.button("Object", {x: 75, y: 25});
		ImGui.button("Text", {x: 75, y: 25});
		ImGui.button("Bitmap", {x: 75, y: 25});
	}

	function populateChildren( def: CUIElementDef )
	{
		for( idx in 0 ... def.children.length )
		{
			var c = def.children[idx];

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			if( c.children.length == 0)
				flags |= ImGuiTreeNodeFlags.Leaf;

			if( inspectorTreeSelected == c )
				flags |= ImGuiTreeNodeFlags.Selected;

			var name = c.name  != null ? c.name : '${c.type}/{$treeIdx}';
			var isOpen = ImGui.treeNodeEx( name, flags );

			if( ImGui.isItemClicked() )
				inspectorTreeSelected = c;

			if( isOpen  )
			{
				if( c.children.length > 0)
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

	function populateEditor()
	{
		var def = inspectorTreeSelected;
		ImGui.text(def.type);

		var obj = preview.getObjectByName(def.name);
		if( obj == null )
			return;

		populateEditorFields(obj, def.type);

		var s =  Type.getSuperClass( Type.getClass( obj ) );
		while( s != null )
		{
			populateEditorFields( obj, Type.getClassName(s) );
			s = Type.getSuperClass( s );
		}
	}

	function populateEditorFields(obj: Object, type: String )
	{
		switch( type )
		{
			case "h2d.Object":
				ImGui.separator();
				IG.wref( ImGui.inputDouble("X",_,1,10), obj.x );
				IG.wref( ImGui.inputDouble("Y",_,1,10), obj.y );

			case "h2d.Text":
				var t : Text = cast obj;
				ImGui.separator();
				var val = IG.textInput("Text", t.text);
				if( val != null )
					t.text = val;

		}
	}
}