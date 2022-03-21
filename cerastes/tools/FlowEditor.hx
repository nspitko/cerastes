
package cerastes.tools;
import cerastes.flow.Flow.FlowComment;
import haxe.rtti.Meta;
import haxe.rtti.Rtti;
import cerastes.flow.Flow.FlowNode;
import cerastes.tools.ImguiTool.ImguiToolManager;
#if hlimgui
import cerastes.flow.Flow.SceneNode;
import cerastes.tools.ImguiTools.ComboFilterState;
import cerastes.tools.ImguiTools.ImGuiTools;
import cerastes.flow.Flow.LabelNode;

import hl.Ref;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import imgui.NodeEditor;
import hl.UI;

import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImGuiNodes;

enum FlowEditorMode {
	Select;
	AddNode;
	AddComment;
}

@:keep
@:access(cerastes.tools.Node)
class FlowEditor extends ImguiTool
{

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var nodes : ImGuiNodes;

	var fileName: String = null;

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var mode: FlowEditorMode = Select;

	public function new()
	{
		nodes = new ImGuiNodes();

		// TEST
		var t: LabelNode = {};
		nodes.addNode(t, 20, 20);
		var t: LabelNode = {};
		nodes.addNode(t, 50, 200);

		var c: FlowComment = {
			comment:"Test comment",
		};

		c.commentSize.x = 100;
		c.commentSize.y = 100;

		nodes.registerNode("Label", LabelNode);
		nodes.registerNode("Scene", SceneNode);

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		nodes.addNode(c, 5,5);
	}



	override public function update( delta: Float )
	{

		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: windowWidth, y: windowHeight}, ImGuiCond.Once);
		ImGui.begin("\uf1e0 Flow Editor", isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);


		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('View##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );


		nodes.render();

		ImGui.end();

		commandPalette();
		inspector();

	}




	function commandPalette()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Command Palette##${windowID()}');

		ImGui.text("HI");

		if( ImGui.button("Select") ) mode = Select;
		if( ImGui.button("Add Node") ) mode = AddNode;
		if( ImGui.button("Add Comment") ) mode = AddComment;



		ImGui.end();

	}


	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');

		var node: FlowNode = Std.downcast( nodes.getSelectedNode(), FlowNode );
		if( node != null )
		{
			ImGui.pushID( '${node.id}' );
			ImGui.pushFont( ImguiToolManager.headingFont );
			ImGui.text( node.def.name );
			ImGui.popFont();

			var meta: haxe.DynamicAccess<Dynamic> = Meta.getFields( Type.getClass( node ) );
			for( field => data in meta )
			{
				var metadata: haxe.DynamicAccess<Dynamic> = data;
				if( metadata.exists("editor") )
				{
					var args = metadata.get("editor");
					switch( args[1] )
					{
						case "String":
							var val = Reflect.getProperty(node,field);
							var ret = IG.textInput(args[0],val);
							if( ret != null )
								Reflect.setField( node, field, ret );
						default:
							ImGui.text('UNHANDLED!!! ${field} -> ${args[0]} of type ${args[1]}');
					}

				}
			}

			ImGui.popID();
		}
		else
		{
			ImGui.text("No node selected");
		}




		ImGui.end();

	}


	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = "FlowEditorDockspace";

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

	function menuBar()
	{
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( fileName != null && ImGui.menuItem("Save", "Ctrl+S"))
				{
					//CUIResource.writeObject(rootDef,preview,fileName);
					Utils.error("STUB!");
				}
				if (ImGui.menuItem("Save As..."))
				{
					var newFile = UI.saveFile({
						title:"Save As...",
						filters:[
						{name:"Cerastes flow files", exts:["flow"]}
						]
					});
					if( newFile != null )
					{
						fileName = Utils.toLocalFile( newFile );
						//CUIResource.writeObject(rootDef, preview,newFile);
						Utils.error("STUB!");

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

	inline function windowID()
	{
		return 'flow${fileName}';
	}

}

#end