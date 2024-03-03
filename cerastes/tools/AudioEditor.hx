
package cerastes.tools;
#if hlimgui
import hxd.res.Sound;
import cerastes.SoundManager;
import cerastes.SoundManager;
import cerastes.tools.ImguiTools.IG;

import hxd.Key;
import sys.io.File;
import cerastes.data.Nodes.Link;
import cerastes.file.CDParser;
import cerastes.file.CDPrinter;

import cerastes.flow.Flow;
import haxe.rtti.Meta;
import haxe.rtti.Rtti;
import cerastes.tools.ImguiTool.ImGuiToolManager;
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
import imgui.ImGuiMacro.wref;

@:structInit
class AETreeNode
{
	public var name: String = "Root";
	public var cues: Map<String, SoundCue> = [];
	public var children: Array<AETreeNode> = [];
}

enum AESelectMode
{
	Cue;
}

@:keep
@multiInstance(true)
class AudioEditor extends ImguiTool
{

	var cues: Map<String, SoundCue> = [];

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var cueTree: AETreeNode = {};

	var selectMode: AESelectMode = Cue;

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var nestedCues: Array<String> = [];

	var selectedTreeNode: AETreeNode;
	var selectedTreeCue: String;
	var selectedCue: SoundCue;

	var showPopupNew = false;

	var zoom: Float = 50; // pixels per second

	var cueInstance: CueInstance;

	public override function getName() { return "\uf569 Audio Editor"; }

	public function new()
	{

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		//openFile( "data/soundtest.audio" );
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
		ImGui.begin('\uf569 Audio Editor ${fileName != null ? fileName : ""}###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('View##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		cueEditor();

		ImGui.end();

		browser();
		inspector();

		popups();


		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}


	}

