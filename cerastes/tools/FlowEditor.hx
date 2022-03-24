
package cerastes.tools;
import game.GameState;
import hscript.Checker;
import cerastes.data.Nodes.Link;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;
#if hlimgui
import cerastes.flow.Flow;
import haxe.rtti.Meta;
import haxe.rtti.Rtti;
import cerastes.tools.ImguiTool.ImguiToolManager;
import cerastes.tools.ImguiTools.ComboFilterState;
import cerastes.tools.ImguiTools.ImGuiTools;

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

		openFile( "data/nested_test.flow" );
	}



	override public function update( delta: Float )
	{

		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: windowWidth * 0.7, y: windowHeight * 0.7}, ImGuiCond.Once);
		ImGui.begin('\uf1e0 Flow Editor ${fileName}##${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);


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


		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}


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
		var link: FlowLink = Std.downcast( nodes.getSelectedLink( ), FlowLink );
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

						case "StringMultiline":
							var val = Reflect.getProperty(node,field);
							var ret = IG.textInputMultiline(args[0],val,{x: -1, y: 300 * Utils.getDPIScaleFactor()},0,1024*8);
							if( ret != null )
								Reflect.setField( node, field, ret );

						case "File":
							var val = Reflect.getProperty(node,field);
							var ret = IG.textInput(args[0],val);
							if( ret != null )
								Reflect.setField( node, field, ret );

							if( ImGui.beginDragDropTarget( ) )
							{
								var payload = ImGui.acceptDragDropPayloadString("asset_name");
								if( payload != null && StringTools.endsWith(payload, "flow") )
								{
									Reflect.setField( node, field, payload );
								}
							}


							if( ImGui.button("Select...") )
							{
								var file = UI.saveFile({
									title:"Select file",
									filters:[
									{name:"Cerastes flow files", exts:["flow"]},
									],
									filterIndex: 0
								});
								if( file != null )
									Reflect.setField( node, field, file );
							}

						case "ComboString":
							var val = Reflect.getProperty(node,field);
							var opts = node.getOptions( field );
							var idx = opts.indexOf( val );
							if( ImGui.beginCombo( args[0], val ) )
							{
								for( opt in opts )
								{
									if( ImGui.selectable( opt, opt == val ) )
										Reflect.setField( node, field, opt );
								}
								ImGui.endCombo();
							}


						default:
							ImGui.text('UNHANDLED!!! ${field} -> ${args[0]} of type ${args[1]}');
					}

				}
			}

			ImGui.popID();
		}
		else if( link != null )
		{
			var i = 0;
			if( link.conditions != null && link.conditions.length > 0 )
			{
				for( i in 0 ... link.conditions.length )
				{
					var c = link.conditions[i];
					var newVal = IG.textInput('Condition ${i}', c );
					if( newVal != null )
						link.conditions[i] = newVal;

					runChecker( link.conditions[i] );
				}

				i = link.conditions.length;
			}

			var newVal = IG.textInput('Condition ${i}', "" );
			if( newVal != null )
			{
				if( link.conditions == null )
					link.conditions = [ newVal ];
				else
					link.conditions.push( newVal );

				link.color = { x: 0.9, y: 0.95, z: 0.2, w: 1.0 };
				link.thickness = 3.0;
			}
			if( newVal != null )
				runChecker( newVal );
		}
		else
		{
			ImGui.text("No item selected");
		}




		ImGui.end();

	}

	function runChecker( val: String )
	{
		if( ImGui.isItemFocused() )
		{
			try
			{
				context.parser.parseString(val);
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

	public function openFile( fileName: String )
	{
		var res = hxd.Res.loader.load(fileName);
		var obj: FlowFile = CDParser.parse( res.toText(), FlowFile );
		nodes.nodes = cast obj.nodes;
		nodes.links = cast obj.links;

		this.fileName = fileName;
	}

	function menuBar()
	{
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( fileName != null && ImGui.menuItem("Save", "Ctrl+S"))
				{
					var obj: FlowFile = {
						nodes: cast nodes.nodes,
						links: cast nodes.links
					};

					sys.io.File.saveContent( Utils.fixWritePath(fileName,"flow"), CDPrinter.print( obj ) );

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

						var obj: FlowFile = {
							nodes: cast nodes.nodes,
							links: cast nodes.links
						};

						sys.io.File.saveContent( Utils.fixWritePath(fileName,"flow"), CDPrinter.print( obj ) );

						cerastes.tools.AssetBrowser.needsReload = true;
					}
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

	inline function windowID()
	{
		return 'flow${fileName}';
	}

}

#end