
package cerastes.tools;
#if ( hlimgui && cannonml )
import cerastes.fmt.SpriteResource.CSDSound;
import h3d.Vector;
import h3d.mat.DepthBuffer;
import h2d.Graphics;
import cerastes.collision.Colliders.AABB;
import cerastes.fmt.SpriteResource.CSDFile;
import cerastes.fmt.BulletLevelResource;
import cerastes.macros.Metrics;

import org.si.cml.CMLObject;
import org.si.cml.CMLFiber;
import cerastes.tools.ImguiTool.ImGuiToolManager;
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
	SelectMesh;
	AssignSpawnGroup;
	PlaceEntity;
	PlaceSpawnGroup;
	PlaceTrigger;
	PlaceMesh;
	Move;
}

enum InspectMode {
	None;
	Sprite;
	SpawnGroup;
	Trigger;
	Mesh;
}

@:keep
class BulletLevelEditor extends ImguiTool
{

	var viewportWidth: Int;
	var viewportHeight: Int;

	var preview: h2d.Scene;
	var preview3d: h3d.scene.Scene;
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

	var sceneX = 0;
	var sceneY = 0;

	var data: CBLFile;
	var modalTextValue = "";


	var selectMode: SelectMode = None;
	var inspectMode: InspectMode = None;
	var mouseScenePos: ImVec2;
	var isMouseOverViewport = false;

	var selectedSprite: CBLObject;
	var selectedGroup: CBLSpawnGroup;
	var selectedTrigger: CBLTrigger;
	var selectedMesh: CBLMesh;

	var selectedFiber: String = null;

	var fiberList: Map<String, String> = [];

	var graphics: Graphics;

	var startRunPos: Float = 0;


