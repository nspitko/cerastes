
package cerastes.tools;
#if ( bullet && hlimgui )
import hxd.SceneEvents;
import bullet.Point;
import h3d.col.Bounds;
import cerastes.c3d.Prefab.PrefabDef;
import dx.Driver;
import h3d.impl.DirectXDriver;
import h3d.Camera;
import h3d.scene.Graphics;
import hxd.Key;
import cerastes.tools.ImguiTool.ImguiToolManager;
import h3d.Vector;
import h3d.mat.Texture;
import cerastes.c3d.World;
import cerastes.c3d.World.WorldDef;
import hl.Ref;


import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import imgui.NodeEditor;

import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImGuiNodes;

@:keep
class WorldEditor extends ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;

	var dockID : ImGuiID = -1;

	var perspectiveScene: h3d.scene.Scene;
	var topScene: h3d.scene.Scene;
	var sideScene: h3d.scene.Scene;
	var frontScene: h3d.scene.Scene;

	var perspectiveEvents: hxd.SceneEvents;
	var topEvents: hxd.SceneEvents;
	var sideEvents: hxd.SceneEvents;
	var frontEvents: hxd.SceneEvents;

	var perspectiveRT: Texture;
	var topRT: Texture;
	var sideRT: Texture;
	var frontRT: Texture;

	var topCamera: Camera;
	var sideCamera: Camera;
	var frontCamera: Camera;
	var perspectiveCamera: Camera;

	var fileName: String = null;

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockspaceIdPerspective: ImGuiID;
	var dockspaceIdTop: ImGuiID;
	var dockspaceIdSide: ImGuiID;
	var dockspaceIdFront: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var origin: h3d.scene.Graphics;
	var grid: h3d.scene.Graphics;

	var mouseScenePos: ImVec2;

	var selectedPrefab: PrefabDef = null;


	var worldDef: WorldDef;
	var world: World;

	public function new()
	{

		var size = haxe.macro.Compiler.getDefine("windowSize");

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;

		perspectiveScene = new h3d.scene.Scene();
		topScene = new h3d.scene.Scene();
		sideScene = new h3d.scene.Scene();
		frontScene = new h3d.scene.Scene();

		perspectiveRT = new Texture(viewportWidth,viewportHeight, [Target] );
		topRT = new Texture(viewportWidth,viewportHeight, [Target] );
		sideRT = new Texture(viewportWidth,viewportHeight, [Target] );
		frontRT = new Texture(viewportWidth,viewportHeight, [Target] );

		worldDef = {
			prefabs: [
				{
					file: "test/rock.prefab",
					x: 0,
					y: 0,
					z: 0,
					rotation: new h3d.Quat(0,0,0,0)
				}
			],
			geo: []
		};

		world = new World( );

		perspectiveScene.addChild(world);



		perspectiveEvents = new hxd.SceneEvents();
		perspectiveEvents.addScene( perspectiveScene );

		topEvents = new hxd.SceneEvents();
		topEvents.addScene( topScene );

		sideEvents = new hxd.SceneEvents();
		sideEvents.addScene( sideScene );

		frontEvents = new hxd.SceneEvents();
		frontEvents.addScene( frontScene );


		// @todo: Move to world
		var light = new h3d.scene.pbr.DirLight(perspectiveScene);
		light.setPosition(72, 72, 40);
		light.setDirection(new Vector( 1.0, 1.0, -1.0 ));
		light.power = 3;

		new h3d.scene.fwd.DirLight(new h3d.Vector( 0.3, -0.4, -0.9), perspectiveScene);


		perspectiveScene.camera.target.set(0, 0, 1);
		perspectiveScene.camera.pos.set(25, 25, 25);
		new h3d.scene.CameraController(perspectiveScene).loadFromCamera();

		var viewportRatio = viewportHeight / viewportWidth;
		var orthoSize = 25;

		topScene.camera.target.set(0,0,0);
		topScene.camera.pos.set(0,0,25);
		topScene.camera.orthoBounds = new Bounds();
		topScene.camera.orthoBounds.setMin(new Point( -orthoSize, -orthoSize * viewportRatio, -100 ) );
		topScene.camera.orthoBounds.setMax(new Point( orthoSize, orthoSize * viewportRatio, 100 ) );
		new h3d.scene.CameraController(topScene).loadFromCamera();

		sideScene.camera.target.set(0,0,0);
		sideScene.camera.pos.set(0,25,0);
		sideScene.camera.orthoBounds = new Bounds();
		sideScene.camera.orthoBounds.setMin(new Point( -orthoSize, -orthoSize * viewportRatio, -100 ) );
		sideScene.camera.orthoBounds.setMax(new Point( orthoSize, orthoSize * viewportRatio, 100 ) );
		new h3d.scene.CameraController(sideScene).loadFromCamera();

		frontScene.camera.target.set(0,0,0);
		frontScene.camera.pos.set(25,0,0);
		frontScene.camera.orthoBounds = new Bounds();
		frontScene.camera.orthoBounds.setMin(new Point( -orthoSize, -orthoSize * viewportRatio, -100 ) );
		frontScene.camera.orthoBounds.setMax(new Point( orthoSize, orthoSize * viewportRatio, 100 ) );
		new h3d.scene.CameraController(frontScene).loadFromCamera();

		rebuildWorld();

		origin = new Graphics(perspectiveScene);

		final originSize = 1;
		final originThickness = 10;

		origin.lineStyle(originThickness,0xFF0000, 0.5 );
		origin.moveTo(0,0,0);
		origin.lineTo(originSize,0,0);

		origin.lineStyle(originThickness,0x00FF00, 0.5);
		origin.moveTo(0,0,0);
		origin.lineTo(0,originSize,0);

		origin.lineStyle(originThickness,0x0000FF, 0.5);
		origin.moveTo(0,0,0);
		origin.lineTo(0,0,originSize);

		origin.material.props = h3d.mat.MaterialSetup.current.getDefaults("ui");
		//origin.visible = false;
		origin.material.mainPass.depthWrite = true;
		origin.material.mainPass.depthTest = Always;

		grid = new Graphics(topScene);
		grid.material.props = h3d.mat.MaterialSetup.current.getDefaults("ui");
		grid.material.mainPass.depthWrite = true;
		grid.material.mainPass.depthTest = Always;

	}

	function updateGrid( rangeX: Int, rangeY: Int, rangeZ: Int )
	{
		// @todo determine bounds from cameras
		grid.clear();
		grid.lineStyle(10, 0x888888, 0.5 );
		var chunkSize = world.geo.chunkSize;

		for( x in -rangeX ... rangeX )
		{
			for( y in -rangeY ... rangeY )
			{
				for( z in -rangeZ ... rangeZ )
				{
					grid.moveTo(x * chunkSize, y * chunkSize,z * chunkSize);
					grid.lineTo(x * chunkSize + chunkSize, y * chunkSize, z * chunkSize);
					grid.moveTo(x * chunkSize, y * chunkSize, z * chunkSize);
					grid.lineTo(x * chunkSize, y * chunkSize + chunkSize, z * chunkSize);
					grid.moveTo(x * chunkSize, y * chunkSize, z * chunkSize );
					grid.lineTo(x * chunkSize, y * chunkSize, z * chunkSize + chunkSize);
				}
			}
		}
	}

	function rebuildWorld()
	{
		world.load( worldDef );


		//world.addChild( origin );
	}



	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: viewportWidth * 2, y: viewportHeight * 1.6}, ImGuiCond.Once);
		ImGui.begin('\uf557 World Editor##${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		//menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		// Selected Border stuff
		//processSelection();

		//inspectorColumn();

		//ImGui.sameLine();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdPerspective, dockCond );
		ImGui.begin('Perspective##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoScrollbar );
		ImGui.setCursorPos({x:0, y:0});
		ImGui.image(perspectiveRT, { x: perspectiveRT.width, y: perspectiveRT.height } );
		handleSceneMouse( perspectiveEvents );
		updateViewport( perspectiveRT );
		ImGui.end();

		ImGui.setNextWindowDockId( dockspaceIdTop, dockCond );
		ImGui.begin('Top##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoScrollbar );
		ImGui.setCursorPos({x:0, y:0});
		ImGui.image(topRT, { x: topRT.width, y: topRT.height });
		handleSceneMouse( topEvents );
		updateViewport( topRT, topScene );
		ImGui.end();

		ImGui.setNextWindowDockId( dockspaceIdFront, dockCond );
		ImGui.begin('Front##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoScrollbar );
		ImGui.setCursorPos({x:0, y:0});
		ImGui.image(frontRT, { x: frontRT.width, y: frontRT.height });
		handleSceneMouse( frontEvents );
		updateViewport( frontRT, frontScene );
		ImGui.end();

		ImGui.setNextWindowDockId( dockspaceIdSide, dockCond );
		ImGui.begin('Side##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoScrollbar );
		ImGui.setCursorPos({x:0, y:0});
		ImGui.image(sideRT, { x: sideRT.width, y: sideRT.height } );
		handleSceneMouse( sideEvents );
		updateViewport( sideRT, sideScene );
		ImGui.end();


		inspectorColumn();

		propertiesColumn();

		//ImGui.end();


		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}



	}

	function updateViewport(rt: Texture, ?scene: h3d.scene.Scene)
	{
		var size: ImVec2 = ImGui.getWindowSize();
		var sx: Int = Math.floor( size.x );
		var sy: Int = Math.floor( size.y );

		if(sx != rt.width || sy != rt.height )
		{
			rt.resize(sx, sy);

			if( scene != null )
			{
				var scalefactor = .05;
				scene.camera.orthoBounds.setMin(new Point( -sx * scalefactor, -sy * scalefactor, -100 ) );
				scene.camera.orthoBounds.setMax(new Point( sx * scalefactor, sy * scalefactor, 100 ) );
			}
		}
	}

	function propertiesColumn()
	{
		//ImGui.beginChild("uie_inspector",{x: 200 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize );
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Properties##${windowID()}');


		ImGui.text("Todo");



		//ImGui.endChild();
		ImGui.end();
	}

	function inspectorColumn()
	{
		//ImGui.beginChild("uie_inspector",{x: 200 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize );
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Inspector##${windowID()}');


		// Buttons
		if( ImGui.button("Add") )
		{
			ImGui.openPopup("we_additem");
		}

		if( ImGui.beginPopup("we_additem") )
		{
			ImGui.menuItem( 'But how?');
			ImGui.endPopup();
		}
		ImGui.sameLine();

		if( ImGui.button("Delete") && selectedPrefab != null )
		{
			// @todo
		}


		ImGui.beginChild("we_inspector_tree",null, false, ImGuiWindowFlags.AlwaysAutoResize);

		populateInspector();

		ImGui.endChild();



		//ImGui.endChild();
		ImGui.end();
	}

	function populateInspector()
	{
		if( worldDef == null )
			return;


	}



	function handleSceneMouse( sceneEvents: SceneEvents )
	{
		if( !ImGui.isItemHovered() )
			return;


		var startPos: ImVec2 = ImGui.getCursorScreenPos();
		var mousePos: ImVec2 = ImGui.getMousePos();

		mouseScenePos = {x: ( mousePos.x - startPos.x), y: ( startPos.y - mousePos.y ) };

		var event = new hxd.Event(EMove, mouseScenePos.x, mouseScenePos.y);

		if( ImGui.isMouseClicked( ImGuiMouseButton.Left ) )
		{
			event.kind = EPush;
			event.button = 0;
		}
		else if( ImGui.isMouseClicked( ImGuiMouseButton.Right ) )
		{
			event.kind = EPush;
			event.button = 1;
		}
		else if( ImGui.isMouseReleased( ImGuiMouseButton.Left ) )
		{
			event.kind = ERelease;
			event.button = 0;
		}
		else if( ImGui.isMouseReleased( ImGuiMouseButton.Right ) )
		{
			event.kind = ERelease;
			event.button = 1;
		}

		@:privateAccess sceneEvents.emitEvent( event );

		//preview.dispatchListeners( event );


	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = "WorldEditorDockSpace";

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");


			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var d2 = 0;

			var idOut: hl.Ref<ImGuiID> = dockspaceId;
			var idOtherOut: hl.Ref<ImGuiID> = d2;

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);

			dockspaceIdPerspective = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.5, idOtherOut, idOut);
			dockspaceIdTop = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.5, null, idOut);
			dockspaceIdPerspective = idOut.get();

			dockspaceIdFront = ImGui.dockBuilderSplitNode(idOtherOut.get(), ImGuiDir.Right, 0.5, null, idOut);
			dockspaceIdSide = idOut.get();




			ImGui.dockBuilderFinish(dockspaceId);
		}
	}


	inline function windowID()
	{
		return 'we${fileName}';
	}


	override public function render( e: h3d.Engine)
	{


		perspectiveScene.addChild( world );
		grid.visible = false;

		perspectiveRT.clear( 0 );
		e.pushTarget( perspectiveRT );
		e.clear(0,1);
		perspectiveScene.render(e);
		e.popTarget();

		grid.visible = true;

		/*
		var d: DirectXDriver = cast e.driver;

		for( rasterBits => state in @:privateAccess d.rasterStates )
		{
			if( rasterBits == 0 )
				continue;

			var desc = new RasterizerDesc();

			desc.fillMode = WireFrame;
			desc.cullMode = None;

			desc.depthClipEnable = false;
			desc.scissorEnable = false;
			var raster = Driver.createRasterizerState(desc);
			@:privateAccess d.rasterStates.set(rasterBits, raster);


		}
		*/

		updateGrid(10,10,1);
		topScene.addChild( world );
		topScene.addChild( grid );
		e.pushTarget( topRT );
		e.clear(0,1);
		topScene.render(e);
		e.popTarget();

		updateGrid(10,1,10);
		sideScene.addChild( world );
		sideScene.addChild( grid );
		e.pushTarget( sideRT );
		e.clear(0,1);
		sideScene.render(e);
		e.popTarget();

		updateGrid(1,10,10);
		frontScene.addChild( world );
		frontScene.addChild( grid );
		e.pushTarget( frontRT );
		e.clear(0,1);
		frontScene.render(e);
		e.popTarget();


		/*
		for( idx => state in @:privateAccess d.rasterStates )
		{
			state.release();
			@:privateAccess d.rasterStates.remove(idx);
		}
		*/



	}

}

#end