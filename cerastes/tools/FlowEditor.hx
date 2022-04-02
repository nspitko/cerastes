
package cerastes.tools;
#if ( hlimgui )
import hxd.Key;
import sys.io.File;
import game.GameState;
import cerastes.data.Nodes.Link;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
import cerastes.flow.Flow;
import haxe.rtti.Meta;
import cerastes.tools.ImguiTool;
import cerastes.tools.ImguiTools;

import hl.Ref;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
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
@:access(cerastes.data.Node)
@multiInstance(true)
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

	var context = new FlowContext(null);

	var selectedNode: FlowNode;

	public function new()
	{
		nodes = new ImGuiNodes();
		nodes.createLink = (sourceId: PinId, destId: PinId, id: Int)  -> { var l: FlowLink = { sourceId: sourceId, destId: destId, id: id }; return l; };

		// TEST
		var t: EntryNode = {};
		nodes.addNode(t, 25, 25);

		for( label => cls in cerastes.Config.flowEditorNodes )
		{
			nodes.registerNode(label, cast cls);
		}

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		//openFile( "data/nested_test.flow" );
	}



	override public function update( delta: Float )
	{

		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		if( forceFocus )
		{
			forceFocus = false;
			ImGui.setNextWindowFocus();
		}
		ImGui.setNextWindowSize({x: windowWidth * 0.7, y: windowHeight * 0.7}, ImGuiCond.Once);
		ImGui.begin('\uf1e0 Flow Editor ${fileName != null ? fileName : ""}###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('View##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		nodes.render();
		processMouse();


		ImGui.end();

		commandPalette();
		inspector();

		if( selectedNode != null )
		{
			selectedNode.updatePreviewWindow( windowID() );
		}


		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}


	}

	var mouseStart: ImVec2;
	function processMouse()
	{
		switch( mode )
		{
			case AddComment:
				if( ImGui.isMouseDown(ImGuiMouseButton.Left ) && mouseStart == null )
				{
					mouseStart = ImGui.getMousePos();
				}

				if( ImGui.isMouseReleased( ImGuiMouseButton.Left ) && mouseStart != null )
				{

					var startPos:ImVec2 = NodeEditor.screenToCanvas(mouseStart);
					var endPos:ImVec2 = NodeEditor.screenToCanvas(ImGui.getMousePos());

					var comment: FlowComment = {
						comment: "",
						commentWidth: endPos.x - startPos.x,
						commentHeight: endPos.y - startPos.y,

					};

					nodes.addNode( comment, startPos.x, startPos.y );

					mouseStart = null;
					mode = Select;
				}

			case Select:
			case AddNode:
		}
	}




	function commandPalette()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Command Palette##${windowID()}');
		handleShortcuts();

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
		handleShortcuts();

		var node: FlowNode = Std.downcast( nodes.getSelectedNode(), FlowNode );
		var link: FlowLink = Std.downcast( nodes.getSelectedLink( ), FlowLink );
		if( node != null )
		{
			node.renderProps();
			selectedNode = node;
		}
		else if( link != null )
		{
			var n = 0;
			if( link.conditions != null )
				n = link.conditions.length;

			var idToRemove = -1;

			var i = 0;
			if( link.conditions != null && link.conditions.length > 0 )
			{
				for( i in 0 ... link.conditions.length )
				{
					var c = link.conditions[i];
					var newVal = IG.textInput('##${i}', c );
					if( newVal != null )
						link.conditions[i] = newVal;

					ImGui.sameLine();
					if( ImGui.button("\uf55a"))
						idToRemove = i;

					runChecker( link.conditions[i] );
				}

				i = link.conditions.length;
			}

			if( idToRemove != -1 )
			{
				link.conditions.splice(idToRemove,1);
				if( link.conditions.length == 0 )
				{
					link.conditions = null;
				}
				decorateLink( link );
			}

			if( ImGui.button('\u002b') )
			{
				if( link.conditions != null )
					link.conditions.push('');
				else
				{
					link.conditions = [''];
				}

				decorateLink( link );
			}

		}
		else
		{
			ImGui.text("No item selected");
		}




		ImGui.end();

	}

	//static var checker: Checker;

	function decorateLink( link: FlowLink )
	{
		if( link.conditions != null && link.conditions.length > 0 )
		{
			link.color = { x: 0.9, y: 0.95, z: 0.2, w: 1.0 };
			link.thickness = 3.0;
		}
	}

	function runChecker( val: String )
	{
/*
		if( checker == null )
		{
			checker = new Checker();
			var types = new CheckerTypes();
			types.addXmlApi(Xml.parse( File.getContent("api.xml") ).firstElement()); // `xml` = api.xml contents as String
			checker.types = types;

			for( k => v in context.globals )
			{
				trace('${k} -> ${v}');
				var t = types.resolve( v );
				if( t == null )
				{
					for( t => v in @:privateAccess types.types )
					{
						if( t.indexOf("changeScene") != -1 )
							trace('FOUND IT!! ${t}');
					}
				}
				Utils.assert( t != null, 'Unable to resolve ${k} (${v}) for hscript checker. Type checking may fail!!');
				checker.setGlobal(k, t);
			}
		}
*/
		if( ImGui.isItemFocused() )
		{
			try
			{
				var expr = context.parser.parseString(val);
/*
				try
				{
					checker.check( expr );
				}
				catch( e )
				{
					ImGui.textColored( {x: 1.0, y: 0.3, z: 0.3, w: 1.0}, e.message );
				}
*/
			}
			catch( e )
			{
				ImGui.textColored( {x: 1.0, y: 0.3, z: 0.3, w: 1.0}, e.message );
			}



		}
	}


	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'FlowEditorDockspace${windowID()}';

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

	public function openFile( fileName: String )
	{
		var res = hxd.Res.loader.load(fileName);
		var obj: FlowFile = CDParser.parse( res.toText(), FlowFile );
		nodes.nodes = cast obj.nodes;
		nodes.links = cast obj.links;

		this.fileName = fileName;

		// Have editor rebuild it's internal state
		nodes.regenerateData();

		// Decorate links
		for( link in nodes.links )
			decorateLink( cast link );

	}

	function saveAs()
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

			var obj: FlowFile = {
				nodes: cast nodes.nodes,
				links: cast nodes.links
			};

			sys.io.File.saveContent( Utils.fixWritePath(fileName,"flow"), CDPrinter.print( obj ) );

			cerastes.tools.AssetBrowser.needsReload = true;
		}
	}

	function save()
	{
		if( fileName == null )
		{
			saveAs();
			return;
		}
		var obj: FlowFile = {
			nodes: cast nodes.nodes,
			links: cast nodes.links
		};

		var file = Utils.fixWritePath(fileName,"flow");


		sys.io.File.saveContent( file, CDPrinter.print( obj ) );

		ImguiToolManager.showPopup("File saved",'Wrote ${file} successfully.', Info);
	}

	function handleShortcuts()
	{
		if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}
	}

	function menuBar()
	{

		handleShortcuts();
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( fileName != null && ImGui.menuItem("Save", "CTRL+S"))
				{
					save();
				}
				if (ImGui.menuItem("Save As..."))
				{
					saveAs();
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

		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( fileName != null && ImGui.menuItem("Save", "Ctrl+S"))
				{
					save();
				}
				if (ImGui.menuItem("Save As..."))
				{
					saveAs();
				}
				ImGui.separator();
				if( ImGui.menuItem("Load"))
				{
					Utils.error("STUB!");
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

	public override inline function windowID()
	{
		return 'flow${fileName != null ? fileName : ""+toolId}';
	}

	public override function render( e: h3d.Engine )
	{

		if( selectedNode != null )
		{
			selectedNode.renderPreviewWindow(e);
		}
	}

}

#end