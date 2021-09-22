
package cerastes.tools;

import h2d.Graphics;
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
	ATTACHMENT;
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
	var selectedAttachment: CSDAttachment;
	var inspectorMode: SpriteInspectorMode = NONE;

	var cache: SpriteCache;
	var sprite: Sprite;

	var scaleFactor = Utils.getDPIScaleFactor();
	var spriteScale: Int = 8;

	var fileName = "";

	var tmpInput = "";

	// visual stuff
	var attachmentPreview: Graphics;


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

		// minimial non-null sprite def
		spriteDef = {
			name:"undefined",
			animations: [
				{
					name:"idle",
					atlas: "",
					frames: [],
					tags: [],
					sounds: [],
					attachmentOverrides: []
				}
			],
			attachments: []
		}

		updateScene();

		// Testing
		openFile("spr/test.csd");

		attachmentPreview = new Graphics(sprite);


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

		if( sprite.parent == null && selectedAnimation.frames.length > 0 )
		{
			preview.addChild(sprite);
			updateSprite();
		}

		attachmentPreview.clear();
		if( selectedAttachment != null && inspectorMode == ATTACHMENT )
		{
			attachmentPreview.lineStyle(1, 0xFF0000 );
			attachmentPreview.drawCircle( selectedAttachment.position.x, selectedAttachment.position.y, 5 );
			attachmentPreview.lineStyle(1, 0x0000FF );
			attachmentPreview.moveTo( selectedAttachment.position.x, selectedAttachment.position.y );
			var endX = selectedAttachment.position.x + Math.cos( selectedAttachment.rotation ) * 10;
			var endY = selectedAttachment.position.y + Math.sin( selectedAttachment.rotation ) * 10;
			attachmentPreview.lineTo(endX,endY);
		}

	}

	function selectAnimation( newAnimation: CSDAnimation )
	{
		selectedAnimation = newAnimation;
		selectedFrame = null;
		inspectorMode = ANIMATION;

		if( selectedAnimation.frames.length == 0 )
			preview.removeChild(sprite);
	}

	function selectFrame( newFrame: CSDFrame )
	{
		selectedFrame = newFrame;
		inspectorMode = FRAME;
	}

	function selectAttachment( newAttachment: CSDAttachment )
	{
		selectedAttachment = newAttachment;
		inspectorMode = ATTACHMENT;
	}

	function rebuildCache()
	{
		@:privateAccess cache.build();
		if( selectedAnimation != null )
			sprite.play( selectedAnimation.name );
		else if( spriteDef.animations.length > 0 )
			sprite.play( spriteDef.animations[0].name );
	}


	function updateSprite()
	{

		var bounds = sprite.getBounds();

		//preview.width = bounds.width;
		//preview.height = bounds.height;
		//preview.scaleMode = Stretch(cast bounds.width,cast bounds.height);

		//sceneRT.resize(cast bounds.width, cast bounds.height);

		sprite.x =  Math.floor( preview.width / 2 - bounds.width / 2 );
		sprite.y = Math.floor( preview.height / 2 - bounds.height / 2 );
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
		ImGui.begin('Preview###${windowID()}_preview', null, ImGuiWindowFlags.NoScrollWithMouse | ImGuiWindowFlags.NoScrollbar);
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
		ImGui.begin('Outline');

		ImGui.text("Animations");
		//ImGui.beginChild("AnimationsList",null, true );


		for( i  in 0 ... spriteDef.animations.length )
		{
			var animation = spriteDef.animations[i];

			ImGui.pushID('animlist_${animation.name}');

			var flags = ImGuiTreeNodeFlags.Leaf;
			if( animation == selectedAnimation )
				flags |= ImGuiTreeNodeFlags.Selected;
			var isOpen = ImGui.treeNodeEx( animation.name, flags );

			if( isOpen )
				ImGui.treePop();


			if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
			{
				selectAnimation( animation );
				ImGui.openPopup('context');
			}
			if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
			{
				selectAnimation( animation );
				//updateSelectedSprite();
			}

			if( ImGui.beginPopup('context') )
			{
				if( ImGui.menuItem("Rename") )
				{
					ImGui.openPopup('animation_rename');
				}
				if( ImGui.menuItem("Make Default") )
				{
					// @todo
				}
				if( ImGui.menuItem("Delete") )
				{
					ImGui.openPopup('animation_delete');
				}
				ImGui.endPopup();
			}

			ImGui.popID();

		}

		//ImGui.endChild();
		if( ImGui.button("Add Animation") )
		{
			tmpInput = "";
			ImGui.openPopup("Add Animation");
		}

		ImGui.separator();

		ImGui.text("Attachments");
		//ImGui.beginChild("AttachmentsList",null, true);


		for( i  in 0 ... spriteDef.attachments.length )
		{

			var attachment = spriteDef.attachments[i];
			ImGui.pushID('atlist_${attachment.name}');

			var flags = ImGuiTreeNodeFlags.Leaf;
			if( attachment == selectedAttachment )
				flags |= ImGuiTreeNodeFlags.Selected;
			var isOpen = ImGui.treeNodeEx( attachment.name, flags );

			if( isOpen )
				ImGui.treePop();


			if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
			{
				selectAttachment( attachment );
				ImGui.openPopup('context');
			}
			if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
			{
				selectAttachment( attachment );
			}

			if( ImGui.beginPopup('context') )
			{
				if( ImGui.menuItem("Rename") )
				{
					ImGui.openPopup('attachment_rename');
				}
				if( ImGui.menuItem("Delete") )
				{
					ImGui.openPopup('attachment_delete');
				}
				ImGui.endPopup();
			}

			ImGui.popID();



		}
		//ImGui.endChild();
		if( ImGui.button("Add Attachment") )
		{
			ImGui.openPopup("Add Attachment");
		}

		var isOpen = true;
		var closeRef = hl.Ref.make(isOpen);

		if( ImGui.beginPopupModal("Add Animation", closeRef) )
		{
			var r = IG.textInput("Name", tmpInput);
			if( r != null )
				tmpInput = r;

			if( ImGui.button("Add") )
			{
				var baseAnim = spriteDef != null && spriteDef.animations.length > 0 ? spriteDef.animations[0] : null;
				var a: CSDAnimation = {
					name: tmpInput,
					atlas: baseAnim != null ? baseAnim.atlas : "",
					frames: [],
					tags: [],
					sounds: [],
					attachmentOverrides: [],

				}
				spriteDef.animations.push(a);
				ImGui.closeCurrentPopup();
			}

			ImGui.sameLine();

			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}


			ImGui.endPopup();
		}

		if( ImGui.beginPopupModal('Really delete ${selectedAnimation.name}?###animation_delete', closeRef) )
		{
			ImGui.text("This can't be undone since I'm too lazy to add proper undo support.");
			ImGui.separator();

			if( spriteDef.animations.length == 1 )
			{
				ImGui.text("Can't delete the last animation in a sprite. All sprites must have at least 1 animation, even if it's only a single frame");
			}
			else
			{

				if( ImGui.button("Ok") )
				{
					var idx = 0;
					for( i in 0 ... spriteDef.animations.length )
					{
						if( spriteDef.animations[i] == selectedAnimation )
						{
							idx = i; break;
						}
					}
					selectedAnimation = null;
					spriteDef.animations.splice(idx, 1);
					rebuildCache();
					ImGui.closeCurrentPopup();
				}

				ImGui.sameLine();

				if( ImGui.button("Cancel") )
				{
					ImGui.closeCurrentPopup();
				}
			}


			ImGui.endPopup();
		}

		if( ImGui.beginPopupModal("Add Attachment", closeRef) )
		{
			var r = IG.textInput("Name", tmpInput);
			if( r != null )
				tmpInput = r;

			if( ImGui.button("Add") )
			{
				var a: CSDAttachment = {
					name: tmpInput,
					position: {x: 0, y: 0},
					rotation: 0,

				}
				spriteDef.attachments.push(a);
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

	function tileWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		ImGui.begin('Frames');

		var itemHeight = 140 * scaleFactor;
		ImGui.beginChild("frame_list", null, true, ImGuiWindowFlags.AlwaysAutoResize);



		var desiredW = 100 * scaleFactor;
		var handledDrop = false;

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
							handledDrop = true;
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

		if( !handledDrop && ImGui.beginDragDropTarget( ) )
		{
			var payload = ImGui.acceptDragDropPayloadString("atlas_tile");
			if( payload != null )
			{
				var bits = payload.split('|');
				Utils.assert(bits.length == 2, "Weird drag drop payload...");

				if( selectedAnimation.atlas == "" )
					selectedAnimation.atlas = bits[0];

				if( bits.length >= 2 && bits[0] == selectedAnimation.atlas )
				{
					var tileToInsert = bits[1];
					insertFrame(tileToInsert, selectedAnimation.frames.length, 0.33);
				}
			}
			ImGui.endDragDropTarget();
		}

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
				ImGui.text("Animation settings");
				ImGui.separator();
				var newAtlas = IG.textInput( "Atlas", selectedAnimation.atlas );
				if( newAtlas != null && hxd.Res.loader.exists( newAtlas ) )
				{
					selectedAnimation.atlas = newAtlas;
					rebuildCache();
				}


			case FRAME:
				ImGui.text("Frame settings");
				ImGui.separator();
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
							selectedFrame.tile = bits[1];
							rebuildCache();
						}
					}
					ImGui.endDragDropTarget();
				}

				IG.wref( IG.inputDouble("Duration (ms)", _, 0.01, 0.1, "%.3f"), selectedFrame.duration );
				IG.wref( IG.inputDouble("Offset X", _, 1, 10, "%.2f"),  selectedFrame.offsetX);
				IG.wref( IG.inputDouble("Offset Y", _, 1, 10, "%.2f"), selectedFrame.offsetY);


			case ATTACHMENT:
				ImGui.text("Attachment settings");
				ImGui.separator();
				IG.posInput("Offset", selectedAttachment.position, "%.2f");
				var single: Single = selectedAttachment.rotation;
				if( IG.wref( ImGui.sliderAngle("Rotation", _), single ) )
					selectedAttachment.rotation = single;

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Ctrl+click to manually set");
					ImGui.endTooltip();
				}



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