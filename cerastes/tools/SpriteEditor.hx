
package cerastes.tools;
#if hlimgui
#if spritemeta
import hl.NativeArray;
import hl.Ref;
import cerastes.macros.SpriteData;
import cerastes.macros.Metrics;


import h2d.Graphics;
import hxd.res.Atlas;
import cerastes.Sprite.SpriteCache;
import hxd.Key;
import cerastes.fmt.SpriteResource;
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

import imgui.ImGuiMacro.wref;


enum SpriteInspectorMode {
	NONE;
	ANIMATION;
	FRAME;
	ATTACHMENT;
	COLLIDER;
	ATTACHMENTOVERRIDE;
	SOUND;
	TAG;
}

@:structInit
class BarReservation
{
	public var min: Float;
	public var max: Float;
}


@:keep
@multiInstance(true)
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

	var spriteDef: CSDDefinition;
	var selectedAnimation: CSDAnimation;
	var selectedFrame: CSDFrame;
	var selectedAttachment: CSDAttachment;
	var selectedCollider: CSDCollider;

	var selectedAttachmentOverride: CSDAttachmentOverride;
	var selectedSound: CSDSound;
	var selectedTag: CSDTag;


	var inspectorMode: SpriteInspectorMode = NONE;

	var cache: SpriteCache;
	var sprite: Sprite;

	var scaleFactor = Utils.getDPIScaleFactor();
	var spriteScale: Int = 4;

	/// preview
	var drawAttachments = false;
	var drawColliders = false;
	var playAudio = false;


	/// Timeline
	var timelineZoom: Float = 1;
	var fileName = "";
	var tmpInput = "";

	// visual stuff
	var graphics: Graphics;
	var drawOrigin: Bool = false;


	public function new()
	{
		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;

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
			attachments: [],
			colliders: [],
			typeData: [],
			origin: {x: 0, y: 0},
		}

		updateScene();

		// Testing
		openFile("spr/test.csd");

		graphics = new Graphics(sprite);


	}


	public function openFile(f: String )
	{
		fileName = f;

		var res = hxd.Res.load( fileName ).to(SpriteResource);
		spriteDef = res.getData(false).sprite;
		cache = new SpriteCache( spriteDef );
		@:privateAccess cache.build();

		rebuildSprite();

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

		if( selectedAnimation != null && sprite.currentAnimation != selectedAnimation.name )
		{
			sprite.play( selectedAnimation.name );
		}

		if( sprite.parent == null && selectedAnimation.frames.length > 0 )
		{
			preview.addChild(sprite);
			updateSprite();
		}

		graphics.clear();
		for( a in spriteDef.attachments )
		{
			if( ( a == selectedAttachment && inspectorMode == ATTACHMENT ) || drawAttachments )
			{
				var color = a == selectedAttachment && inspectorMode == ATTACHMENT ? 0x33AA33 : 0x3333AA;
				var colorRot = a == selectedAttachment && inspectorMode == ATTACHMENT ? 0x99FF99 : 0x6666FF;
				var spriteAttachment = sprite.getAttachment( a.name );
				var bounds = spriteAttachment.getBounds( sprite );
				graphics.lineStyle(1, color );
				graphics.drawCircle( bounds.x, bounds.y, 5 );
				graphics.lineStyle(1, colorRot );
				graphics.moveTo( bounds.x, bounds.y );
				var endX = bounds.x + Math.cos( spriteAttachment.rotation ) * 10;
				var endY = bounds.y + Math.sin( spriteAttachment.rotation ) * 10;
				graphics.lineTo(endX,endY);
			}
		}

		for( c in spriteDef.colliders )
		{
			if( ( selectedCollider != null && inspectorMode == COLLIDER ) || drawColliders )
			{
				var color = c == selectedCollider && inspectorMode == COLLIDER ? 0xAAAA44 : 0xAA44AA;
				graphics.lineStyle(1,color);
				switch( c.type )
				{
					case AABB:
						graphics.drawRect( c.position.x,c.position.y,c.size.x,c.size.y );
					case Circle:
						graphics.drawCircle(c.position.x, c.position.y, c.size.x);
					default:
				}
			}
		}

		if( drawOrigin )
		{
			var color = 0xFF8888;
			graphics.lineStyle(2,color);
			graphics.moveTo( spriteDef.origin.x - 5, spriteDef.origin.y );
			graphics.lineTo( spriteDef.origin.x + 5, spriteDef.origin.y );

			graphics.moveTo( spriteDef.origin.x, spriteDef.origin.y - 5 );
			graphics.lineTo( spriteDef.origin.x, spriteDef.origin.y + 5 );
		}
	}

	function selectAnimation( newAnimation: CSDAnimation )
	{
		selectedAnimation = newAnimation;
		selectedFrame = null;
		inspectorMode = ANIMATION;

		if( selectedAnimation.frames.length == 0 )
			sprite.remove();
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

	function selectCollider( newCollder: CSDCollider )
	{
		selectedCollider = newCollder;
		inspectorMode = COLLIDER;
	}

	function selectAttachmentOverride( newAttachmentOverride: CSDAttachmentOverride )
	{
		selectedAttachmentOverride = newAttachmentOverride;
		inspectorMode = ATTACHMENTOVERRIDE;
	}

	function selectSound( newSound: CSDSound )
	{
		selectedSound = newSound;
		inspectorMode = SOUND;
	}

	function selectTag( newTag: CSDTag )
	{
		selectedTag = newTag;
		inspectorMode = TAG;
	}

	function rebuildCache()
	{
		@:privateAccess cache.build();
		if( selectedAnimation != null )
			sprite.play( selectedAnimation.name );
		else if( spriteDef.animations.length > 0 )
			sprite.play( spriteDef.animations[0].name );
	}

	// More aggressive than rebuildCache()
	function rebuildSprite()
	{
		if( sprite != null )
			sprite.remove();

		var res = hxd.Res.load( fileName ).to(SpriteResource);
		sprite = res.toSprite( preview, cache );
		sprite.mute = !playAudio;
		// Build a custom cache for this sprite instance


		updateSprite();

		graphics = new Graphics(sprite);
	}


	function updateSprite()
	{

		var bounds = sprite.getBounds();
		var center = bounds.getCenter();

		//preview.width = bounds.width;
		//preview.height = bounds.height;
		//preview.scaleMode = Stretch(cast bounds.width,cast bounds.height);

		//sceneRT.resize(cast bounds.width, cast bounds.height);

		sprite.x =  Math.floor( preview.width / 2 - center.x );
		sprite.y = Math.floor( preview.height / 2 - center.y );
	}



	override public function update( delta: Float )
	{
		Metrics.begin();

		ImGui.pushID(windowID());
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		if( forceFocus )
		{
			forceFocus = false;
			ImGui.setNextWindowFocus();
		}
		ImGui.setNextWindowSize({x: viewportWidth * 2.3, y: viewportHeight * 2.4}, ImGuiCond.Once);
		ImGui.begin('\uf6be Sprite Editor (${fileName})##${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoScrollWithMouse | ImGuiWindowFlags.NoScrollbar);

		wref( ImGui.checkbox( "Draw colliders", _ ), drawColliders );
		ImGui.sameLine();
		wref( ImGui.checkbox( "Draw Attachments", _ ), drawAttachments );
		ImGui.sameLine();
		wref( ImGui.checkbox( "Play Audio", _ ), playAudio );
		sprite.mute = !playAudio;

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
			ImGuiToolManager.closeTool( this );
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
				if ( ImGui.menuItem("Save", "Ctrl+S"))
				{
					SpriteResource.write( spriteDef, fileName );
				}
				if ( ImGui.menuItem("Save As...", ""))
				{
					var newFile = UI.saveFile({
						title:"Save As...",
						filters:[
						{name:"Sprites", exts:["csd"]}
						]
					});
					if( newFile != null )
					{
						fileName = Utils.toLocalFile( newFile );
						SpriteResource.write( spriteDef, newFile );
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




	function settingsWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Settings##${windowID()}') )
		{
			// Fixup
			if( spriteDef.origin == null )
				spriteDef.origin = {x: 0, y: 0};
			if( IG.posInput("Origin", spriteDef.origin, "%.2f") )
			{
				rebuildSprite();
			}
			drawOrigin = ImGui.isItemFocused() || ImGui.isItemActive();


			var classList : Map<String,Array<SpriteDataItem>> = cerastes.SpriteMeta.getClassList();

			if( ImGui.beginCombo("Class", trimCls( spriteDef.type ) ) )
			{
				if( ImGui.selectable("None", spriteDef.type == null ) )	spriteDef.type = null;

				if( classList != null )
				{
					for(k => v in classList )
					{
						trace('$k -> $v');
						if( ImGui.selectable(trimCls( k ),	k == spriteDef.type ) )	spriteDef.type = k;
					}
				}

				ImGui.endCombo();
			}

			if( spriteDef.type != null && classList.exists( spriteDef.type ) )
			{
				ImGui.separator();
				var props = classList.get( spriteDef.type );

				for( p in props )
				{
					var kv = getKV( p.name );
					if( kv == null )
					{
						kv = {
							key: p.name,
							value: p.defaultValue
						};
						cache.spriteDef.typeData.push(kv);
					}


					switch( p.type )
					{
						case "Int":
							var staticVal: Int = cast(kv.value, Int);
							var ref = hl.Ref.make( staticVal );
							if( ImGui.inputInt( p.label, ref ) )
							{
								kv.value = ref.get();
								rebuildCache();
							}
						case "Float":
							var staticVal: Single = cast(kv.value, Single);
							var ref = hl.Ref.make( staticVal );
							if( ImGui.inputFloat( p.label, ref ) )
							{
								kv.value = ref.get();
								rebuildCache();
							}
						case "String":
							var staticVal: String = cast(kv.value, String);
							//var ref = hl.Ref.make( staticVal );
							var r = IG.textInput(p.label, staticVal);
							if( r != null )
								kv.value = r;

						default:
							ImGui.text( '${p.label} (${p.type}) UNSUPPORTED' );
					}

					if( p.tooltip != null && ImGui.isItemHovered() )
					{
						ImGui.beginTooltip();
						ImGui.text(p.tooltip);
						ImGui.endTooltip();
					}
				}


			}
		}


		ImGui.end();
	}

	function getKV(name: String ) : CSDKV
	{
		if( cache.spriteDef.typeData == null )
		{
			// Fixup
			cache.spriteDef.typeData = [];
			return null;
		}

		for( kv in cache.spriteDef.typeData)
		{
			if( kv.key == name )
				return kv;
		}

		return null;
	}

	inline function trimCls(string: String )
	{
		if( string == null ) return "None";
		if( StringTools.startsWith( string, "game.objects." ) ) return string.substr(13);
		return string;
	}

	function listWindow()
	{

		var isOpen = true;
		var closeRef = hl.Ref.make(isOpen);

		// Yeah, these kinda suck. My hand has been forced. https://github.com/ocornut/imgui/issues/331
		var showAnimationDeletePopup = false;
		var showAttachmentDeletePopup = false;
		var showColliderDeletePopup = false;

		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Outline##${windowID()}') )
		{


			// ============================================================================
			// Animations
			// ============================================================================

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
						showAnimationDeletePopup = true;
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

			if( showAnimationDeletePopup )
			{
				ImGui.openPopup("###animation_delete");
			}

			if( ImGui.beginPopupModal("Add Animation", null, ImGuiWindowFlags.AlwaysAutoResize ) )
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

			if( ImGui.beginPopupModal('Really delete ${selectedAnimation != null ? selectedAnimation.name : "NULL"}###animation_delete', null, ImGuiWindowFlags.AlwaysAutoResize ) )
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
						inspectorMode = NONE;
						selectedAnimation = null;
						spriteDef.animations.splice(idx, 1);
						rebuildCache();
						ImGui.closeCurrentPopup();
					}

					ImGui.sameLine();


				}
				if( ImGui.button("Cancel") )
				{
					ImGui.closeCurrentPopup();
				}


				ImGui.endPopup();
			}


			ImGui.separator();

			// ============================================================================
			// Attachments
			// ============================================================================

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
						showAttachmentDeletePopup = true;
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


			if( showAttachmentDeletePopup )
			{
				ImGui.openPopup("###attachment_delete");
			}


			if( ImGui.beginPopupModal("Add Attachment", null, ImGuiWindowFlags.AlwaysAutoResize ) )
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
						attachmentSprite: null,
						parent: null
					}
					spriteDef.attachments.push(a);
					rebuildSprite();
					ImGui.closeCurrentPopup();
				}

				ImGui.sameLine();

				if( ImGui.button("Cancel") )
				{
					ImGui.closeCurrentPopup();
				}


				ImGui.endPopup();
			}

			if( ImGui.beginPopupModal('Really delete ${selectedAttachment != null ? selectedAttachment.name : "NULL"}?###attachment_delete', closeRef) )
			{
				ImGui.text("This can't be undone since I'm too lazy to add proper undo support.");
				ImGui.separator();



				if( ImGui.button("Ok") )
				{
					var idx = 0;
					for( i in 0 ... spriteDef.attachments.length )
					{
						if( spriteDef.attachments[i] == selectedAttachment )
						{
							idx = i; break;
						}
					}
					inspectorMode = NONE;
					selectedAttachment = null;
					spriteDef.attachments.splice(idx, 1);
					rebuildSprite();
					ImGui.closeCurrentPopup();
				}

				ImGui.sameLine();

				if( ImGui.button("Cancel") )
				{
					ImGui.closeCurrentPopup();
				}



				ImGui.endPopup();
			}


			ImGui.separator();

			// ============================================================================
			// Colliders
			// ============================================================================

			ImGui.text("Colliders");

			for( i  in 0 ... spriteDef.colliders.length )
			{

				var collider = spriteDef.colliders[i];
				ImGui.pushID('collist_${i}');



				var name = '${collider.type.toString()} (${collider.position.x}, ${collider.position.y})';

				var flags = ImGuiTreeNodeFlags.Leaf;
				if( collider == selectedCollider )
					flags |= ImGuiTreeNodeFlags.Selected;
				var isOpen = ImGui.treeNodeEx( name, flags );

				if( isOpen )
					ImGui.treePop();


				if( ImGui.isItemClicked(ImGuiMouseButton.Right) )
				{
					selectCollider( collider );
					ImGui.openPopup('context');
				}
				if( ImGui.isItemClicked(ImGuiMouseButton.Left) )
				{
					selectCollider( collider );
				}

				if( ImGui.beginPopup('context') )
				{
					if( ImGui.menuItem("Delete") )
					{
						showColliderDeletePopup = true;
					}
					ImGui.endPopup();
				}

				ImGui.popID();
			}
			//ImGui.endChild();
			if( ImGui.button("Add Collider") )
			{
				var a: CSDCollider = {
					type: AABB,
					position: {x: 0, y: 0},
					size: {x: 10, y: 10},

				}
				spriteDef.colliders.push(a);
				rebuildSprite();
			}


			if( showColliderDeletePopup )
			{
				ImGui.openPopup("###collider_delete");
			}

			if( ImGui.beginPopupModal('Really delete this collider??###collider_delete', closeRef) )
			{
				ImGui.text("This can't be undone since I'm too lazy to add proper undo support.");
				ImGui.separator();



				if( ImGui.button("Ok") )
				{
					var idx = 0;
					for( i in 0 ... spriteDef.colliders.length )
					{
						if( spriteDef.colliders[i] == selectedCollider )
						{
							idx = i; break;
						}
					}
					inspectorMode = NONE;
					selectedCollider = null;
					spriteDef.colliders.splice(idx, 1);
					rebuildSprite();
					ImGui.closeCurrentPopup();
				}

				ImGui.sameLine();

				if( ImGui.button("Cancel") )
				{
					ImGui.closeCurrentPopup();
				}

				ImGui.endPopup();
			}
		}



		ImGui.end();


	}


	function tileWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		if( ImGui.begin('Frames##${windowID()}') )
		{

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
					if( tile == null ) continue;
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
					if( ImGui.isItemVisible() && ImGui.isItemClicked(ImGuiMouseButton.Left ) )
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


	var barReservations: Map<Int, Array<BarReservation>>;
	function tryReserve( res: BarReservation, depth: Int )
	{
		if( !barReservations.exists(depth) ) barReservations[depth] = [];
		for( r in barReservations[depth] )
		{
			// I swear there's a less dumb way to write this but my brain no worky
			if( res.max <= r.min || res.min >= r.max  )
				continue;

			return false;
		}

		barReservations[depth].push(res);

		return true;
	}

	// ============================================================================
	// Timeline
	// ============================================================================
	var lastFrameHeight: Float = 100;
	function animationWindow()
	{

		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		if( ImGui.begin('Timeline##${windowID()}') )
		{

			if( !sprite.pause )
			{
				if( ImGui.button("\uf04c") )
					sprite.pause = true;
			}
			else
			{
				if( ImGui.button("\uf04b") )
					sprite.pause = false;
			}

			ImGui.sameLine();
			if( ImGui.button( "\uf127 Add Attachment Override" ) ) { snapModal(); ImGui.openPopup("Add Attachment Override"); }
			ImGui.sameLine();
			if( ImGui.button( "\uf028 Add Sound Cue" ) ) { snapModal(); ImGui.openPopup("Add Sound Cue"); }
			ImGui.sameLine();
			if( ImGui.button( "\uf02b Add Tag" ) ) { snapModal(); ImGui.openPopup("Add Tag"); }

			//selectedAnimation = spriteDef.animations[0];
			if( selectedAnimation == null )
			{

				ImGui.end();
				return;
			}
			var rect: ImVec2 = ImGui.getWindowContentRegionMax();

			ImGui.beginChild("timeline", null, true, ImGuiWindowFlags.AlwaysAutoResize | ImGuiWindowFlags.HorizontalScrollbar | ImGuiWindowFlags.NoMove);

			if( ImGui.isWindowHovered() )
			{
				// Should use imgui events here for consistency but GetIO isn't exposed to hl sooo...
				if (Key.isPressed(Key.MOUSE_WHEEL_DOWN))
				{
					timelineZoom -= 0.2;
					if( timelineZoom < 1 )
						timelineZoom = 1;
				}
				if (Key.isPressed(Key.MOUSE_WHEEL_UP))
				{
					timelineZoom+= 0.2;
					if( timelineZoom > 100 )
						timelineZoom = 100;
				}


			}



			var sequenceLength: Float = 0;
			for( frame in selectedAnimation.frames )
				sequenceLength += frame.duration;


			//var p: ImVec2 = ImGui.getCursorPos();
			ImGui.setCursorPos({x:0,y:0});
			var lp: ImVec2 = ImGui.getCursorScreenPos();
			var tScale = timelineZoom * ( rect.x / sequenceLength );
			var padding: ImVec2 = {x: 5, y: 5};

			ImGui.dummy({x: rect.x * timelineZoom + padding.x * 2, y:100 + padding.y * 2});


			var drawList = ImGui.getWindowDrawList();
			//
			//drawList.addRect( lp, { x: lp.x + rect.x, y: lp.y + rect.y }, 0xFFFFFFFF );
			var scrollX = ImGui.getScrollX();
			var contentRect : ImVec2 = ImGui.getWindowContentRegionMax();
			var maxX = contentRect.x;
			var maxY = contentRect.y - 60;

			//drawList.addRect( { x: lp.x + scrollX, y: lp.y }, { x: lp.x + scrollX + maxX - 50, y: lp.y + rect.y - 50 }, 0xFFFFFFFF );


			// Draw timeline labels
			var tickFreq = 150;
			var tickHeight = lastFrameHeight;
			for( tickx in 0 ... Math.floor( ( rect.x / tickFreq )  * timelineZoom ) )
			{

				var x = tickx * tickFreq; // pixel value
				var ms = ( x / tScale );
				drawList.addLine( {x: x + lp.x, y: lp.y}, {x: x+lp.x, y: lp.y + tickHeight }, 0xFF333333  );

				ImGui.setCursorPos({x:x , y:tickHeight});
				ImGui.text('${Math.floor( ms * 1000 ) }ms');
			}

			var rows = 0;


			// Draw each frame
			var frameTime = 0.;
			var frameY = 5 + padding.y;
			var frameHeight = 20 * scaleFactor;
			var c: ImVec4 = { x: 0.7, y: 0.5, z: 0.1, w: 1.0 };
			var ci = IG.imVec4ToColor( c );

			rows = 0;
			barReservations = [];


			for( f in selectedAnimation.frames )
			{
				var row = 0;
				while( !tryReserve({min: frameTime, max: frameTime + f.duration }, row ) ) row++;
				var startPos = frameTime * tScale;
				var endPos = (frameTime + f.duration) * tScale;
				var width = endPos - startPos;
				var sel = function(){ selectFrame(f); }
				var rc = function(){ selectFrame(f); ImGui.openPopup("frame_rc"); }
				drawBarWithText( padding.x + startPos, frameY + frameHeight * row, padding.x +  lp.x, lp.y, width, frameHeight, f.tile, c, sel, rc );

				//drawList.addLine({x: lp.x + framePos, y: lp.y + 30 }, {x: lp.x + framePos, y: lp.y + 80}, 0xFFFF0000, 5);
				frameTime += f.duration;
				if( row > rows ) rows = row;
			}

			// Now do tags
			var c: ImVec4 = { x: 0.4, y: 0.7, z: 0.2, w: 1.0 };
			var ci = IG.imVec4ToColor( c );
			frameY += frameHeight + ( frameHeight * rows ) + 5;
			barReservations = [];
			rows = 0;

			for( t in selectedAnimation.tags )
			{
				var row = 0;
				while( !tryReserve({min: t.start, max: t.start + t.duration }, row ) ) row++;
				var localY = frameY + frameHeight * row;
				var startPos = t.start * tScale;
				var endPos = ( t.start + t.duration )  * tScale;
				var width = endPos - startPos;
				var sel = function(){ selectTag(t); }
				var rc = function(){ selectTag(t); ImGui.openPopup("tag_rc"); }
				if( t.duration == 0 )
					drawEventWithText( drawList, padding.x + startPos, localY, padding.x + lp.x, lp.y, frameHeight, 4, t.name, ci, sel, rc  );
				else
					drawBarWithText( padding.x + startPos, localY, padding.x +  lp.x, lp.y, width, frameHeight, t.name, c, sel, rc  );

				if( row > rows ) rows = row;
			}

			//Sounds
			var c: ImVec4 = { x: 0.3, y: 0.1, z: 0.7, w: 1.0 };
			var ci = IG.imVec4ToColor( c );
			frameY += frameHeight + ( frameHeight * rows ) + 5;
			barReservations = [];
			rows = 0;

			for( s in selectedAnimation.sounds )
			{
				var row = 0;
				while( !tryReserve({min: s.start, max: s.start + s.duration }, row ) ) row++;
				var startPos = s.start * tScale;
				var endPos = ( s.start + s.duration )  * tScale;
				var width = endPos - startPos;
				var sel = function(){ selectSound(s); }
				var rc = function(){ selectSound(s); ImGui.openPopup("sound_rc"); }
				if( s.duration == 0 )
					drawEventWithText( drawList, padding.x + startPos, frameY, padding.x + lp.x, lp.y, frameHeight, 4, s.name, ci, sel, rc );
				else
					drawBarWithText( padding.x + startPos, frameY + row * frameHeight, padding.x +  lp.x, lp.y, width, frameHeight, s.name, c, sel, rc );

				if( row > rows ) rows = row;
			}

			// Attachment Overrides
			var c: ImVec4 = { x: 0.16, y: 0.7, z: 0.7, w: 1.0 };
			var ci = IG.imVec4ToColor( c );
			var ctv: ImVec4 = { x: 0.16, y: 0.7, z: 0.7, w: 1.0 };
			var ct = IG.imVec4ToColor( ctv );
			frameY += frameHeight + ( frameHeight * rows ) + 5;
			barReservations = [];
			rows = 0;

			for( a in selectedAnimation.attachmentOverrides )
			{
				var row = 0;
				while( !tryReserve({min: a.start, max: a.start + a.duration }, row ) ) row++;
				var startPos = a.start * tScale;
				var endPos = ( a.start + a.duration )  * tScale;
				var width = endPos - startPos;
				var sel = function(){ selectAttachmentOverride(a); }
				var rc = function(){ selectAttachmentOverride(a); ImGui.openPopup("attachment_override_rc"); }
				drawBarWithText( padding.x + startPos, frameY + row * frameHeight, padding.x +  lp.x, lp.y, width, frameHeight, a.name, c, sel, rc );

				// Tween duration, if set:
				if( a.tweenDuration > 0 )
				{
					var offX = ( a.tweenDuration * tScale ) + padding.x + startPos;
					// End line
					drawList.addLine( { x: lp.x + offX, y: lp.y + frameY  + row * frameHeight }, { x: lp.x + offX, y: lp.y + frameY + frameHeight + 2  + row * frameHeight }, ci,3.5 );
					// Tween state
					drawList.addLine( { x: lp.x, y: lp.y + frameY + frameHeight + 2  + row * frameHeight }, { x: lp.x + offX, y: lp.y + frameY  + row * frameHeight }, ci,3.5 );


				}
				if( row > rows ) rows = row;
			}

			frameY += frameHeight + ( frameHeight * rows ) + 5;

			lastFrameHeight = frameY;

			// Draw the scrubber
			var currentTime = @:privateAccess sprite.animTime;
			var posX = currentTime * tScale;

			drawList.addLine({ x: lp.x + posX, y: lp.y }, { x: lp.x + posX, y: lp.y + lastFrameHeight  }, 0xFFFFFFFF, 2.5 );

			addTimelinePopups();

			ImGui.endChild();

			addTimelineModals();

			if( ImGui.isMouseDown( ImGuiMouseButton.Left ) )
			{
				var mouse: ImVec2 = ImGui.getMousePos();
				if( mouse.x > lp.x && mouse.x < rect.x + lp.x && mouse.y > lp.y && mouse.y < rect.y + lp.y )
				{
					var localMouse: ImVec2 = { x: mouse.x - lp.x, y: mouse.y - lp.y };
					var frameTime = localMouse.x / tScale;
					sprite.setAnimTime( frameTime );
				}
			}
		}

		ImGui.end();
	}



	function snapModal(  )
	{
		var animStart: Float = @:privateAccess sprite.animTime;
		var snappedStart: Float = 0;
		var snappedDuration: Float = 0;
		var dist: Float = animStart;


		var t: Float = 0;
		for( f in selectedAnimation.frames )
		{
			var lDist = Math.abs( t - animStart );
			if( lDist < dist )
			{
				dist = lDist;
				snappedStart = t;
				snappedDuration = f.duration;
			}

			t+=f.duration;
		}

		modalStart = snappedStart;
		modalDuration = snappedDuration;
		modalName = "";
	}

	var modalStart: Float = 0;
	var modalDuration: Float = 0;
	var modalName: String = "";

	function addTimelineModals()
	{


		// Modals
		if( ImGui.beginPopupModal("Add Sound Cue", null, ImGuiWindowFlags.AlwaysAutoResize ) )
		{

			wref( ImGui.inputDouble("Start", _ ), modalStart );
			wref( ImGui.inputDouble("Duration", _ ), modalDuration );
			var n =  IG.textInput("Sound", modalName );
			if( n != null )
				modalName = n;

			if( ImGui.button("Ok") )
			{
				selectedAnimation.sounds.push({
					name: modalName,
					start: modalStart,
					duration: modalDuration,
				});
				selectSound( selectedAnimation.sounds[ selectedAnimation.sounds.length -1 ] );
				rebuildCache();
				ImGui.closeCurrentPopup();
			}
			ImGui.sameLine();
			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}

			ImGui.endPopup();
		}

		if( ImGui.beginPopupModal("Add Tag", null, ImGuiWindowFlags.AlwaysAutoResize ) )
		{

			wref( ImGui.inputDouble("Start", _ ), modalStart );
			wref( ImGui.inputDouble("Duration", _ ), modalDuration );
			var n =  IG.textInput("Tag", modalName );
			if( n != null )
				modalName = n;

			if( ImGui.button("Ok") )
			{
				selectedAnimation.tags.push({
					name: modalName,
					start: modalStart,
					duration: modalDuration,
				});
				selectTag( selectedAnimation.tags[ selectedAnimation.tags.length -1 ] );
				rebuildCache();
				ImGui.closeCurrentPopup();
			}
			ImGui.sameLine();
			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}

			ImGui.endPopup();
		}

		if( ImGui.beginPopupModal("Add Attachment Override", null, ImGuiWindowFlags.AlwaysAutoResize ) )
		{

			wref( ImGui.inputDouble("Start", _ ), modalStart );
			wref( ImGui.inputDouble("Duration", _ ), modalDuration );
			var n =  IG.textInput("Attachment", modalName );
			if( n != null )
				modalName = n;

			if( ImGui.button("Ok") )
			{
				selectedAnimation.attachmentOverrides.push({
					name: modalName,
					start: modalStart,
					duration: modalDuration,
					position: {x: 0, y: 0},
					rotation: 0,
					positionTween: None,
					rotationTween: None,
					tweenDuration: 0
				});
				selectAttachmentOverride( selectedAnimation.attachmentOverrides[ selectedAnimation.attachmentOverrides.length -1 ] );
				rebuildSprite();
				ImGui.closeCurrentPopup();
			}
			ImGui.sameLine();
			if( ImGui.button("Cancel") )
			{
				ImGui.closeCurrentPopup();
			}

			ImGui.endPopup();
		}
	}

	function addTimelinePopups()
	{
		// Context
		if( ImGui.beginPopup("frame_rc") )
			{
				if( ImGui.menuItem("Remove") )
				{
					selectedAnimation.frames.remove(selectedFrame);
					selectedFrame = null;
					inspectorMode = NONE;
					rebuildCache();
				}
				ImGui.endPopup();
			}
			if( ImGui.beginPopup("sound_rc") )
			{
				if( ImGui.menuItem("Remove") )
				{
					selectedAnimation.sounds.remove(selectedSound);
					selectedSound = null;
					inspectorMode = NONE;
				}
				ImGui.endPopup();
			}
			if( ImGui.beginPopup("tag_rc") )
			{
				if( ImGui.menuItem("Remove") )
				{
					selectedAnimation.tags.remove(selectedTag);
					selectedTag = null;
					inspectorMode = NONE;
				}
				ImGui.endPopup();
			}
			if( ImGui.beginPopup("attachment_override_rc") )
			{
				if( ImGui.menuItem("Remove") )
				{
					selectedAnimation.attachmentOverrides.remove(selectedAttachmentOverride);
					selectedAttachmentOverride = null;
					inspectorMode = NONE;
				}
				ImGui.endPopup();
			}
	}

	function drawBarWithText( x: Float, y: Float, gx: Float, gy: Float, width: Float, height: Float, text: String, c: ImVec4, ?onSelect: Void->Void, ?onContext: Void->Void )
	{
		var texture = h3d.mat.Texture.fromColor(0xFFFFFF,1.);

		var bc: ImVec4 = {
			x: Math.min( c.x + 0.2, 1 ),
			y: Math.min( c.y + 0.2, 1 ),
			z: Math.min( c.z + 0.2, 1 ),
			w: 1.0,
		};

		ImGui.setCursorPos({x: x, y: y } );
		ImGui.image(texture,{ x: width, y: height },null, null, c, bc );
		if( ImGui.isItemClicked(ImGuiMouseButton.Left) && onSelect != null )	onSelect();
		if( ImGui.isItemClicked(ImGuiMouseButton.Right) && onContext != null )	onContext();
		ImGui.setCursorPos({x: x + 4, y: y + 4 } );
		ImGui.pushClipRect({x: gx + x, y: gy + y }, { x: gx + x + width, y: gy + y + height }, true);
		ImGui.text(text);
		ImGui.popClipRect();
	}

	function drawEventWithText( drawList: ImDrawList, x: Float, y: Float, gx: Float, gy: Float, height: Float, thickness: Float, text: String, c: Int, ?onSelect: Void->Void, ?onContext: Void->Void )
	{
		var textSize: ImVec2 = ImGui.calcTextSize(text);
		drawList.addLine({ x: gx+x, y: gy+y }, { x: gx+x, y: gy+y + height }, c, thickness );
		ImGui.setCursorPos({x: x, y: y } );

		ImGui.dummy( {x: thickness + textSize.x, y: height  } );
		if( ImGui.isItemClicked(ImGuiMouseButton.Left) && onSelect != null )	onSelect();
		if( ImGui.isItemClicked(ImGuiMouseButton.Right) && onContext != null )	onContext();
		ImGui.setCursorPos({x: x + 4 + thickness, y: y + 4 } );
		ImGui.text(text);
	}



	function inspectorWindow()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Inspector##${windowID()}');

		switch( inspectorMode )
		{
			case ANIMATION:
				ImGui.pushID( "animation" + selectedAnimation.name );
				ImGui.text("Animation settings");
				ImGui.separator();
				var newAtlas = IG.textInput( "Atlas", selectedAnimation.atlas );
				if( newAtlas != null && hxd.Res.loader.exists( newAtlas ) )
				{
					selectedAnimation.atlas = newAtlas;
					rebuildCache();
				}

				ImGui.popID();


			case FRAME:
				ImGui.pushID("frame" + selectedFrame.tile);
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
				wref( ImGui.inputDouble("Duration (ms)", _, 0.01, .1, "%.3f"), selectedFrame.duration);
				wref( ImGui.inputDouble("Offset X", _, 1, 10, "%.2f"),  selectedFrame.offsetX);
				wref( ImGui.inputDouble("Offset Y", _, 1, 10, "%.2f"), selectedFrame.offsetY);

				ImGui.popID();

			case ATTACHMENT:
				ImGui.pushID("attachmnet" + selectedAttachment.name);
				ImGui.text("Attachment settings");
				ImGui.separator();
				if( IG.posInput("Offset", selectedAttachment.position, "%.2f") )
				{
					rebuildSprite();
				}
				var single: Single = selectedAttachment.rotation;
				if( wref( ImGui.sliderAngle("Rotation", _), single ) )
					selectedAttachment.rotation = single;

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Ctrl+click to manually set");
					ImGui.endTooltip();
				}

				var newSprite = IG.textInput( "Sprite", selectedAttachment.attachmentSprite != null ? selectedAttachment.attachmentSprite : "" );
				if( newSprite != null && ( hxd.Res.loader.exists( newSprite ) || newSprite == "" ) )
				{
					if( newSprite == "" ) newSprite = null;
					selectedAttachment.attachmentSprite = newSprite;
					rebuildSprite();
				}

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && StringTools.endsWith(payload, ".csd") )
					{
						selectedAttachment.attachmentSprite = payload;
						rebuildSprite();
					}
					ImGui.endDragDropTarget();
				}

				// parenting
				if( ImGui.beginCombo("Parent", selectedAttachment.parent != null ? selectedAttachment.parent : "None" ) )
				{
					if( ImGui.selectable("None", selectedAttachment.parent == null) )
					{
						selectedAttachment.parent = null;
						rebuildSprite();
					}

					for( a in spriteDef.attachments )
					{
						if( ImGui.selectable(a.name, a.name == selectedAttachment.parent) )
						{
							selectedAttachment.parent = a.name;
							rebuildSprite();
						}
					}



					ImGui.endCombo();
				}

				ImGui.popID();

			case COLLIDER:
				ImGui.pushID("collider");
				ImGui.text("Collider settings");
				ImGui.separator();
				/*
				var options = new hl.NativeArray<String>(2);
				options[0] = "Box";
				options[1] = "Circle";
				wref( ImGui.combo("Type", _, options), selectedCollider.type);
				*/
				if( ImGui.beginCombo("Type", selectedCollider.type.toString() ) )
				{
					if( ImGui.selectable("AABB", 	selectedCollider.type == AABB) )	selectedCollider.type = AABB;
					if( ImGui.selectable("Circle", 	selectedCollider.type == Circle) )	selectedCollider.type = Circle;

					ImGui.endCombo();
				}



				IG.posInput("Offset", selectedCollider.position, "%.2f");
				IG.posInput("Size", selectedCollider.size, "%.2f");

				ImGui.popID();

			case SOUND:
				ImGui.pushID("sound" + selectedSound.name);

				ImGui.text("Sound cue settings");
				ImGui.separator();


				wref( ImGui.inputDouble("Start", _), selectedSound.start );
				wref( ImGui.inputDouble("Duration", _), selectedSound.duration );

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Only used for looping sounds.");
					ImGui.endTooltip();
				}

				var newSound = IG.textInput( "Sound cue", selectedSound.name != null ? selectedSound.name : "" );
				if( newSound != null )
				{
					if( newSound == "" ) newSound = null;
					selectedSound.name = newSound;
				}

				ImGui.popID();


			case ATTACHMENTOVERRIDE:
				ImGui.pushID("attachmentoverride" + selectedAttachmentOverride.name);

				ImGui.text("Attachment Override settings");
				ImGui.separator();

				wref( ImGui.inputDouble("Start", _), selectedAttachmentOverride.start );
				wref( ImGui.inputDouble("Duration", _), selectedAttachmentOverride.duration );

				if( IG.posInput("Offset", selectedAttachmentOverride.position, "%.2f") )
				{
					rebuildSprite();
				}

				if( ImGui.beginCombo("Offset Tween", selectedAttachmentOverride.positionTween.toString() ) )
				{
					if( ImGui.selectable(SpriteAttachmentTween.None.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.None ) )
						selectedAttachmentOverride.positionTween = None;

					if( ImGui.selectable(SpriteAttachmentTween.Linear.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.Linear ) )
						selectedAttachmentOverride.positionTween = Linear;

					if( ImGui.selectable(SpriteAttachmentTween.ExpoIn.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.ExpoIn ) )
						selectedAttachmentOverride.positionTween = ExpoIn;

					if( ImGui.selectable(SpriteAttachmentTween.ExpoOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.ExpoOut ) )
						selectedAttachmentOverride.positionTween = ExpoOut;

					if( ImGui.selectable(SpriteAttachmentTween.ExpoInOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.ExpoInOut ) )
						selectedAttachmentOverride.positionTween = ExpoInOut;

					if( ImGui.selectable(SpriteAttachmentTween.CircIn.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.CircIn ) )
						selectedAttachmentOverride.positionTween = CircIn;

					if( ImGui.selectable(SpriteAttachmentTween.CircOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.CircOut ) )
						selectedAttachmentOverride.positionTween = CircOut;

					if( ImGui.selectable(SpriteAttachmentTween.CircInOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.CircInOut ) )
						selectedAttachmentOverride.positionTween = CircInOut;

					if( ImGui.selectable(SpriteAttachmentTween.SineIn.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.SineIn ) )
						selectedAttachmentOverride.positionTween = SineIn;

					if( ImGui.selectable(SpriteAttachmentTween.SineOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.SineOut ) )
						selectedAttachmentOverride.positionTween = SineOut;

					if( ImGui.selectable(SpriteAttachmentTween.SineInOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.SineInOut ) )
						selectedAttachmentOverride.positionTween = SineInOut;

					ImGui.endCombo();
				}


				var single: Single = selectedAttachmentOverride.rotation;
				if( wref( ImGui.sliderAngle("Rotation", _), single ) )
					selectedAttachmentOverride.rotation = single;

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Ctrl+click to manually set");
					ImGui.endTooltip();
				}

				if( ImGui.beginCombo("Rotation Tween", selectedAttachmentOverride.rotationTween.toString() ) )
				{
					if( ImGui.selectable(SpriteAttachmentTween.None.toString(), selectedAttachmentOverride.rotationTween == SpriteAttachmentTween.None ) )
						selectedAttachmentOverride.rotationTween = None;

					if( ImGui.selectable(SpriteAttachmentTween.Linear.toString(), selectedAttachmentOverride.rotationTween == SpriteAttachmentTween.Linear ) )
						selectedAttachmentOverride.rotationTween = Linear;

					if( ImGui.selectable(SpriteAttachmentTween.ExpoIn.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.ExpoIn ) )
						selectedAttachmentOverride.rotationTween = ExpoIn;

					if( ImGui.selectable(SpriteAttachmentTween.ExpoOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.ExpoOut ) )
						selectedAttachmentOverride.rotationTween = ExpoOut;

					if( ImGui.selectable(SpriteAttachmentTween.ExpoInOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.ExpoInOut ) )
						selectedAttachmentOverride.rotationTween = ExpoInOut;

					if( ImGui.selectable(SpriteAttachmentTween.CircIn.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.CircIn ) )
						selectedAttachmentOverride.rotationTween = CircIn;

					if( ImGui.selectable(SpriteAttachmentTween.CircOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.CircOut ) )
						selectedAttachmentOverride.rotationTween = CircOut;

					if( ImGui.selectable(SpriteAttachmentTween.CircInOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.CircInOut ) )
						selectedAttachmentOverride.rotationTween = CircInOut;

					if( ImGui.selectable(SpriteAttachmentTween.SineIn.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.SineIn ) )
						selectedAttachmentOverride.rotationTween = SineIn;

					if( ImGui.selectable(SpriteAttachmentTween.SineOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.SineOut ) )
						selectedAttachmentOverride.rotationTween = SineOut;

					if( ImGui.selectable(SpriteAttachmentTween.SineInOut.toString(), selectedAttachmentOverride.positionTween == SpriteAttachmentTween.SineInOut ) )
						selectedAttachmentOverride.rotationTween = SineInOut;
					ImGui.endCombo();
				}

				wref( ImGui.inputDouble("Tween Duration", _), selectedAttachmentOverride.tweenDuration );

				if( selectedAttachmentOverride.tweenOrigin == null )
				{
					var setOrigin = false;

					if( wref( ImGui.checkbox("Tween Origin", _), setOrigin) && setOrigin )
					{
						selectedAttachmentOverride.tweenOrigin = {x: 0, y:0};
					}
				}
				else
				{
					if( IG.posInput("Tween Origin", selectedAttachmentOverride.tweenOrigin, "%.2f") )
					{
						rebuildSprite();
					}

					var single: Single = selectedAttachmentOverride.tweenRotation != null ? cast selectedAttachmentOverride.tweenRotation : 0.;
					if( wref( ImGui.sliderAngle("Tween Rotation", _), single ) )
						selectedAttachmentOverride.tweenRotation = single;

						if( ImGui.isItemHovered() )
						{
							ImGui.beginTooltip();
							ImGui.text("Ctrl+click to manually set");
							ImGui.endTooltip();
						}
				}

				ImGui.popID();

			case TAG:
				ImGui.pushID("tag" + selectedTag.name);

				ImGui.text("Tag settings");
				ImGui.separator();

				wref( ImGui.inputDouble("Start", _), selectedTag.start );
				wref( ImGui.inputDouble("Duration", _), selectedTag.duration );

				ImGui.popID();

			case NONE:

		}

		ImGui.end();
	}

	public override function windowID()
	{
		return 'spre${fileName != null ? fileName : ""+toolId}';
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

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.40, null, idOut);
			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.30, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.30, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}
}

#end
#end