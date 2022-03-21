
package cerastes.tools;

import hxd.Key;
import haxe.display.Protocol.HaxeResponseErrorData;
import hxd.res.Font;
import hxd.res.BitmapFont;
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
import cerastes.fmt.CUIResource.CUIObject;
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
	var viewportScale: Int;

	var preview: h2d.Scene;
	var previewRoot: Object;
	var sceneRT: Texture;
	var sceneRTId: Int;

	var fileName: String = null;
	var rootDef: CUIObject;

	var treeIdx = 0;
	var selectedInspectorTree: CUIObject;
	var selectedDragDrop: CUIObject;

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
	var hasFocus = false;

	var zoom: Int = 1;

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;
		viewportScale = viewportDimensions.scale;
		preview = new h2d.Scene();
		preview.scaleMode = Fixed(viewportWidth,viewportHeight, 1, Left, Top);
		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		selectedItemBorder = new h2d.Graphics();
		cursor = new h2d.Graphics();


		rootDef = {
			type: "h2d.Object",
			name:"root",
			children: []
		};

		previewRoot = new Object(preview);
		cerastes.fmt.CUIResource.recursiveCreateObjects(rootDef, previewRoot);

	}

	public function openFile( f: String )
	{
		fileName = f;

		try
		{
			var res = new cerastes.fmt.CUIResource( hxd.Res.loader.load(fileName).entry );
			var data = res.getData();
			rootDef = data.root;
			CUIResource.recursiveUpgradeObjects( rootDef, data.version  );
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

	function updateDef( o: CUIObject )
	{
		var e = previewRoot.getObjectByName( o.name );
		cerastes.fmt.CUIResource.updateObject(o, e);
		@:privateAccess e.onContentChanged();
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
			var types = ["h2d.Object", "h2d.Text", "h2d.Bitmap", "h2d.Flow", "h2d.Mask", "h2d.ScaleGrid", "cerastes.ui.Button", "cerastes.ui.AdvancedText"];

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


		ImGui.beginChild("uie_inspector_tree",null, false, ImGuiWindowFlags.AlwaysAutoResize);

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
				if ( fileName != null && ImGui.menuItem("Save", "Ctrl+S"))
				{
					CUIResource.writeObject(rootDef,preview,fileName);
				}
				if (ImGui.menuItem("Save As..."))
				{
					var newFile = UI.saveFile({
						title:"Save As...",
						filters:[
						{name:"Cerastes UI files", exts:["ui"]}
						]
					});
					if( newFile != null )
					{
						fileName = Utils.toLocalFile( newFile );
						CUIResource.writeObject(rootDef, preview,newFile);

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

		ImGui.setNextWindowSize({x: viewportWidth * 2, y: viewportHeight * 1.6}, ImGuiCond.Once);
		ImGui.begin('\uf108 UI Editor##${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		// Selected Border stuff
		processSelection();

		inspectorColumn();

		//ImGui.sameLine();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );


		ImGui.image(sceneRT, { x: viewportWidth * zoom, y: viewportHeight * zoom }, null, null, null, {x: 1, y: 1, z:1, w:1} );

		if( ImGui.isWindowHovered() )
		{
			var startPos: ImVec2 = ImGui.getCursorScreenPos();
			var mousePos: ImVec2 = ImGui.getMousePos();

			mouseScenePos = {x: ( mousePos.x - startPos.x) / zoom, y: ( mousePos.y - startPos.y ) / zoom };
			// Should use imgui events here for consistency but GetIO isn't exposed to hl sooo...
			if (Key.isPressed(Key.MOUSE_WHEEL_DOWN))
			{
				zoom--;
				if( zoom <= 0 )
					zoom = 1;
			}
			if (Key.isPressed(Key.MOUSE_WHEEL_UP))
			{
				zoom++;
				if( zoom > 20 )
					zoom = 20;
			}


		}
		else
		{
			mouseScenePos = null;
		}

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


	}

	function processSelection()
	{
		selectedItemBorder.clear();
		if( selectedInspectorTree == null )
			return;

		var o = preview.getObjectByName( selectedInspectorTree.name );
		if( o == null )
			return;

		var type = Type.getClassName( Type.getClass( o ) );

		var bounds = o.getBounds();

		var colBounds = 0x6666ff;
		var colMins = 0x66ff66;
		var colMaxs = 0xff6666;

		if( bounds.getSize().x > 0 || bounds.getSize().y > 0 )
		{
			selectedItemBorder.lineStyle(4,colBounds, 0.5);
			selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, bounds.width, bounds.height);

			var flow: CUIFlow = Std.downcast( selectedInspectorTree, CUIFlow );
			if( flow != null )
			{
				selectedItemBorder.lineStyle(4,colMins, 0.5);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, flow.minWidth, flow.minHeight);
				selectedItemBorder.lineStyle(4,colMaxs, 0.5);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, flow.maxWidth, flow.maxHeight);
			}
			var text: CUIText = Std.downcast( selectedInspectorTree, CUIText );
			if( text != null )
			{
				var t: h2d.Text = cast o;
				selectedItemBorder.lineStyle(4,colMaxs, 0.5);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, text.maxWidth, t.textHeight);
			}

		}
		else
		{
			selectedItemBorder.lineStyle(4,colBounds, 0.5);
			selectedItemBorder.drawRect(bounds.x, bounds.y, 1, 1);
		}


	}

	function processSceneMouse( delta: Float )
	{
		if( mouseScenePos == null )
			return;

		var isMouseOverViewport = mouseScenePos.x > 0 && mouseScenePos.x < viewportWidth && mouseScenePos.y > 0 && mouseScenePos.y < viewportHeight;
		if( isMouseOverViewport && ImGui.isMouseClicked(ImGuiMouseButton.Left) && previewRoot != null )
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
			if( o == null )
			{
				Utils.warning("Lost selected object...");
				selectedInspectorTree = null;
				return;
			}
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

	function getElementDefByName( name: String, def: CUIObject ) : CUIObject
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
		var dd: CUIObject = {
			type:"dummy",
			name:"dummy",
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

	function populateChildren( def: CUIObject )
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

	function getDefByName(name: String, def: CUIObject = null )
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

	function getDefParent(find: CUIObject, ?def: CUIObject = null )
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

		var oldW = e.width;
		var oldH = e.height;

		e.pushTarget( sceneRT );
		e.clear(0,1);

		@:privateAccess// @:bypassAccessor
		{
			e.width = sceneRT.width;
			e.height = sceneRT.height;
			preview.checkResize();
			preview.render(e);
			e.width = oldW;
			e.height = oldH;
		}

		e.popTarget();
	}

	function populateEditor()
	{
		var def = selectedInspectorTree;
		ImGui.pushFont( ImguiToolManager.headingFont );
		ImGui.text(def.type);
		ImGui.popFont();



		var obj = preview.getObjectByName(def.name);
		if( obj == null )
			return;

		var newName = IG.textInput( "ID", def.name );
		if( newName != null && newName.length > 0 )
		{
			var other = preview.getObjectByName(newName);
			if( other == null )
			{
				def.name = newName;
				updateScene();
			}
		}

		ImGui.pushID(def.name);

		ImGui.separator();


		populateEditorFields(obj, def, def.type);

		var s =  Type.getSuperClass( Type.getClass( obj ) );
		while( s != null )
		{
			populateEditorFields( obj, def, Type.getClassName(s) );
			s = Type.getSuperClass( s );
		}

		updateDef( def );

		ImGui.popID();
	}

	//
	// Field related functions
	//
	function populateEditorFields(obj: Object, def: CUIObject, type: String )
	{

		if (!ImGui.collapsingHeader(type, ImGuiTreeNodeFlags.DefaultOpen ))
			return;

		switch( type )
		{
			case "h2d.Object":
				IG.wref( ImGui.inputDouble("X",_,1,10,"%.2f"), def.x );
				IG.wref( ImGui.inputDouble("Y",_,1,10,"%.2f"), def.y );
				var single: Single = def.rotation;
				if( IG.wref( ImGui.sliderAngle("Rotation", _), single ) )
					def.rotation = single;

				IG.wref( ImGui.inputDouble("Scale X",_,1,10,"%.2f"), def.scaleX );
				IG.wref( ImGui.inputDouble("Scale Y",_,1,10,"%.2f"), def.scaleY );

				IG.wref( ImGui.checkbox( "Visible", _ ), def.visible );



			case "h2d.Drawable":
				var d : CUIDrawable = cast def;
				// Color
				var nc = IG.inputColorInt( d.color );
				if( nc != -1 )
					d.color = nc;

			case "h2d.Text":
				var d: CUIText = cast def;

				var val = IG.textInputMultiline("Text", d.text, null, ImGuiInputTextFlags.Multiline);
				if( val != null )
					d.text = val;

				var newFont = IG.textInput( "Font", d.font );
				if( newFont != null && hxd.Res.loader.exists( newFont ) )
					d.font = newFont;

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && hxd.Res.loader.exists( payload ) )
						d.font = payload;

					ImGui.endDragDropTarget();
				}

				if( StringTools.endsWith( d.font, ".msdf.fnt" ) )
				{
					IG.wref( ImGui.inputInt( "Font Size", _ ), d.sdfSize );
					IG.wref( ImGui.inputDouble( "Alpha Cutoff", _ ), d.sdfAlpha );
					IG.wref( ImGui.inputDouble( "Smoothing", _ ), d.sdfSmoothing );
				}

				var out = IG.combo("Text Align", d.textAlign, h2d.Text.Align );
				if( out != null )
					d.textAlign = out;


				var maxWidth: Float = d.maxWidth > 0 ? d.maxWidth : 0;
				if( IG.wref( ImGui.inputDouble("Max Width",_,1,10,"%.2f"), maxWidth ) )
				{
					if( maxWidth > 0 )
						d.maxWidth = maxWidth;
					else
						d.maxWidth = -1;

				}

			case "cerastes.ui.AdvancedText":

			case "h2d.Bitmap":
				var d: CUIBitmap = cast def;


				var newTile = IG.inputTile( "Tile", d.tile );
				if( newTile != null )
					d.tile = newTile;

				var width: Float = d.width > 0 ? d.width : 0;
				if( IG.wref( ImGui.inputDouble("Width",_,1,10,"%.2f"), width ) )
				{
					if( width > 0 )
						d.width = width;
					else
						d.width = -1;
				}

				var height: Float = d.height > 0 ? d.height : 0;
				if( IG.wref( ImGui.inputDouble("Height",_,1,10,"%.2f"), height ) )
				{
					if( height > 0 )
						d.height = height;
					else
						d.height = -1;
				}

			case "h2d.Flow":
				var d: CUIFlow = cast def;


				var layout = IG.combo("Layout", d.layout, h2d.Flow.FlowLayout );
				if( layout != null )
					d.layout = layout;

				IG.wref( ImGui.checkbox( "Wrap", _ ), d.multiline );


				var align = IG.combo("Vertical Align", d.verticalAlign, h2d.Flow.FlowAlign );
				if( align != null )
					d.verticalAlign = align;

				align = IG.combo("Horizontal Align", d.horizontalAlign, h2d.Flow.FlowAlign );
				if( align != null )
					d.horizontalAlign = align;

				var overflow = IG.combo("Overflow", d.overflow, h2d.Flow.FlowOverflow );
				if( overflow != null )
					d.overflow = overflow;

				var minW: Int = d.minWidth != -1 ? cast d.minWidth : 0;
				var minH: Int = d.minHeight != -1 ? cast d.minHeight : 0;

				if( IG.wref( ImGui.inputInt("Min Width",_,1,10), minW ) )
					d.minWidth = minW;

				if( IG.wref( ImGui.inputInt("Min Height",_,1,10), minH ) )
					d.minHeight = minH;

				var maxW: Int = d.maxWidth != -1 ? cast d.maxWidth : 0;
				var maxH: Int = d.maxHeight != -1 ? cast d.maxHeight : 0;

				if( IG.wref( ImGui.inputInt("Max Width",_,1,10), maxW ) )
					d.maxWidth = maxW;

				if( IG.wref( ImGui.inputInt("Max Height",_,1,10), maxH ) )
					d.maxHeight = maxH;


				IG.wref( ImGui.inputInt("Vertical Spacing",_,1,10), d.verticalSpacing );
				IG.wref( ImGui.inputInt("Horizontal Spacing",_,1,10), d.horizontalSpacing );

				var newTile = IG.inputTile( "Background Tile", d.backgroundTile );
				if( newTile != null )
					d.backgroundTile = newTile;

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Setting a background tile will create an ScaleGrid background which uses the borderWidth / borderHeigh values for its borders.");
					ImGui.endTooltip();
				}


				IG.wref( ImGui.inputInt("Border Width",_,1,10), d.borderWidth );
				IG.wref( ImGui.inputInt("Border Height",_,1,10), d.borderHeight );
/*
			case "h2d.Mask":
				var t : h2d.Mask = cast obj;

				IG.wref( ImGui.inputInt("Width",_,1,10), t.width );
				IG.wref( ImGui.inputInt("Height",_,1,10), t.height );

				IG.wref( ImGui.inputDouble("Scroll X",_,1,10,"%.2f"), t.scrollX );
				IG.wref( ImGui.inputDouble("Scroll Y",_,1,10,"%.2f"), t.scrollY );
*/


			case "h2d.ScaleGrid":
				var d : CUIScaleGrid = cast def;


				IG.wref( ImGui.inputDouble("Width",_,1,10), d.width );
				IG.wref( ImGui.inputDouble("Height",_,1,10), d.height );

				IG.wref( ImGui.inputInt("Border Top",_,1,10), d.borderTop );
				IG.wref( ImGui.inputInt("Border Bottom",_,1,10), d.borderBottom );
				IG.wref( ImGui.inputInt("Border Left",_,1,10), d.borderLeft );
				IG.wref( ImGui.inputInt("Border Right",_,1,10), d.borderRight );

				IG.wref( ImGui.inputInt("Border Width",_,1,10), d.borderWidth );
				IG.wref( ImGui.inputInt("Border Height",_,1,10), d.borderHeight );

				var newTile = IG.inputTile( "Background Tile", d.contentTile );
				if( newTile != null )
					d.contentTile = newTile;

			case "cerastes.ui.Button":
				var d : CUIButton = cast def;


				var newTile = IG.inputTile( "Default Tile", d.defaultTile );
				if( newTile != null )
					d.defaultTile = newTile;

				var nc = IG.inputColorHVec( d.defaultColor, "defaultColor" );
				if( nc != null )
					d.defaultColor = nc;

				ImGui.text("Visited Color");
				var nc = IG.inputColorHVec( d.visitedColor, "visitedColor" );
				if( nc != null )
					d.visitedColor = nc;

				ImGui.text("Disabled Color");
				var nc = IG.inputColorHVec( d.disabledColor, "disabledColor" );
				if( nc != null )
					d.disabledColor = nc;

				var newTile = IG.inputTile( "Hover Tile", d.hoverTile );
				if( newTile != null )
					d.hoverTile = newTile;

				var nc = IG.inputColorHVec( d.hoverColor, "hoverColor" );
				if( nc != null )
					d.hoverColor = nc;

				var newTile = IG.inputTile( "Press Tile", d.pressTile );
				if( newTile != null )
					d.pressTile = newTile;

				var nc = IG.inputColorHVec( d.pressColor, "pressColor" );
				if( nc != null )
					d.pressColor = nc;

				var orientation = IG.combo("Orientation", d.orientation, cerastes.ui.Button.Orientation );
				if( orientation != null )
				{
					d.orientation = orientation;
				}



			case "h2d.Interactive":
				var d : CUIInteractive = cast def;

				IG.wref( ImGui.inputDouble("Width",_,1,10), d.width );
				IG.wref( ImGui.inputDouble("Height",_,1,10), d.height );

				/*
				var cursor = IG.combo("Cursor", t.cursor, hxd.Cursor );
				if( cursor != null )
				{
					t.cursor = cursor;
				}*/
/*
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

*/



		}

		ImGui.separator();
	}
