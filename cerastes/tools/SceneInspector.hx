
package cerastes.tools;

#if hlimgui
import h3d.Engine;
import hxd.Key;
import h2d.Tile;
import cerastes.macros.Metrics;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTool.ImGuiToolManager;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import imgui.ImGuiMacro.wref;

@:keep
class SceneInspector extends ImguiTool
{

	var dockCond = ImGuiCond.Appearing;
	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	//var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;
	//var dockspaceIdBottom: ImGuiID;

	var desiredScale = -1;
	var currentScale = -1;

	var selected2d: h2d.Object = null;

	public override function getName() { return "\uf201 Inspector"; }

	override public function update( delta: Float )
	{
		Metrics.begin();

		ImGui.begin("\uf201 Scene Inspector", null, ImGuiWindowFlags.MenuBar);
		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );
		ImGui.end();

		inspectorColumn();
		propertiesColumn();

		Metrics.end();
	}


	function menuBar()
	{

		handleShortcuts();


		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("View", true) )
			{
				var scale1Checked = currentScale == 1;
				var scale2Checked = currentScale == 2;
				var scale4Checked = currentScale == 4;

				var changed = false;
				scale1Checked = ImGui.menuItem("Scene 1x", null, scale1Checked );
				scale2Checked = ImGui.menuItem("Scene 2x", null, scale2Checked );
				scale4Checked = ImGui.menuItem("Scene 4x", null, scale4Checked );

				if( scale1Checked ) desiredScale = 1;
				if( scale2Checked ) desiredScale = 2;
				if( scale4Checked ) desiredScale = 4;

				updateScaleRatio();


				//ImGui.separator();
				if (ImGui.menuItem("Reset docking"))
				{
					dockCond = ImGuiCond.Always;
				}
				ImGui.endMenu();
			}
			ImGui.endMenuBar();
		}
	}
	function handleShortcuts()
	{
		var io = ImGui.getIO();
		if( ImGui.isWindowFocused( ImGuiFocusedFlags.RootAndChildWindows ) )
		{
			if( io.KeyCtrl )
			{
				//if( ImGui.isKeyPressed( 'S'.imKey() ) )
				//	save();
			}
		}
	}

	function updateScaleRatio()
	{
		if( cerastes.App.currentScene != null )
		{
			var window = hxd.Window.getInstance();
			var windowHeight = window.height;
			currentScale = 1;
			switch( cerastes.App.currentScene.s2d.scaleMode )
			{
				case Fixed(width, height, zoom, horizontalAlign, verticalAlign):
					currentScale = Math.round( windowHeight / height );
				case Stretch(width, height):
					currentScale = Math.round( windowHeight / height );
				default:
					Utils.warning('Unsupported scaleMode ${cerastes.App.currentScene.s2d.scaleMode}');
			}

			if( desiredScale != -1)
			{
				currentScale = desiredScale;
				desiredScale = -1;
				switch( cerastes.App.currentScene.s2d.scaleMode )
				{
					case Fixed(width, height, zoom, horizontalAlign, verticalAlign):
						window.resize(width * currentScale, height * currentScale );
					case Stretch(width, height):
						window.resize(width * currentScale, height * currentScale );
					default:
						Utils.warning('Unsupported scaleMode ${cerastes.App.currentScene.s2d.scaleMode}');
				}
			}
		}
	}


	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = "UIEditorDockspace";

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			//dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut = hl.Ref.make( dockspaceId );

			//dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.30, null, idOut);
			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.50, null, idOut);
			//dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.30, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}

	function inspectorColumn()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('2d Inspector##${windowID()}') )
		{
			handleShortcuts();

			if( ImGui.beginChild("2di_inspector_tree",null, false, ImGuiWindowFlags.AlwaysAutoResize) )
			{

				if( cerastes.App.currentScene != null )
					populateChildren( cerastes.App.currentScene.s2d );

				ImGui.endChild();
			}



			//ImGui.endChild();
		}
		ImGui.end();
	}

	function propertiesColumn()
	{
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		if( ImGui.begin('Properties##${windowID()}') )
		{
			handleShortcuts();
			if( selected2d != null )
			{
				populate2dProperties( selected2d, Type.getClassName( Type.getClass( selected2d ) ) );
				var s =  Type.getSuperClass( Type.getClass( selected2d ) );
				while( s != null )
				{
					populate2dProperties( selected2d, Type.getClassName(s) );
					s = Type.getSuperClass( s );
				}
			}
			else
			{
				ImGui.text("No item selected");
			}




			//ImGui.endChild();
		}
		ImGui.end();
	}

	function populate2dProperties(obj: h2d.Object, type: String )
	{
		switch( type )
		{
			case "h2d.Object":
				if (!ImGui.collapsingHeader(type, ImGuiTreeNodeFlags.DefaultOpen ))
					return;

				var o: h2d.Object = cast obj;
				if( ImGui.inputDouble("X", o.x, 1, 10, "%.2f" ) ) @:privateAccess o.posChanged = true;
				if( ImGui.inputDouble("Y", o.y, 1, 10, "%.2f" ) ) @:privateAccess o.posChanged = true;

				if( ImGui.inputDouble("scaleX", o.scaleX, 1, 10, "%.2f" ) ) @:privateAccess o.posChanged = true;
				if( ImGui.inputDouble("scaleY", o.scaleY, 1, 10, "%.2f" ) ) @:privateAccess o.posChanged = true;

				ImGui.checkbox("Visible", o.visible );

				ImGui.inputDouble("Alpha", o.alpha);

			case "cerastes.ui.UIEntity":
				var o: cerastes.ui.UIEntity = cast obj;
				o.sceneInspector(o);

			default:
				ImGui.text( type );
		}
	}

	function populateChildren( o: h2d.Object )
	{
		for( idx in 0 ... o.numChildren )
		{
			var c = o.getChildAt(idx);
			if( c == null )
				continue;

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			if( c.numChildren == 0)
				flags |= ImGuiTreeNodeFlags.Leaf;

			if( selected2d == c )
				flags |= ImGuiTreeNodeFlags.Selected;

			var type = Type.getClassName( Type.getClass( c ) );

			var name = c.name  != null ? c.name : '${type}/{$idx}';
			//name = '${getIconForType( c.type )} ${name}';

			var isOpen = ImGui.treeNodeEx( name, flags );

			if( ImGui.isItemClicked() )
			{
				selected2d = c;
			}

			if( ImGui.isItemHovered() )
			{
				var bounds = c.getBounds();
				cerastes.c2d.DebugDraw.bounds(bounds, 0xFF0000, 0, 0.75, 1);
			}


			/*
			if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
				ImGui.openPopup('${c.name}_2di_context');


			if( ImGui.beginPopup('${c.name}_2di_popup') )
			{
				ImGui.endPopup();
			}


			// Right click context menu
			if( ImGui.beginPopup('${c.name}_uie_context') )
			{
				ImGui.endPopup();
			}

			*/

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

}

#end