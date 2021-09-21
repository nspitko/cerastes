
package cerastes.tools;

import hxd.res.Atlas;
import cerastes.Sprite.SpriteCache;
import hxd.Key;
import cerastes.fmt.SpriteResource;
import org.si.cml.CMLObject;
import org.si.cml.CMLFiber;
import cerastes.tools.ImguiTool.ImguiToolManager;
import hl.UI;
import haxe.Json;
import cerastes.tools.ImguiTools.IG;
#if cannonml
import h3d.mat.Texture;
import hxd.res.Loader;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;

import cerastes.bulletml.BulletManager;
import cerastes.bulletml.CannonBullet;


enum SpriteInspectorMode {
	NONE;
	ANIMATION;
	FRAME;
}

@:keep
class SpriteEditor extends ImguiTool
{

	var viewportWidth: Int;
	var viewportHeight: Int;

	var preview: h2d.Scene;
	var sceneRT: Texture;
	var sceneRTId: Int;

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdBottom: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var seed: CMLFiber;

	var spriteDef: CSDDefinition;
	var selectedAnimation: CSDAnimation;
	var selectedFrame: CSDFrame;
	var inspectorMode: SpriteInspectorMode = NONE;

	var cache: SpriteCache;
	var sprite: Sprite;

	var scaleFactor = Utils.getDPIScaleFactor();
	var spriteScale: Int = 8;

	var fileName = "";


	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");
		viewportWidth = 640;
		viewportHeight = 360;

		if( size != null )
		{
			var p = size.split("x");
			viewportWidth = Std.parseInt(p[0]);
			viewportHeight = Std.parseInt(p[1]);
		}

		// ???? hacky shit. We really want to just dynamically size this for our sprite
		viewportWidth = cast viewportWidth;
		viewportHeight = cast  viewportHeight;