/*
	function loadFont(text: h2d.Text, def: CUIElementDef )
	{
		var isSDF = StringTools.endsWith( def.props["font"], ".msdf.fnt" );

		if( !isSDF )
		{
			text.font = hxd.Res.loader.loadCache( def.props["font"], BitmapFont).toFont();
		}
		else
		{
			if( !def.props.exists("sdf_size") )
			{
				// Defaults
				def.props["sdf_size"] = 14;
				def.props["sdf_alpha"] = 0.5;
				def.props["sdf_smoothing"] = 32;
			}
			text.font = hxd.Res.loader.loadCache( def.props["font"], BitmapFont).toSdfFont(def.props["sdf_size"],4,def.props["sdf_alpha"],1/def.props["sdf_smoothing"]);
		}
	}
*/
	function getNameForType( type: String )
	{
		switch(type)
		{
			default:
				return type.substr( type.lastIndexOf(".") +1 );
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
			case "h2d.ScaleGrid": return "\uf00a";
			case "cerastes.ui.Button": return "\uf04d";
			case "cerastes.ui.AdvancedText": return "\uf033";
			default: return "";
		}
	}

	function addItem(type: String)
	{
		var parent = selectedInspectorTree != null ? selectedInspectorTree : rootDef;
		// Populate enough values to allow object creation
		switch( type )
		{
			case "h2d.Object":

				var def: CUIObject = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);

			case "h2d.Text":
				var def: CUIText = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);

			case "cerastes.ui.AdvancedText":
				var def: CUIAdvancedText = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);

			case "h2d.Bitmap":
				var def: CUIBitmap = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);
			case "h2d.Flow":
				var def: CUIFlow = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);

			case "h2d.ScaleGrid":
				var def: CUIScaleGrid = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);

			case "h2d.Mask":
				var def: CUIMask = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);

			case "cerastes.ui.Button":
				var def: CUIButton = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				parent.children.push(def);
		}





		updateScene();
	}
}

#end