	var tmpInput = "";
	function popups()
	{
		if( showPopupNew )
		{
			ImGui.openPopup("new_cue");
			showPopupNew = false;
		}

		if( ImGui.beginPopupModal('new_cue'))
		{

			ImGui.setKeyboardFocusHere();
			var r = IG.textInput("Name", tmpInput,ImGuiInputTextFlags.EnterReturnsTrue);

			if( r != null )
			{
				tmpInput = r;
				cues.set(tmpInput, {});
				recomputeTree();
				ImGui.closeCurrentPopup();
			}

			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}


			ImGui.endPopup();
		}
	}

	inline function sToPixel( seconds: Float )
	{
		return ( seconds * zoom );
	}

	inline function pixelToS( pixels: Float )
	{
		return pixels / zoom;
	}

	var nextScrollX: Float = -1;
	function cueEditor()
	{

	}

	function toDragDropClip( )
	{
		var payload = ImGui.acceptDragDropPayloadString("asset_name");
		if( payload != null )
		{
			// Is it an audio file?
			if( StringTools.endsWith( payload, ".wav" ) || StringTools.endsWith( payload, ".ogg" ) || StringTools.endsWith( payload, ".mp3" ))
			{
				return payload;
			}
		}

		return null;

	}

	static var imguiIds: Map<String, ImGuiID> = [];
	function getID( id: String )
	{
		if( !imguiIds.exists(id) )
			imguiIds.set(id, ImGui.getID(id));

		return imguiIds[id];
	}




	function browser()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Cues##${windowID()}');
		handleShortcuts();

		ImGui.beginChild("cuelist",null, false, ImGuiWindowFlags.AlwaysAutoResize);

		populateBrowser( cueTree );

		ImGui.endChild();



		ImGui.end();

	}

	function recomputeTree()
	{

		var sortedCues: Array<String> = [ for( k => v in cues ) k ];
		sortedCues.sort( Reflect.compare );

		for( cue in sortedCues )
		{
			var path = cue.split(".");
			//var name = path.pop();
			setLeaf( path, cues[cue] );
		}

	}
	function setLeaf( path: Array<String>, cue: SoundCue )
	{
		var target: AETreeNode = cueTree;
		for( i in 0 ... path.length )
		{
			var isLeaf = i == path.length - 1;
			var node = path[i];
			if( isLeaf )
			{
				target.cues.set( path.join("."), cue);
			}
			else
			{
				var t: AETreeNode = null;
				for( branch in target.children )
				{
					if( branch.name == node)
					{
						t = branch;
						break;
					}
				}

				if( t == null )
				{
					t = {
						name: node
					}
					target.children.push( t );
				}
				target = t;
			}
		}
	}

	function populateBrowser( node: AETreeNode )
	{
		var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
		//if( c.children.length == 0)
		//	flags |= ImGuiTreeNodeFlags.Leaf;

		var icon = '\uf07c';

		if( selectedTreeNode == node )
		{
			flags |= ImGuiTreeNodeFlags.Selected;

		}

		var name = '${icon} ${node.name}';

		var isOpen = ImGui.treeNodeEx( name, flags );

		if( ImGui.isItemClicked() )
		{
			selectedTreeNode = node;
			selectedTreeCue = null;
		}



		if( isOpen  )
		{
			if( node.children.length > 0)
			{
				for( child in node.children )
					populateBrowser(child);
			}

			for( name => cue in node.cues )
			{

				var flags = ImGuiTreeNodeFlags.Leaf;

				if( selectedCue == null )
					selectedCue = cue;



				var icon = '\uf028';

				if( selectedTreeCue == name )
				{
					flags |= ImGuiTreeNodeFlags.Selected;
				}

				var shortName = name.split('.').pop();


				var label = '${icon} ${shortName}';

				var isOpen = ImGui.treeNodeEx( label, flags );

				if( ImGui.isItemClicked() )
				{
					selectedTreeCue = name;
					selectedCue = cue;
					selectedTreeNode = null;
					selectMode = Cue;
				}

				if( isOpen )
					ImGui.treePop();


			}

			ImGui.treePop();
		}

	}

	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');
		handleShortcuts();

		switch( selectMode )
		{
			case Cue:
				if( selectedCue != null )
				{
					ImGui.pushFont( ImGuiToolManager.headingFont );
					ImGui.text( selectedTreeCue );
					ImGui.popFont();

					wref( ImGui.sliderDouble( "Volume", _, 0, 2 ), selectedCue.volume );
					wref( ImGui.sliderDouble( "Volume Variance", _, -1, 1 ), selectedCue.volumeVariance );

					wref( ImGui.checkbox( "Loop", _ ), selectedCue.loop );

					wref( ImGui.sliderDouble( "Pitch", _, 0, 2 ), selectedCue.pitch );
					wref( ImGui.sliderDouble( "Pitch Variance", _, -1, 1 ), selectedCue.pitchVariance );

					wref( ImGui.sliderDouble( "Low Pass", _, 0, 1 ), selectedCue.lowpass );
					wref( ImGui.sliderDouble( "Low Pass Variance", _, -1, 1 ), selectedCue.lowpassVariance );

					if( ImGui.beginChild("clips") )
					{
						if( selectedCue.clips != null )
						{

							for( idx in 0 ... selectedCue.clips.length )
							{
								if( selectedCue.clips[idx] == null )
									continue;

								ImGui.pushID('idx${idx}');
								wref( ImGui.inputText( '${idx}', _), selectedCue.clips[idx] );

								if( ImGui.button("Del") )
									selectedCue.clips.splice(idx,1);

								ImGui.popID();
							}
						}
						else
						{
							ImGui.text("No clips added. Drag an audio file to add one!");
						}
						ImGui.endChild();
					}

					if( ImGui.beginDragDropTarget() )
					{
						var clip = toDragDropClip();
						if( clip != null )
						{
							if( selectedCue.clips == null )
								selectedCue.clips = [ clip ];
							else
								selectedCue.clips.push(clip);
						}

					}
					if( ImGui.button("Add") )
					{
						if( selectedCue.clips == null )
							selectedCue.clips = [""];
						else
							selectedCue.clips.push("");
					}


				}



		}



		ImGui.end();

	}




	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'AudioEditorDockspace${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}

	public override function openFile( fileName: String )
	{
		var file: SoundCueFile = CDParser.parse(hxd.Res.loader.load( fileName ).toText(), SoundCueFile );
		cues = file.cues;

		this.fileName = fileName;

		recomputeTree();

	}

	function saveAs()
	{
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes audio files", exts:["audio"]}
			]
		});
		if( newFile != null )
		{
			fileName = Utils.toLocalFile( newFile );

			save();


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

		var obj: SoundCueFile = {
			cues: cues
		}

		sys.io.File.saveContent( Utils.fixWritePath(fileName,"audio"), CDPrinter.print( obj ) );


		ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
	}

	function handleShortcuts()
	{
		if( !ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) )
			return;
		if( Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}

		if( Key.isDown( Key.CTRL ) && Key.isPressed( Key.N ) )
		{
			showPopupNew = true;
		}

		if(  Key.isPressed( Key.SPACE ) )
		{
			if( selectedCue != null )
			{
				if( cueInstance != null && !cueInstance.isFinished )
					cueInstance.stop();
				else
					cueInstance = selectedCue.play();
			}
		}

		if( Key.isPressed( Key.DELETE ) )
		{
			switch( selectMode )
			{
				case Cue:
					cues.remove( selectedTreeCue );
					selectedCue = null;
					recomputeTree();
			}
		}
	}

	function menuBar()
	{

		handleShortcuts();
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if( ImGui.menuItem("New Cue", "Ctrl+N") )
				{
					showPopupNew = true;
				}
				ImGui.separator();
				if ( fileName != null && ImGui.menuItem("Save", "Ctrl+S"))
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
	}

	public override inline function windowID()
	{
		return 'audioeditor${fileName != null ? fileName : ""+toolId}';
	}

}

#end