	public function new()
	{
		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;

		preview = new h2d.Scene();
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);
		preview3d = new h3d.scene.Scene();
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);


		cast(preview3d.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(1, 1, 1);


		var cam = preview3d.camera;

		cam.zNear = 1;
		cam.zFar = 100;


		cam.pos.x = 0;
		cam.pos.y = 6;
		cam.pos.z = 7;



		cam.target.x = 0;
		cam.target.y = 0;
		cam.target.z = -7;


		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );
		sceneRT.depthBuffer = new DepthBuffer(viewportWidth,viewportHeight);

		graphics = new Graphics();

		// TEMP: Populate with some crap
		fileName = "data/level1.cbl";
		if( fileName != "" )
			openFile(fileName);

		var fiberFile = hxd.Res.tools.levelfibers.entry.getText();
		var entries = fiberFile.split("`");
		for( e in entries )
		{
			var lines = e.split("\n");
			var title = lines.shift();
			var fiber = lines.join("\n");
			fiberList.set(title, fiber);
		}


		rebuildScene();


	}

	public function openFile( f: String )
	{
		fileName = f;
		var r = hxd.Res.loader.load(f).to( cerastes.fmt.BulletLevelResource );
		data = r.getData();
		rebuildScene();

	}

	override public function render( e: h3d.Engine)
	{
		sceneRT.clear( 0 );

		e.pushTarget( sceneRT );
		e.clear(data.fogColor,1);
		preview3d.render(e);
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
		level = new BulletLevel( data, Math.min(viewportWidth, data.size.x), Math.min(viewportHeight, data.size.y), preview );
		level.runFibers = false;

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = Math.floor( Math.min(viewportDimensions.width, data.size.x) );
		viewportHeight = Math.floor( Math.min(viewportHeight, data.size.y) );
		sceneRT.resize(cast Math.abs(viewportWidth), cast Math.abs(viewportHeight));
		sceneRT.depthBuffer = new DepthBuffer(cast Math.abs(viewportWidth), cast Math.abs(viewportHeight));
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);
		preview.addChild(graphics);
		preview3d.removeChildren();
		preview3d.addChild( level.o3d );
	}

	function reset()
	{
		BulletManager.destroy();
	}

	function levelRun()
	{
		level.runFibers = true;
		level.velocityX = data.velocity.x;
		level.velocityY = data.velocity.y;
		preview.addChild( @:privateAccess BulletManager.parent );
		@:privateAccess BulletManager.parent.x = 0;
		@:privateAccess BulletManager.parent.y = 0;
		@:privateAccess level.rebuild();
		startRunPos = level.posY;
	}

	function levelStop()
	{
		level.runFibers = false;
		preview.removeChild( @:privateAccess BulletManager.parent );
		BulletManager.destroy();
		@:privateAccess level.rebuild();
		level.simluateMove(0,startRunPos);
	}


	override public function update( delta: Float )
	{
		Metrics.begin();
		if( level.runFibers )
		{
			level.tick(delta);
		}
		graphics.clear();
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.pushID(windowID());

		ImGui.setNextWindowSize({x: viewportWidth + 800, y: viewportHeight + 300}, ImGuiCond.Once);
		if( ImGui.begin('\uf279 Bullet Level Editor (${fileName})', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar ) )
		{

			menuBar();

			dockSpace();

			ImGui.dockSpace( dockspaceId, null );
		}
		ImGui.end();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		if( ImGui.begin('Preview', null, ImGuiWindowFlags.NoMove) )
		{
			var startPos: ImVec2 = ImGui.getCursorScreenPos();
			var localPos: ImVec2 = ImGui.getCursorPos();
			var mousePos: ImVec2 = ImGui.getMousePos();
			mouseScenePos = {x: mousePos.x - startPos.x, y: mousePos.y - startPos.y };
			ImGui.image(sceneRT, { x: viewportWidth, y: viewportHeight }, null, null, null, {x: 1, y: 1, z: 1, w: 1} );

			isMouseOverViewport = 	mouseScenePos.x >= 0 && mouseScenePos.x <= viewportWidth &&
									mouseScenePos.y >= 0 && mouseScenePos.y <= viewportHeight;

			ImGui.setCursorPos({ x: localPos.x + viewportWidth + 40, y: localPos.y } );

			if( level.runFibers == false )
			{
				if( ImGui.button("Run") )
				{
					levelRun();
				}
			}
			else
			{
				if( ImGui.button("Stop") )
				{
					levelStop();
				}
			}

			// Scrollbars
			var sbPadding = 5;
			var scrollTile = Texture.fromColor(0xFFFFFF);
			var col: ImVec4 = {x: 0.3, y: 0.7, z: 0.3, w: 1.0};
			var bcol: ImVec4 = {x: 0.7, y: 1.0, z: 0.7, w: 1.0};
			var dl = ImGui.getWindowDrawList();

			// Left scrollbar
			if( viewportHeight < data.size.y )
			{
				ImGui.setCursorPos({ x: localPos.x + viewportWidth + sbPadding, y: localPos.y } );
				ImGui.image(scrollTile, {x: 20, y:viewportHeight},null, null, col, bcol);

				var maxY = data.size.y + 200;
				if( ImGui.isItemClicked() )
				{

					var clickY = ( ( mousePos.y - startPos.y ) / viewportHeight ) * maxY;
					setScrollY(clickY);
				}


				var lx = startPos.x + viewportWidth + sbPadding;
				var ly = startPos.y + ( viewportHeight * ( level.posY / maxY ) );
				dl.addLine({ x:lx , y: ly }, { x: lx + 20, y: ly }, 0xFFFFFFFF, 1);



			}

			// bottom
			if( viewportWidth < data.size.x )
			{
				ImGui.setCursorPos({ x: localPos.x, y: localPos.y + viewportHeight + sbPadding } );
				ImGui.image(scrollTile, {y: 20, x:viewportWidth},null, null, col, bcol);
			}

		}
		ImGui.end();
		processMouse();

		// Windows
		settings();
		objectPalette();
		inspector();
		timeline();

		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

		ImGui.popID();

		drawAdditionalEntities();

		Metrics.end();
	}

	function drawAdditionalEntities()
	{
		var pos = {x: level.posX, y: level.posY };
		var rect = 25;
		var hr = rect/2;
		var aabbCollider = new AABB({ min: {x: pos.x, y: pos.y}, max: {x: pos.x + viewportWidth, y: pos.y + viewportHeight} });
		graphics.lineStyle(1.5,0x4444ff);
		var triggerSize = 20;
		for( t in data.triggers )
		{
			if( aabbCollider.intersectsPoint( 0,0, t.position.x, t.position.y ) )
			{
				graphics.moveTo(t.position.x - triggerSize + pos.x, t.position.y - pos.y);
				graphics.lineTo(t.position.x + triggerSize + pos.x, t.position.y - pos.y);

				graphics.moveTo(t.position.x + pos.x, t.position.y - triggerSize - pos.y);
				graphics.lineTo(t.position.x + pos.x, t.position.y + triggerSize - pos.y);
			}
		}

		graphics.lineStyle(1.5,0x44ff44);
		for( g in data.spawnGroups )
		{
			if( aabbCollider.intersectsPoint( 0,0, g.position.x, g.position.y ) )
			{
				graphics.moveTo(g.position.x - triggerSize + pos.x, g.position.y - pos.y);
				graphics.lineTo(g.position.x + triggerSize + pos.x, g.position.y - pos.y);

				graphics.moveTo(g.position.x + pos.x, g.position.y - triggerSize - pos.y);
				graphics.lineTo(g.position.x + pos.x, g.position.y + triggerSize - pos.y);
			}
		}

		if( selectMode == Select )
		{

			// sprites
			for( s in data.sprites )
			{
				graphics.drawRect( s.position.x+ pos.x - hr, s.position.y - pos.y- hr, rect, rect );
			}

			// Triggers
			for( t in data.triggers )
			{
				graphics.drawRect( t.position.x+ pos.x- hr, t.position.y - pos.y- hr, rect, rect );
			}

			// SpawnGroups
			for( g in data.spawnGroups )
			{
				graphics.drawRect( g.position.x+ pos.x- hr, g.position.y - pos.y- hr, rect, rect );
			}
		}
		if( selectMode == SelectMesh)
		{
			for( g in data.meshes )
			{
				graphics.drawRect( g.position.x + pos.x- hr , g.position.y - pos.y- hr, rect, rect );
			}

		}

	}

	function setScrollY(amt: Float )
	{
		level.simluateMove( level.posX, amt );
	}

	function processMouse()
	{
		if( ImGui.isMouseClicked(ImGuiMouseButton.Left ) && isMouseOverViewport )
		{
			switch( selectMode )
			{
				case PlaceEntity:
					// get data so we can store the AABB
					data.sprites.push({
						sprite: placeSprite,
						position: {x: mouseScenePos.x + level.posX, y: mouseScenePos.y + level.posY },
						fiber: "",
						rotation: 0,
						speed: {x: -3, y: 0},
						acceleration: {x: 0, y: 0},
						spawnGroup: placeSpawnGroup,
					});

					@:privateAccess level.updateSpawns();

				case PlaceTrigger:
					data.triggers.push({
						position: {x: mouseScenePos.x + level.posX, y: mouseScenePos.y + level.posY },
						type: None,
						data: {x: 0, y:0}
					});

				case PlaceSpawnGroup:
					data.spawnGroups.push({
						position: {x: mouseScenePos.x + level.posX, y: mouseScenePos.y + level.posY },
						id: getNewSpawnGroupID()
					});
				case PlaceMesh:

					//var p = preview3d.camera.unproject( mouseScenePos.x + level.posX, mouseScenePos.y + level.posY, level.meshZ);//, viewportWidth, viewportHeight );

					data.meshes.push({
						position: {x: mouseScenePos.x + level.posX, y: mouseScenePos.y + level.posY },
						mesh: placeMesh,
						scale: 1,
						rotation: 0
					});

					@:privateAccess level.updateSpawns();

				case Select:
					// sprites
					var rect = 25;
					var hr = rect / 2;
					var pos = {x: mouseScenePos.x + level.posX - hr, y: mouseScenePos.y + level.posY -hr};

					var aabbCollider = new AABB({ min: {x: pos.x - rect, y: pos.y - rect}, max: {x: pos.x + rect, y: pos.y + rect} });
					for( s in data.sprites )
					{
						if( aabbCollider.intersectsPoint( 0,0, s.position.x, s.position.y ) )
						{
							selectedSprite = s;
							inspectMode = Sprite;
							return;
						}

					}

					// Triggers
					for( t in data.triggers )
					{
						if( aabbCollider.intersectsPoint( 0,0, t.position.x, t.position.y ) )
						{
							selectedTrigger = t;
							inspectMode = Trigger;
							return;
						}

					}

					// SpawnGroups
					for( g in data.spawnGroups )
					{
						if( aabbCollider.intersectsPoint( 0,0, g.position.x, g.position.y ) )
						{
							selectedGroup = g;
							inspectMode = SpawnGroup;
							return;
						}

					}

				case SelectMesh:
					// Meshes
					var pos = {x: mouseScenePos.x + level.posX, y: mouseScenePos.y + level.posY };
					var rect = 25;
					var aabbCollider = new AABB({ min: {x: pos.x - rect, y: pos.y - rect}, max: {x: pos.x + rect, y: pos.y + rect} });

					for( g in data.meshes )
					{
						if( aabbCollider.intersectsPoint( 0,0, g.position.x, g.position.y ) )
						{
							selectedMesh = g;
							inspectMode = Mesh;
							return;
						}
					}

				case AssignSpawnGroup:
					// sprites
					var pos = {x: mouseScenePos.x + level.posX, y: mouseScenePos.y + level.posY };
					var rect = 25;
					var aabbCollider = new AABB({ min: {x: pos.x - rect, y: pos.y - rect}, max: {x: pos.x + rect, y: pos.y + rect} });
					for( g in data.spawnGroups )
					{
						if( aabbCollider.intersectsPoint( 0,0, g.position.x, g.position.y ) )
						{
							if( selectedSprite != null )
								selectedSprite.spawnGroup = g.id;
							else
								placeSpawnGroup = g.id;

							selectMode = Select;
							return;
						}
					}

				default: // Nothing
			}

		}
	}

	function menuBar()
	{
		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if (fileName != "" && ImGui.menuItem("Save", "Ctrl+S"))
				{
					BulletLevelResource.write( data, fileName );
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

						Utils.error("NOpe");
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

	var placeSprite = "spr/test_ship.csd";
	var placeMesh = "mdl/b1.fbx";
	var placeSpawnGroup: Int = 0;

	function objectPalette()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Object Palette' ) )
		{
			modeButton("Select", Select);
			modeButton("Select Mesh", SelectMesh);
			modeButton("Place Move", Move);
			modeButton("Place Entity", PlaceEntity);
			modeButton("Place Group", PlaceSpawnGroup);
			modeButton("Place Trigger", PlaceTrigger);
			modeButton("Place Mesh", PlaceMesh);
			ImGui.separator();

			var newSprite = IG.textInput( "Sprite", placeSprite );
			if( newSprite != null && hxd.Res.loader.exists( newSprite ) )
				placeSprite = newSprite;

			if( ImGui.beginDragDropTarget() )
			{
				var payload = ImGui.acceptDragDropPayloadString("asset_name");
				if( payload != null && hxd.Res.loader.exists( payload ) )
					placeSprite = payload;

				ImGui.endDragDropTarget();
			}

			ImGui.text("Place spawn Group: " + ( ( placeSpawnGroup == 0 ) ? "NO" : '${placeSpawnGroup}' ));
			if( placeSpawnGroup != 0 )
			{
				ImGui.sameLine();
				if( ImGui.button("\uf057" ) )
					placeSpawnGroup = 0;
			}
			else
			{
				ImGui.sameLine();
				if( ImGui.button("\uf0a4" ) )
				{
					inspectMode = None;
					selectedSprite = null;
					selectMode = AssignSpawnGroup;
				}
			}

			var newMesh = IG.textInput( "Mesh", placeMesh );
			if( newMesh != null && hxd.Res.loader.exists( newMesh ) )
				placeMesh = newMesh;

			if( ImGui.beginDragDropTarget() )
			{
				var payload = ImGui.acceptDragDropPayloadString("asset_name");
				if( payload != null && hxd.Res.loader.exists( payload ) )
					placeMesh = payload;

				ImGui.endDragDropTarget();
			}




		}

		ImGui.end();


	}

	function settings()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Level settings' ) )
		{
			var oldSize = {x: data.size.x, y: data.size.y};
			if( IG.posInput("Size", data.size) )
			{
				var yDiff =oldSize.y - data.size.y;
				if( yDiff != 0 )
				{
					for( o in data.meshes )
						o.position.y -= yDiff;
					for( o in data.spawnGroups )
						o.position.y -= yDiff;
					for( o in data.sprites )
						o.position.y -= yDiff;
					for( o in data.triggers )
						o.position.y -= yDiff;
				}


				rebuildLevel();
			}
			if( IG.posInput("Velocity", data.velocity) )
			{
				rebuildLevel();
			}

			var c = Vector.fromColor( data.fogColor );
			var color = new hl.NativeArray<Single>(4);
			color[0] = c.r;
			color[1] = c.g;
			color[2] = c.b;
			color[3] = c.a;
			var flags = ImGuiColorEditFlags.AlphaBar | ImGuiColorEditFlags.AlphaPreview
					| ImGuiColorEditFlags.DisplayRGB | ImGuiColorEditFlags.DisplayHex
					| ImGuiColorEditFlags.AlphaPreviewHalf;
			if( IG.wref( ImGui.colorPicker4( "Fog Color", _, flags), color ) )
			{
				c.set(color[0], color[1], color[2], color[3] );
				data.fogColor = c.toColor();
			}

		}

		ImGui.end();
	}

	function rebuildLevel()
	{
		@:privateAccess level.rebuild();
	}

	function inspector()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		if( ImGui.begin('Inspector##${windowID()}' ) )
		{
			switch(inspectMode)
			{
				case None:
				case Sprite:
					ImGui.text("Sprite inspector");
					ImGui.separator();
					var newSprite = IG.textInput( "Sprite", selectedSprite.sprite );
					if( newSprite != null && hxd.Res.loader.exists( newSprite ) )
					{
						selectedSprite.sprite = newSprite;
						@:privateAccess level.rebuild();
					}

					if( ImGui.beginDragDropTarget() )
					{
						var payload = ImGui.acceptDragDropPayloadString("asset_name");
						if( payload != null && hxd.Res.loader.exists( payload ) )
						{
							selectedSprite.sprite =payload;
							@:privateAccess level.rebuild();
						}
						ImGui.endDragDropTarget();
					}

					ImGui.text('Spawn group: ${ selectedSprite.spawnGroup == 0 ? "None" : ""+selectedSprite.spawnGroup }');
					ImGui.sameLine();
					if( selectedSprite.spawnGroup != 0 )
					{
						ImGui.sameLine();
						if( ImGui.button("\uf057" ) )
							selectedSprite.spawnGroup = 0;
					}
					else
					{
						ImGui.sameLine();
						if( ImGui.button("\uf0a4" ) )
						{
							selectMode = AssignSpawnGroup;
						}
					}


					if( IG.posInput("Spawn Position", selectedSprite.position, "%.2f") )
					{
						@:privateAccess level.rebuild();
					}
					var val = IG.textInputMultiline("Fiber", selectedSprite.fiber, null, ImGuiInputTextFlags.Multiline);
					if( val != null )
					{
						selectedSprite.fiber = val;
					}
					if( ImGui.beginDragDropTarget() )
					{
						var targetFlags : ImGuiDragDropFlags = 0;

						var payload = ImGui.acceptDragDropPayloadString("fiber");
						if( payload != null )
						{
							selectedSprite.fiber = payload;
						}

						ImGui.endDragDropTarget();
					}

					IG.posInput("Velocity", selectedSprite.speed, "%.2f");
					IG.posInput("Acceleration", selectedSprite.acceleration, "%.2f");

					if( ImGui.button("Delete") )
					{
						data.sprites.remove(selectedSprite );
						selectedSprite = null;
						inspectMode = None;
						@:privateAccess level.rebuild();
					}

					if( ImGui.button("Duplicate") )
					{
						var ns: CBLObject = {
							sprite: selectedSprite.sprite,
							position: {x: selectedSprite.position.x, y: selectedSprite.position.y},
							fiber: selectedSprite.fiber,
							rotation: selectedSprite.rotation,
							speed: {x: selectedSprite.speed.x, y: selectedSprite.speed.y},
							acceleration: {x: selectedSprite.acceleration.x, y: selectedSprite.acceleration.y},
							spawnGroup: selectedSprite.spawnGroup,
						}
						data.sprites.push(ns );
						selectedSprite = ns;
						ns.position.y -= 100;
						@:privateAccess level.rebuild();
					}


				case Trigger:
					ImGui.text("Trigger inspector");
					ImGui.separator();
					IG.posInput("Trigger Position", selectedTrigger.position, "%.2f");

					if( ImGui.beginCombo( "Type", selectedTrigger.type.toString() ) )
					{
						if( ImGui.selectable("None", selectedTrigger.type == None) ) selectedTrigger.type = None;
						if( ImGui.selectable("Pause until clear", selectedTrigger.type == PauseForClear) ) selectedTrigger.type = PauseForClear;
						if( ImGui.selectable("Change Velocity", selectedTrigger.type == ChangeVelocity) ) selectedTrigger.type = ChangeVelocity;
						if( ImGui.selectable("Dialogue", selectedTrigger.type == Dialogue) ) selectedTrigger.type = Dialogue;
						if( ImGui.selectable("End Level", selectedTrigger.type == LevelEnd) ) selectedTrigger.type = LevelEnd;

						ImGui.endCombo();
					}

					switch(  selectedTrigger.type )
					{
						case ChangeVelocity:
							IG.posInput("New Velocity", selectedTrigger.data, "%.2f");
						case PauseForClear:
						case Dialogue:
							var n = Math.floor( selectedTrigger.data.x );
							if( IG.wref( ImGui.inputInt( "ID", _ ), n ) )
							{
								selectedTrigger.data.x = n;
							}
						default:
					}

					if( ImGui.button("Delete") )
					{
						data.triggers.remove(selectedTrigger );
						selectedTrigger = null;
						inspectMode = None;
						@:privateAccess level.rebuild();
					}


				case SpawnGroup:
					ImGui.text("Spawn Group inspector");
					ImGui.separator();
					IG.posInput("Spawn Position", selectedGroup.position, "%.2f");
					ImGui.text('ID: ${selectedGroup.id}');

					if( ImGui.button("Delete") )
					{
						data.spawnGroups.remove(selectedGroup );
						selectedGroup = null;
						inspectMode = None;
						@:privateAccess level.rebuild();
					}

				case Mesh:
					ImGui.text("Mesh inspector");
					ImGui.separator();
					if( IG.posInput("Position", selectedMesh.position, "%.2f") )
					{
						@:privateAccess level.rebuild();
					}
					var single: Single = selectedMesh.rotation;
					if( IG.wref( ImGui.sliderAngle("Rotation", _), single ) )
					{
						selectedMesh.rotation = single;
						@:privateAccess level.rebuild();
					}

					if( ImGui.button("Delete") )
					{
						data.meshes.remove(selectedMesh );
						selectedMesh = null;
						inspectMode = None;
						@:privateAccess level.rebuild();
					}

			}

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

		for( k => v in fiberList )
		{
			if( ImGui.button(k) )
			{
				selectedFiber = k;
			}
			if( ImGui.beginDragDropSource() )
			{
				ImGui.setDragDropPayloadString( "fiber", v );
				ImGui.beginTooltip();
				ImGui.text(v);
				ImGui.endTooltip();

				ImGui.endDragDropSource();
			}
		}


		ImGui.end();


	}

	public override function windowID()
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
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.30, null, idOut);
			dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.20, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}

	function getNewSpawnGroupID(): Int
	{
		var id = 0;
		var found = false;
		do
		{
			id++;
			found=false;
			for( g in data.spawnGroups )
			{
				if( g.id == id )
				{
					found = true;
					break;
				}
			}
		}
		while( found == true );

		return id;
	}
}

#end