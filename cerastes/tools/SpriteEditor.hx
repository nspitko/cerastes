
package cerastes.tools;

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
	var dockspaceIdBottom: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var seed: CMLFiber;

	var resource: SpriteResource;

	var selectedSprite: CSDDefinition;
	var selectedAnimation: Int = -1;

	var cache: SpriteCache;
	var sprite: Sprite;

	var scaleFactor = Utils.getDPIScaleFactor();
	var spriteScale: Int = 8;

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

		resource = hxd.Res.load( "data/sprites.csd" ).to( SpriteResource );

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

	}

	function updateSelectedSprite()
	{
		preview.removeChildren();

		selectedAnimation = 0;

		// Use our own local cache, since we'll be fiddling with things a lot
		cache = new SpriteCache( selectedSprite );
		sprite = new Sprite(cache, preview);

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
		ImGui.begin('Sprites');

		ImGui.beginChild("SpriteList",{x:300,y:400},false );
		for( spriteDef in resource.getData().sprites )
		{
			var flags = ImGuiTreeNodeFlags.Leaf;
			if( spriteDef == selectedSprite )
				flags |= ImGuiTreeNodeFlags.Selected;
			var isOpen = ImGui.treeNodeEx( spriteDef.name, flags );

			if( isOpen )
				ImGui.treePop();


			if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
			{
				selectedSprite = spriteDef;
				ImGui.openPopup('${spriteDef.name}_rc');
			}
			if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
			{
				selectedSprite = spriteDef;
				updateSelectedSprite();
			}

			if( ImGui.beginPopup('${spriteDef.name}_rc') )
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

		ImGui.end();
	}

	function tileWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		ImGui.begin('Frames');

		var itemHeight = 140 * scaleFactor;
		ImGui.beginChild("frame_list", {x: 700 * scaleFactor, y: itemHeight});

		var desiredW = 100 * scaleFactor;

		if( selectedSprite != null && selectedAnimation < selectedSprite.animations.length )
		{
			var anim = selectedSprite.animations[selectedAnimation];
			var tileCache = cache.frameCache[ anim.name ];

			trace(anim.frames.length);



			for( i in 0 ... anim.frames.length )
			{
				var tile = tileCache[i];
				var frame = anim.frames[i];

				var scale = Math.floor( desiredW / tile.width  );

				ImGui.beginChild('frame_${frame.tile}_${i}',{ x: desiredW, y: itemHeight});

				IG.image( tile, {x: scale, y: scale} );
				ImGui.text( frame.tile );
				ImGui.text( '${frame.duration * 100}ms' );

				ImGui.endChild();
				ImGui.sameLine();

			}
		}

		ImGui.endChild();

		ImGui.end();
	}

	function animationWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		ImGui.begin('Playback');

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

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.30, null, idOut);
			dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.40, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}
}

#end