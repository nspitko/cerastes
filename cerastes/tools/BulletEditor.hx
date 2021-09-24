
package cerastes.tools;

#if ( hlimgui && cannonml )

import org.si.cml.CMLObject;
import org.si.cml.CMLFiber;
import cerastes.tools.ImguiTool.ImguiToolManager;
import hl.UI;
import haxe.Json;
import cerastes.tools.ImguiTools.IG;
import h3d.mat.Texture;
import hxd.res.Loader;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

import cerastes.bulletml.BulletManager;
import cerastes.bulletml.CannonBullet;

@:keep
class BulletEditor extends ImguiTool
{

	var viewportWidth: Int;
	var viewportHeight: Int;

	var preview: h2d.Scene;
	var sceneRT: Texture;
	var sceneRTId: Int;

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var fileName = "";

	var data: CannonFile;
	var fiberName: String = null;

	var fiberClickedName = "test";
	var modalTextValue = "";

	static var globalIndex = 0;
	var index = 0;

	var seed: CMLFiber;

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");
		viewportWidth = 640;
		viewportHeight = 360;

		index = globalIndex++;

		if( size != null )
		{
			var p = size.split("x");
			viewportWidth = Std.parseInt(p[0]);
			viewportHeight = Std.parseInt(p[1]);
		}

		preview = new h2d.Scene();
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);

		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		// TEMP: Populate with some crap
		fileName = "";

		updateScene();
	}

	public function openFile( f: String )
	{
		fileName = f;
		updateScene();

	}

	override public function render( e: h3d.Engine)
	{
		sceneRT.clear( 0 );

		e.pushTarget( sceneRT );
		e.clear(0,1);
		preview.render(e);
		e.popTarget();
	}

	function updateScene()
	{
		preview.removeChildren();
		BulletManager.initialize(preview, fileName);

	}

	function updateSeed()
	{

		if( fiberName != null )
		{
			BulletManager.destroy();

			try
			{
			seed = BulletManager.createSeed(fiberName, viewportWidth / 2, viewportHeight / 2);
			var b : CannonBullet = cast seed.object;

			}
			catch( e)
			{
				trace(e);
			}
		}
	}


	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: viewportWidth + 800, y: viewportHeight + 120}, ImGuiCond.Once);
		ImGui.begin('\uf185 Bullet Editor (${fileName})###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview###${windowID()}_preview');
		ImGui.image(sceneRT, { x: viewportWidth, y: viewportHeight } );
		ImGui.end();

		// Windows
		editorWindow();
		fiberList();

		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}
	}

	function menuBar()
	{
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if (ImGui.menuItem("Open", "Ctrl+O"))
				{
					//ImguiToolManager.showTool("Perf");
				}
				if (fileName != "" && ImGui.menuItem("Save", "Ctrl+S"))
				{
					var f : CannonFile = [];
					for( k => v in @:privateAccess BulletManager.patternList )
						f.push({name: k, fiber: v});

					sys.io.File.saveContent( 'res/${fileName}', Json.stringify(f) );
				}
				if (ImGui.menuItem("Save As..."))
				{
					var newFile = UI.saveFile({
						title:"Save As...",
						filters:[
						{name:"Cannon ML Packages", exts:["cml"]}
						]
					});
					if( newFile != null )
					{

						var f : CannonFile = [];
						for( k => v in @:privateAccess BulletManager.patternList )
							f.push({name: k, fiber: v});

						sys.io.File.saveContent( '${newFile}', Json.stringify(f) );
						var idx = newFile.indexOf("res");
						if( idx != -1 )
						{
							var localPath = newFile.substr(idx);
							fileName = localPath;
						}

						cerastes.tools.AssetBrowser.needsReload = true;
					}
					//ImguiToolManager.showTool("UIEditor");
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

	function editorWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Script###${windowID()}_script' );

		if( fiberName != null )
		{
			var newFiber = IG.textInputMultiline( "Fiber", @:privateAccess BulletManager.patternList[fiberName], {x:300,y:200}  );
			if( newFiber != null )
			{
				@:privateAccess BulletManager.patternList[fiberName] = newFiber;
				updateSeed();
			}
		}
		else
		{
			ImGui.text("No fiber selected.");
		}
		ImGui.end();
	}


	function fiberList()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Fibers###${windowID()}_fiberlist');
		ImGui.beginChild("FiberList",{x:300,y:400},false );
		for( k => v in @:privateAccess BulletManager.patternList )
		{
			var flags = ImGuiTreeNodeFlags.Leaf;
			if( k == fiberName )
				flags |= ImGuiTreeNodeFlags.Selected;
			var isOpen = ImGui.treeNodeEx( k, flags );

			if( isOpen )
				ImGui.treePop();


			if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
			{
				fiberClickedName = k;
				ImGui.openPopup('${k}_rc');
			}
			if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
			{
				fiberName = k;
				updateSeed();
			}

			if( ImGui.beginPopup('${k}_rc') )
			{
				if( ImGui.menuItem("Rename") )
				{
					ImGui.openPopup('${windowID()}_rc_rename');
				}
				if( ImGui.menuItem("Delete") )
				{
					ImGui.openPopup('${windowID()}_rc_delete');
				}
				ImGui.endPopup();
			}



		}
		ImGui.endChild();
		if( ImGui.button("Add") )
		{
			var i=1;
			do
			{
				fiberClickedName = 'fiber${i++}';
			}
			while( @:privateAccess BulletManager.patternList.exists(fiberClickedName) );
			ImGui.openPopup('${windowID()}_rc_add');
		}

		var isOpen = true;
		var closeRef = hl.Ref.make(isOpen);

		//ImGui.openPopup('${windowID()}_rc_rename');


		if( ImGui.beginPopupModal('New fiber name###${windowID()}_rc_rename', closeRef, ImGuiWindowFlags.AlwaysAutoResize) )
		{
			var r = IG.textInput("New name", fiberClickedName);
			if( r != null )
				modalTextValue = r;

			if( ImGui.button("Save") )
			{
				@:privateAccess BulletManager.patternList.set(modalTextValue, @:privateAccess BulletManager.patternList.get(fiberClickedName) );
				@:privateAccess BulletManager.patternList.remove(fiberClickedName);
				ImGui.closeCurrentPopup();
			}

			ImGui.sameLine();

			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}


			ImGui.endPopup();
		}

		if( ImGui.beginPopupModal('Really delete ${fiberClickedName}?###${windowID()}_rc_delete', closeRef, ImGuiWindowFlags.AlwaysAutoResize) )
		{
			ImGui.text("This can't be undone since I'm too lazy to add proper undo support.");
			ImGui.separator();

			if( ImGui.button("Ok") )
			{
				@:privateAccess BulletManager.patternList.remove(fiberClickedName);
				ImGui.closeCurrentPopup();
			}

			ImGui.sameLine();

			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}


			ImGui.endPopup();
		}

		if( ImGui.beginPopupModal('New Fiber###${windowID()}_rc_add', closeRef, ImGuiWindowFlags.AlwaysAutoResize) )
		{

			var r = IG.textInput("ID", fiberClickedName);
			if( r != null )
				fiberClickedName = r;

			if( ImGui.button("Save") )
			{
				@:privateAccess BulletManager.patternList.set(fiberClickedName,"");
				ImGui.closeCurrentPopup();
			}

			ImGui.sameLine();

			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}


			ImGui.endPopup();
		}




		ImGui.end();


	}

	inline function windowID()
	{
		return 'bmle${index}';
	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = windowID();

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
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}
}

#end