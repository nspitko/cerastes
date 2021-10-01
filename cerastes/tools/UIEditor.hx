
package cerastes.tools;

import h3d.Vector;
#if hlimgui

import h2d.col.Point;
import h2d.Graphics;
import hl.UI;
import cerastes.tools.ImguiTool.ImguiToolManager;
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

typedef ObjectWidthDimensions = {
	var width: Float;
	var height: Float;
}

@:keep
class UIEditor extends ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;

	var preview: h2d.Scene;
	var previewRoot: Object;
	var sceneRT: Texture;
	var sceneRTId: Int;

	var fileName: String;
	var rootDef: CUIElementDef;

	var treeIdx = 0;
	var selectedInspectorTree: CUIElementDef;
	var selectedDragDrop: CUIElementDef;

	var scaleFactor = Utils.getDPIScaleFactor();

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var selectedItemBorder: Graphics;
	var cursor: Graphics;

	var mouseScenePos: ImVec2;
	var mouseDragDuration: Float = -1;
	var mouseDragStartPos: ImVec2;

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

		selectedItemBorder = new h2d.Graphics();
		cursor = new h2d.Graphics();



	}

	public function openFile( f: String )
	{
		fileName = f;

		try
		{
			var res = new cerastes.fmt.CUIResource( hxd.Res.loader.load(fileName).entry );
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
		previewRoot = new Object(preview);
		cerastes.fmt.CUIResource.recursiveCreateObjects(rootDef, previewRoot);
		//selectedItemBorder = new Graphics();
		preview.addChild(selectedItemBorder);
		preview.addChild(cursor);

	}

	function inspectorColumn()
	{
		//ImGui.beginChild("uie_inspector",{x: 200 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize );
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Inspector##${windowID()}');


		// Buttons
		if( ImGui.button("Add") )
		{
			ImGui.openPopup("uie_additem");
		}

		if( ImGui.beginPopup("uie_additem") )
		{
			var types = ["h2d.Object", "h2d.Text", "h2d.Bitmap", "h2d.Flow", "h2d.Mask", "h2d.Interactive"];

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



		//ImGui.endChild();
		ImGui.end();
	}

	function editorColumn()
	{
		//ImGui.beginChild("uie_editor",{x: 300 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize);
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Editor##${windowID()}');

		if( selectedInspectorTree == null )
		{
			ImGui.text("No item selected...");
		}
		else
		{
			populateEditor();
		}

		//ImGui.endChild();
		ImGui.end();
	}

	function menuBar()
	{
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if (ImGui.menuItem("Save", "Ctrl+S"))
				{
					CUIResource.writeObject(rootDef,preview,fileName);
				}
				if (ImGui.menuItem("Save As..."))
				{
					var newFile = UI.saveFile({
						title:"Save As...",
						filters:[
						{name:"Cerastes UI files", exts:["cui"]}
						]
					});
					if( newFile != null )
					{
						var idx = newFile.indexOf("res");
						if( idx != -1 )
						{
							var localPath = newFile.substr(idx);
							fileName = localPath;
						}

						CUIResource.write(rootDef,fileName);

						cerastes.tools.AssetBrowser.needsReload = true;
					}
				}

				ImGui.endMenu();
			}
			if( ImGui.beginMenu("View", true) )
			{
				if (ImGui.menuItem("Reset docking"))
				{
					dockCond = ImGuiCond.Always;
				}
				ImGui.endMenu();
			}
			ImGui.endMenuBar();
		}
	}

	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: viewportWidth + 800, y: viewportHeight + 120}, ImGuiCond.Once);
		ImGui.begin('\uf108 UI Editor##${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		inspectorColumn();

		//ImGui.sameLine();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoMove);

		var startPos: ImVec2 = ImGui.getCursorScreenPos();
		var mousePos: ImVec2 = ImGui.getMousePos();
		mouseScenePos = {x: mousePos.x - startPos.x, y: mousePos.y - startPos.y };

		ImGui.image(sceneRT, { x: viewportWidth, y: viewportHeight } );

		ImGui.end();

		//ImGui.sameLine();

		editorColumn();

		//ImGui.end();

		// Editor window

		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}

		processSceneMouse( delta );

		// Selected Border stuff
		selectedItemBorder.clear();
		if( selectedInspectorTree != null )
		{
			var o = preview.getObjectByName( selectedInspectorTree.name );
			var type = Type.getClassName( Type.getClass( o ) );

			var bounds = o.getBounds();

			if( bounds.getSize().x > 0 || bounds.getSize().y > 0 )
			{
				selectedItemBorder.lineStyle(4,0x6666ff);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, bounds.width, bounds.height);
			}

		}
	}

	function processSceneMouse( delta: Float )
	{
		if( ImGui.isMouseClicked(ImGuiMouseButton.Left) && previewRoot != null )
		{
			var matches = previewRoot.findAll(function(o: Object){
				var bounds = o.getBounds();
				return bounds.contains( new Point(mouseScenePos.x, mouseScenePos.y) ) ? o : null;
			});

			// return the highest match

			if( matches.length > 0 )
			{
				var target = matches[matches.length-1];
				while( target.name == null && target.parent != null )
					target = target.parent;

				var def = getElementDefByName( target.name, rootDef );
				if( def != null )
					selectedInspectorTree = def;


			}
		}

		// Drag
		if( selectedInspectorTree != null )
		{
			var o = preview.getObjectByName( selectedInspectorTree.name );
			var bounds = o.getBounds();

			if( ImGui.isMouseDown( ImGuiMouseButton.Left ) )
			{
				if( mouseDragDuration == 0 )
				{
					// Make sure we're STARTING on bounds, we can leave it while we drag
					if( bounds.contains( new Point( mouseScenePos.x, mouseScenePos.y ) ) )
					{
						mouseDragStartPos = mouseScenePos;
						mouseDragDuration = delta;
					}
				}
				else
				{
					mouseDragDuration += delta;
				}
			}
			else
			{
				mouseDragDuration = 0;
			}

			if( mouseDragDuration > 0.1 && selectedInspectorTree != null )
			{

				o.x += mouseScenePos.x - mouseDragStartPos.x;
				o.y += mouseScenePos.y - mouseDragStartPos.y;

				mouseDragStartPos = mouseScenePos;
			}
		}
	}

	function getElementDefByName( name: String, def: CUIElementDef ) : CUIElementDef
	{
		if( def.name == name )
			return def;

		for( c in def.children )
		{
			var def = getElementDefByName(name, c );
			if( def != null )
				return def;
		}

		return null;
	}

	inline function windowID()
	{
		return 'spre${fileName}';
	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = "UIEditorDockspace";

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut: hl.Ref<ImGuiID> = dockspaceId;

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
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
				IG.wref( ImGui.inputDouble("X",_,1,10,"%.2f"), obj.x );
				IG.wref( ImGui.inputDouble("Y",_,1,10,"%.2f"), obj.y );

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
				}

			case "h2d.Text":
				var t : Text = cast obj;

				ImGui.separator();
				var val = IG.textInputMultiline("Text", t.text, null, ImGuiInputTextFlags.Multiline);
				if( val != null )
				{
					t.text = val;

				}

				var out = IG.combo("Text Align", t.textAlign, h2d.Text.Align );
				if( out != null )
				{
					t.textAlign = out;

				}

				var maxWidth: Float = t.maxWidth > 0 ? t.maxWidth : 0;
				if( IG.wref( ImGui.inputDouble("Max Width",_,1,10,"%.2f"), maxWidth ) )
				{
					if( maxWidth > 0 )
						t.maxWidth = maxWidth
					else
						t.maxWidth = null;

				}


			case "h2d.Bitmap":
				var b : Bitmap = cast obj;
				var newTile = IG.textInput( "Tile", def.props["tile"] );
				if( newTile != null && hxd.Res.loader.exists( newTile ) )
				{
					b.tile = hxd.Res.loader.load( newTile ).toTile();
				}

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && hxd.Res.loader.exists( payload ) )
					{
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
				}

				var height: Float = b.height > 0 ? b.height : 0;
				if( IG.wref( ImGui.inputDouble("Height",_,1,10,"%.2f"), height ) )
				{
					if( height > 0 )
						b.height = height
					else
						b.height = null;
				}

			case "h2d.Flow":
				var t: h2d.Flow = cast obj;


				var layout = IG.combo("Layout", t.layout, h2d.Flow.FlowLayout );
				if( layout != null )
				{
					t.layout = layout;

				}


				var align = IG.combo("Vertical Align", t.verticalAlign, h2d.Flow.FlowAlign );
				if( align != null )
				{
					t.verticalAlign = align;

				}
				align = IG.combo("Horizontal Align", t.horizontalAlign, h2d.Flow.FlowAlign );
				if( align != null )
				{
					t.horizontalAlign = align;
				}

			case "h2d.Mask":
				var t : h2d.Mask = cast obj;

				IG.wref( ImGui.inputInt("Width",_,1,10), t.width );
				IG.wref( ImGui.inputInt("Height",_,1,10), t.height );


			case "h2d.Interactive":
				var t : h2d.Interactive = cast obj;

				IG.wref( ImGui.inputDouble("Width",_,1,10), t.width );
				IG.wref( ImGui.inputDouble("Height",_,1,10), t.height );

				/*
				var cursor = IG.combo("Cursor", t.cursor, hxd.Cursor );
				if( cursor != null )
				{
					t.cursor = cursor;
				}*/

				// But why?
				IG.wref( ImGui.checkbox( "Ellipse", _ ), t.isEllipse );

				var c = Vector.fromColor( t.backgroundColor );
				var color = new hl.NativeArray<Single>(4);
				color[0] = c.r;
				color[1] = c.g;
				color[2] = c.b;
				color[3] = c.a;
				var flags = ImGuiColorEditFlags.AlphaBar | ImGuiColorEditFlags.AlphaPreview
						| ImGuiColorEditFlags.DisplayRGB | ImGuiColorEditFlags.DisplayHex
						| ImGuiColorEditFlags.AlphaPreviewHalf;
				if( IG.wref( ImGui.colorPicker4( "Color", _, flags), color ) )
				{
					c.set(color[0], color[1], color[2], color[3] );
					t.backgroundColor = c.toColor();
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
			case "h2d.Mask": return "\uf125";
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
			case "h2d.Mask":
				def.props["width"] = 100;
				def.props["height"] = 100;
		}

		parent.children.push(def);

		updateScene();
	}
}

#end