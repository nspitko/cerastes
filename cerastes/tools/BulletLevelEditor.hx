
package cerastes.tools;

import cerastes.fmt.SpriteResource.CSDFile;
import cerastes.fmt.BulletLevelResource;
import cerastes.macros.Metrics;
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

enum SelectMode {
	None;
	Select;
	PlaceEntity;
	PlaceSpawnGroup;
	Move;
}

@:keep
class BulletLevelEditor extends ImguiTool
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
	var dockspaceIdBottom: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var level: BulletLevel;

	var fileName = "";

	var data: CBLFile;
	var modalTextValue = "";


	var selectMode: SelectMode;

	public function new()
	{
		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;

		preview = new h2d.Scene();
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);

		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		// TEMP: Populate with some crap
		fileName = "";

		rebuildScene();
	}

	public function openFile( f: String )
	{
		fileName = f;
		rebuildScene();

	}

	override public function render( e: h3d.Engine)
	{
		sceneRT.clear( 0 );

		e.pushTarget( sceneRT );
		e.clear(0,1);
		preview.render(e);
		e.popTarget();
	}

	function rebuildScene()
	{
		if( level != null )
		{
			level.remove();
			BulletManager.destroy();
		}
		level = new BulletLevel( data, preview );
	}

	function reset()
	{
		BulletManager.destroy();
	}



	override public function update( delta: Float )
	{
		Metrics.begin();
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.pushID(windowID());

		ImGui.setNextWindowSize({x: viewportWidth + 800, y: viewportHeight + 120}, ImGuiCond.Once);
		if( ImGui.begin('\uf279 Bullet Level Editor (${fileName})', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar ) )
		{

			menuBar();

			dockSpace();

			ImGui.dockSpace( dockspaceId, null );
		}
		ImGui.end();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		if( ImGui.begin('Preview') )
		{
			ImGui.image(sceneRT, { x: viewportWidth, y: viewportHeight }, null, null, null, {x: 1, y: 1, z: 1, w: 1} );
		}
		ImGui.end();

		// Windows
		objectPalette();
		timeline();

		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}

		ImGui.popID();

		Metrics.end();
	}

	function menuBar()
	{
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
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
						{name:"Bullet Levels", exts:["cbl"]}
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

	function objectPalette()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Object Palette' ) )
		{
			modeButton("Select", Select);
			modeButton("Place Move", Move);
			modeButton("Place Entity", PlaceEntity);
			modeButton("Place Group", PlaceSpawnGroup);
		}
		ImGui.end();


	}

	function modeButton( label: String, mode: SelectMode )
	{
		var selected = selectMode == mode;
		if( selected )
		{
			ImGui.pushStyleColor(ImGuiCol.Button,0xFFFFFFFF);
			ImGui.pushStyleColor(ImGuiCol.Text,0xFF000000);
		}
		if( ImGui.button(label) ) selectMode = mode;

		if( selected )
			ImGui.popStyleColor(2);
	}


	function timeline()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		ImGui.begin('Fibers');

		var pos: Single = 0;
		//ImGui.dragFloatRange2("Position", pos);
		ImGui.end();


	}

	inline function windowID()
	{
		return 'blevel${fileName}';
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

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.30, null, idOut);
			dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.20, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}
}

#end