		preview = new h2d.Scene();
		preview.scaleMode = Stretch(viewportWidth,viewportHeight);

		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );


		updateScene();

		// Testing
		openFile("spr/test.csd");


	}


	public function openFile(f: String )
	{
		fileName = f;

		var res = hxd.Res.load( f ).to(SpriteResource);
		spriteDef = res.getData(false).sprite;
		sprite = res.toSprite( preview );

		// Build a custom cache for this sprite instance
		cache = new SpriteCache( spriteDef );
		@:privateAccess sprite.cache = cache;

		selectedAnimation = spriteDef.animations.length > 0 ? spriteDef.animations[0] : null;
		sprite.play(selectedAnimation.name);

		updateSprite();
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
		if( sprite == null )
			return;

		if( sprite.currentAnimation != selectedAnimation.name )
		{
			sprite.play( selectedAnimation.name );
		}
	}

	function selectAnimation( newAnimation: CSDAnimation )
	{
		selectedAnimation = newAnimation;
		selectedFrame = null;
		inspectorMode = ANIMATION;
	}

	function selectFrame( newFrame: CSDFrame )
	{
		selectedFrame = newFrame;
		inspectorMode = FRAME;
	}

	function rebuildCache()
	{
		@:privateAccess cache.build();
		sprite.play( selectedAnimation != null ? selectedAnimation.name : spriteDef.animations[0].name );
	}

	function updateSprite()
	{

		var bounds = sprite.getBounds();

		//preview.width = bounds.width;
		//preview.height = bounds.height;
		preview.scaleMode = Stretch(cast bounds.width,cast bounds.height);

		sceneRT.resize(cast bounds.width, cast bounds.height);

		//s.x = 0;// Math.floor( preview.width / 2 - bounds.width / 2 );
		//s.y = 0;//Math.floor( preview.height / 2 - bounds.height / 2 );
	}

	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: viewportWidth * 2.3, y: viewportHeight * 2.4}, ImGuiCond.Once);
		ImGui.begin('\uf6be Sprite Editor', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview###${windowID()}_preview');
		var windowSize: ImVec2 = cast ImGui.getWindowSize();
		ImGui.setCursorPos({x: ( windowSize.x - (preview.width * spriteScale) ) * 0.5, y: ( windowSize.y - (preview.height * spriteScale) ) * 0.5} );
		ImGui.image(sceneRT, { x: preview.width * spriteScale, y: preview.height * spriteScale } );

		if( ImGui.isWindowHovered() )
		{
			// Should use imgui events here for consistency but GetIO isn't exposed to hl sooo...
			if (Key.isPressed(Key.MOUSE_WHEEL_DOWN))
			{
				spriteScale--;
				if( spriteScale <= 0 )
					spriteScale = 1;
			}
			if (Key.isPressed(Key.MOUSE_WHEEL_UP))
			{
				spriteScale++;
				if( spriteScale > 20 )
					spriteScale = 20;
			}


		}

		ImGui.end();

		// Windows
		settingsWindow();
		listWindow();
		animationWindow();
		tileWindow();
		inspectorWindow();

		updateScene();


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

				if ( ImGui.menuItem("Save", "Ctrl+S"))
				{
					// @TODO
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


	function settingsWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Settings');

		ImGui.end();
	}

	function listWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Animations');

		ImGui.beginChild("AnimationsList",null,false, ImGuiWindowFlags.AlwaysAutoResize );

		if( spriteDef != null )
		{
			for( i  in 0 ... spriteDef.animations.length )
			{
				var animation = spriteDef.animations[i];

				var flags = ImGuiTreeNodeFlags.Leaf;
				if( animation == selectedAnimation )
					flags |= ImGuiTreeNodeFlags.Selected;
				var isOpen = ImGui.treeNodeEx( animation.name, flags );

				if( isOpen )
					ImGui.treePop();


				if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
				{
					selectAnimation( animation );
					ImGui.openPopup('${spriteDef.name}_rc');
				}
				if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
				{
					selectAnimation( animation );
					//updateSelectedSprite();
				}

				if( ImGui.beginPopup('${spriteDef.name}_rc') )
				{
					if( ImGui.menuItem("Rename") )
					{
						ImGui.openPopup('${windowID()}_rc_rename');
					}
					if( ImGui.menuItem("Make Default") )
					{
						// @todo
					}
					if( ImGui.menuItem("Delete") )
					{
						ImGui.openPopup('${windowID()}_rc_delete');
					}
					ImGui.endPopup();
				}



			}
		}
		ImGui.endChild();

		ImGui.end();
	}

	function tileWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		ImGui.begin('Frames');

		var itemHeight = 140 * scaleFactor;
		ImGui.beginChild("frame_list", null, true, ImGuiWindowFlags.AlwaysAutoResize);



		var desiredW = 100 * scaleFactor;

		if( spriteDef != null && selectedAnimation != null )
		{
			var tileCache = cache.frameCache[ selectedAnimation.name ];

			for( i in 0 ... selectedAnimation.frames.length )
			{
				if( i >= selectedAnimation.frames.length ) break; // Loop variable cannot be modified :thonk:

				var tile = tileCache[i];
				var frame = selectedAnimation.frames[i];

				var scale = Math.floor( desiredW / tile.width  );
				var selected = selectedFrame == frame;


				if( selected )
				{
					var col= ImGui.getStyleColorVec4( ImGuiCol.ButtonActive );
					ImGui.pushStyleColor2(ImGuiCol.ChildBg, col );
				}

				ImGui.beginChild('frame_${frame.tile}_${i}',{ x: desiredW, y: itemHeight});


				IG.image( tile, {x: scale, y: scale} );
				ImGui.text( frame.tile );
				ImGui.text( '${frame.duration * 100}ms' );

				ImGui.endChild();

				// Drag drop frame insertion
				if( ImGui.beginDragDropTarget( ) )
				{
					var payload = ImGui.acceptDragDropPayloadString("atlas_tile");
					if( payload != null )
					{
						var bits = payload.split('|');
						Utils.assert(bits.length == 2, "Weird drag drop payload...");

						if( bits.length >= 2 && bits[0] == selectedAnimation.atlas )
						{
							var tileToInsert = bits[1];
							var mousePos: ImVec2 = cast ImGui.getMousePos();
							var cursorPos: ImVec2 = cast ImGui.getCursorScreenPos();
							if( mousePos.x - desiredW / 2 < cursorPos.x )
							{
								insertFrame(tileToInsert, i, frame.duration);
							}
							else
							{
								insertFrame(tileToInsert, i + 1, frame.duration);
							}
						}
					}
					ImGui.endDragDropTarget();
				}

				// Selection
				if( ImGui.isItemClicked(ImGuiMouseButton.Left ) )
				{
					selectFrame( frame );
				}

				// Context menu handler
				if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
				{
					selectFrame( frame );
					ImGui.openPopup('frame_${i}_context');
				}

				// Context menu
				if( ImGui.beginPopup('frame_${i}_context') )
				{
					if( ImGui.menuItem("Delete") )
					{
						selectedAnimation.frames.splice(i,1);
						rebuildCache();
					}
					ImGui.endPopup();
				}

				if( selected )
					ImGui.popStyleColor();


				ImGui.sameLine();

			}
		}

		ImGui.endChild();

		ImGui.end();
	}

	function insertFrame(tile: String, position: Int, duration: Float )
	{
		selectedAnimation.frames.insert(position,{
			tile: tile,
			duration: duration,
			offsetY: 0,
			offsetX: 0
		});

		rebuildCache();
	}

	function animationWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		ImGui.begin('Playback');

		ImGui.end();
	}

	function inspectorWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector');

		switch( inspectorMode )
		{
			case ANIMATION:
				var newAtlas = IG.textInput( "Atlas", selectedAnimation.atlas );
				if( newAtlas != null && hxd.Res.loader.exists( newAtlas ) )
				{
					selectedAnimation.atlas = newAtlas;
					rebuildCache();
				}


			case FRAME:
				var newTile = IG.textInput( "Tile", selectedFrame.tile );
				if( newTile != null )
				{
					var atlas = hxd.Res.load( selectedAnimation.atlas ).to(Atlas);
					if( atlas.get( newTile ) != null )
					{
						selectedFrame.tile = newTile;
						rebuildCache();
					}
				}

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("atlas_tile");
					if( payload != null )
					{
						var bits = payload.split('|');
						Utils.assert(bits.length == 2, "Weird drag drop payload...");

						if( bits.length >= 2 && bits[0] == selectedAnimation.atlas )
						{
							trace(payload);
							selectedFrame.tile = bits[1];
							rebuildCache();
						}
					}
					ImGui.endDragDropTarget();
				}

				IG.wref( IG.inputDouble("Duration (ms)", _, 0.01, 0.1, "%.3f"), selectedFrame.duration );
				IG.wref( IG.inputDouble("Offset X", _, 1, 10, "%.2f"),  selectedFrame.offsetX);
				IG.wref( IG.inputDouble("Offset Y", _, 1, 10, "%.2f"), selectedFrame.offsetY);



			case NONE:

		}

		ImGui.end();
	}

	inline function windowID()
	{
		return 'spre';
	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = windowID();

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut: hl.Ref<ImGuiID> = dockspaceId;

			dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.40, null, idOut);
			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.30, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.30, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}
}

#end