
package cerastes.tools;

import haxe.EnumTools;
import haxe.io.Bytes;
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
	var rootDef: CUIElementDef;

	var treeIdx = 0;
	var selectedInspectorTree: CUIElementDef;
	var selectedDragDrop: CUIElementDef;

	var scaleFactor = Utils.getDPIScaleFactor();

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
			rootDef = res.getData().root;
			updateScene();
		} catch(e)
		{
			// do nothing
		}

	}

	function updateScene()
	{
		preview.removeChildren();
		cerastes.fmt.CUIResource.recursiveCreateObjects(rootDef, preview);
	}

	function inspectorColumn()
	{
		ImGui.beginChild("uie_inspector",{x: 200 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize );


		// Buttons
		if( ImGui.button("Add") )
		{
			ImGui.openPopup("uie_additem");
		}

		if( ImGui.beginPopup("uie_additem") )
		{
			var types = ["h2d.Object", "h2d.Text", "h2d.Bitmap", "h2d.Flow"];

			for( t in types )
			{
				if( ImGui.menuItem( '${getIconForType(t)} ${getNameForType(t)}') )
					addItem(t);
			}

			ImGui.endPopup();
		}
		ImGui.sameLine();

		if( ImGui.button("Delete") && selectedInspectorTree != null )
		{
			var parent = getDefParent( selectedInspectorTree );
			if( parent == null )
			{

			}
			else
			{
				parent.children.remove(selectedInspectorTree);
				selectedInspectorTree = null;
				updateScene();
			}


		}


		ImGui.beginChild("uie_inspector_tree",{x: 200 * scaleFactor, y: 400}, false, ImGuiWindowFlags.AlwaysAutoResize);

		populateInspector();

		ImGui.endChild();



		ImGui.endChild();


	}

	function editorColumn()
	{
		ImGui.beginChild("uie_editor",{x: 300 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize);

		if( selectedInspectorTree == null )
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

		ImGui.begin("\uf108 UI Editor", null, ImGuiWindowFlags.AlwaysAutoResize );

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
		if( rootDef == null )
			return;
		// @todo this is dumb.
		var dd: CUIElementDef = {
			type:"dummy",
			name:"dummy",
			props: [],
			children: [rootDef]
		};
		treeIdx = 0;
		populateChildren(dd);


	}

	function getAutoName( type: String )
	{
		var name;
		var n = 0;
		do
		{
			name = '${getNameForType(type)} ${++n}';
		} while( preview.getObjectByName(name) != null );

		return name;
	}

	function populateChildren( def: CUIElementDef )
	{
		for( idx in 0 ... def.children.length )
		{
			var c = def.children[idx];
			if( c == null )
				break;

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			if( c.children.length == 0)
				flags |= ImGuiTreeNodeFlags.Leaf;

			if( selectedInspectorTree == c )
				flags |= ImGuiTreeNodeFlags.Selected;

			var name = c.name  != null ? c.name : '${c.type}/{$treeIdx}';
			name = '${getIconForType( c.type )} ${name}';
			var isOpen = ImGui.treeNodeEx( name, flags );

			if( ImGui.isItemClicked() )
				selectedInspectorTree = c;

			// Drag source
			var srcFlags: ImGuiDragDropFlags  = 0;
			srcFlags |= ImGuiDragDropFlags.SourceNoPreviewTooltip;

			if( ImGui.beginDragDropSource( srcFlags ) )
			{
				ImGui.setDragDropPayloadString("name", c.name );

				ImGui.beginTooltip();


				ImGui.text(name);


				ImGui.endTooltip();

				ImGui.endDragDropSource();
			}

			if( ImGui.beginDragDropTarget() )
			{
				var targetFlags : ImGuiDragDropFlags = 0;

				var payload = ImGui.acceptDragDropPayloadString("name");
				if( payload != null )
				{
					var dropDef = getDefByName( payload );
					selectedDragDrop = dropDef;
					ImGui.openPopup('${c.name}_uie_popup');
				}

				ImGui.endDragDropTarget();
			}

			if( ImGui.beginPopup('${c.name}_uie_popup') )
			{
				if( ImGui.menuItem( '\uf30c Move Above') )
				{
					var oldParent = getDefParent(selectedDragDrop);
					oldParent.children.remove(selectedDragDrop);

					var newIdx = def.children.indexOf(c);
					def.children.insert(newIdx,selectedDragDrop);

					updateScene();
				}
				if( ImGui.menuItem( '\uf2f5 Make child') )
				{
					var oldParent = getDefParent(selectedDragDrop);
					// Make sure we're not about to orphan this tree
					var isChildOfParent = getDefParent( c,selectedDragDrop ) != null;

					if( !isChildOfParent && oldParent != null )
					{
						oldParent.children.remove(selectedDragDrop);

						c.children.push(selectedDragDrop);

						updateScene();
					}


				}
				if( ImGui.menuItem( '\uf309 Move Below') )
				{
					var oldParent = getDefParent(selectedDragDrop);
					oldParent.children.remove(selectedDragDrop);

					var newIdx = def.children.indexOf(c);
					def.children.insert(newIdx+1,selectedDragDrop);

					updateScene();
				}


				ImGui.endPopup();
			}

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

	function getDefByName(name: String, def: CUIElementDef = null )
	{
		if( def == null )
			def = rootDef;

		if( def.name == name )
			return def;

		for( c in def.children )
		{
			var d = getDefByName( name, c );
			if( d != null )
				return d;
		}
		return null;
	}

	function getDefParent(find: CUIElementDef, ?def: CUIElementDef = null )
	{
		if( def == null )
			def = rootDef;

		for( c in def.children )
		{
			if( c.name == find.name )
				return def;

			var d = getDefParent(find, c );
			if( d != null )
				return d;
		}
		return null;
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
		var def = selectedInspectorTree;
		ImGui.text(def.type);


		var obj = preview.getObjectByName(def.name);
		if( obj == null )
			return;

		populateEditorFields(obj, def, def.type);

		var s =  Type.getSuperClass( Type.getClass( obj ) );
		while( s != null )
		{
			populateEditorFields( obj, def, Type.getClassName(s) );
			s = Type.getSuperClass( s );
		}
	}

	//
	// Field related functions
	//

	function populateEditorFields(obj: Object, def: CUIElementDef, type: String )
	{
		switch( type )
		{
			case "h2d.Object":
				ImGui.separator();
				if( IG.wref( ImGui.inputDouble("X",_,1,10,"%.2f"), obj.x ) )
					def.props["x"] = obj.x;
				if( IG.wref( ImGui.inputDouble("Y",_,1,10,"%.2f"), obj.y ) )
					def.props["y"] = obj.y;

			case "h2d.Drawable":
				var t : h2d.Drawable = cast obj;
				ImGui.separator();
				// Color
				var color = new hl.NativeArray<Single>(4);
				color[0] = t.color.r;
				color[1] = t.color.g;
				color[2] = t.color.b;
				color[3] = t.color.a;
				var flags = ImGuiColorEditFlags.AlphaBar | ImGuiColorEditFlags.AlphaPreview
						| ImGuiColorEditFlags.DisplayRGB | ImGuiColorEditFlags.DisplayHex
						| ImGuiColorEditFlags.AlphaPreviewHalf;
				if( IG.wref( ImGui.colorPicker4( "Color", _, flags), color ) )
				{
					t.color.set(color[0], color[1], color[2], color[3] );
					def.props["color"] = t.color.toColor();
				}

			case "h2d.Text":
				var t : Text = cast obj;

				ImGui.separator();
				var val = IG.textInputMultiline("Text", t.text, null, ImGuiInputTextFlags.Multiline);
				if( val != null )
				{
					t.text = val;
					def.props["text"] = t.text;
				}

				var out = IG.combo("Text Align", t.textAlign, h2d.Text.Align );
				if( out != null )
				{
					t.textAlign = out;
					def.props["text_align"] = EnumValueTools.getIndex(out);
				}

				var maxWidth: Float = t.maxWidth > 0 ? t.maxWidth : 0;
				if( IG.wref( ImGui.inputDouble("Max Width",_,1,10,"%.2f"), maxWidth ) )
				{
					if( maxWidth > 0 )
						t.maxWidth = maxWidth
					else
						t.maxWidth = null;
					def.props["max_width"] = maxWidth;
				}


			case "h2d.Bitmap":
				var b : Bitmap = cast obj;
				var newTile = IG.textInput( "Tile", def.props["tile"] );
				if( newTile != null && hxd.Res.loader.exists( newTile ) )
				{
					def.props["tile"] = newTile;
					b.tile = hxd.Res.loader.load( newTile ).toTile();
				}

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && hxd.Res.loader.exists( payload ) )
					{
						def.props["tile"] = payload;
						b.tile = hxd.Res.loader.load( payload ).toTile();
					}
					ImGui.endDragDropTarget();
				}

				var width: Float = b.width > 0 ? b.width : 0;
				if( IG.wref( ImGui.inputDouble("Width",_,1,10,"%.2f"), width ) )
				{
					if( width > 0 )
						b.width = width
					else
						b.width = null;
					def.props["width"] = width;
				}

				var height: Float = b.height > 0 ? b.height : 0;
				if( IG.wref( ImGui.inputDouble("Height",_,1,10,"%.2f"), height ) )
				{
					if( height > 0 )
						b.height = height
					else
						b.height = null;
					def.props["height"] = height;
				}

			case "h2d.Flow":
				var t: h2d.Flow = cast obj;


				var layout = IG.combo("Layout", t.layout, h2d.Flow.FlowLayout );
				if( layout != null )
				{
					t.layout = layout;
					def.props["layout"] = EnumValueTools.getIndex(layout);
				}


				var align = IG.combo("Vertical Align", t.verticalAlign, h2d.Flow.FlowAlign );
				if( align != null )
				{
					t.verticalAlign = align;
					def.props["vertical_align"] = EnumValueTools.getIndex(align);
				}
				align = IG.combo("Horizontal Align", t.horizontalAlign, h2d.Flow.FlowAlign );
				if( align != null )
				{
					t.horizontalAlign = align;
					def.props["horizontal_align"] = EnumValueTools.getIndex(align);
				}



		}
	}

	function getNameForType( type: String )
	{
		switch(type)
		{
			default:
				return type.substr( type.indexOf(".") +1 );
		}
	}

	function getIconForType( type: String )
	{
		switch( type )
		{
			case "h2d.Object": return "\uf0b2";
			case "h2d.Text": return "\uf031";
			case "h2d.Bitmap": return "\uf03e";
			case "h2d.Flow": return "\uf0db";
			default: return "";
		}
	}

	function addItem(type: String)
	{
		var parent = selectedInspectorTree != null ? selectedInspectorTree : rootDef;

		var def: CUIElementDef = {
			type: type,
			name: getAutoName(type),
			props: [],
			children: []
		};

		// Populate enough values to allow object creation
		switch( type )
		{
			case "h2d.Text":
				def.props["text"] = def.name;
				def.props["font"] = "fnt/kodenmanhou16.fnt";
			case "h2d.Bitmap":
				def.props["tile"] = "spr/placeholder.png";
		}

		parent.children.push(def);

		updateScene();
	}
}