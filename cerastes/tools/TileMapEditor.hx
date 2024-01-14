
package cerastes.tools;


import h2d.TileGroup;
import cerastes.fmt.TileMapResource.TileMapTileFlags;
import h2d.Tile;
import cerastes.fmt.TileMapResource.TileMapDef;
import cerastes.fmt.TileMapResource.TileMapLayerDef;
import cerastes.fmt.TileMapResource.TileMapLayerDataDef;
import cerastes.fmt.TileMapResource.TileMap;
#if hlimgui

import h3d.scene.Object.ObjectFlags;
import cerastes.ui.Timeline;
import cerastes.macros.Metrics;
import cerastes.ui.UIEntity;
import cerastes.tools.ImguiTool.ImGuiPopupType;
import hxd.Key;
import hxd.res.Font;
import hxd.res.BitmapFont;
import h3d.Vector;
import h2d.col.Point;
import h2d.Graphics;
import hl.UI;
import cerastes.tools.ImguiTool.ImGuiToolManager;
import haxe.EnumTools;
import haxe.io.Bytes;
import hxd.BytesBuffer;
import h2d.Text;
import hl.Ref;
import cerastes.fmt.CUIResource;
import cerastes.fmt.CUIResource.CUIObject;
import h2d.Flow;
import h2d.Bitmap;
import h3d.mat.Texture;
import h2d.Object;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import cerastes.tools.ImguiTools.IG;
import imgui.ImGuiMacro.wref;
import cerastes.macros.MacroUtils.imTooltip;

@:keep
@multiInstance(true)
class TileMapEditor extends ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;
	var viewportScale: Int;

	var preview: h2d.Scene;
	var previewRoot: Object;
	var sceneRT: Texture;
	var sceneRTId: Int;


	var scaleFactor = Utils.getDPIScaleFactor();

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;
	var dockspaceIdBottom: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var selectedItemBorder: Graphics;
	var cursor: Graphics;
	var cursorTileGroup: TileGroup;

	var mouseScenePos: ImVec2;
	var mouseDragDuration: Float = -1;
	var mouseDragStartPos: ImVec2;
	var hasFocus = false;

	var showMarkers = true;
	var initializeObjects = true;

	var zoom: Int = 1;

	var lastSaved: Float = 0;

	var timelinePlay = false;
	var keyframeContext: TimelineOperation = null;
	var timelineRunner: TimelineRunner;
	var focusScript = false;

	//
	var tileMapDef: cerastes.fmt.TileMapResource.TileMapDef;
	var tileMap: TileMap;

	var selectedLayer: TileMapLayerDef;
	var selectedTile: Int = -1;

	//
	var randomRotation = false;
	var randomFlip = false;
	var tileRotation: Int = 0;

	public override function getName() { return '\uf108 UI Editor ${fileName != null ? '($fileName)' : ""}'; }

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;
		viewportScale = viewportDimensions.scale;
		preview = new h2d.Scene();
		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		selectedItemBorder = new h2d.Graphics();
		cursor = new h2d.Graphics();
		cursorTileGroup = new TileGroup();

		tileMapDef = {};

		// TEST
		//
		var ld: TileMapLayerDataDef = {};
		var l: TileMapLayerDef = {
			tileData: ld
		};
		tileMapDef.layers.push(l);
		tileMapDef.resize(10,10);
		ld.tileSheet = "sheets/RA_Ground_Tiles.png";

		ld.setIdx( 0,0 ,127);
		ld.setIdx(1,0,127);
		ld.setIdx(2,0,127);
		ld.setIdx(3,0,127);

		ld.setIdx(0,1,131);
		ld.setIdx(0,2,131);
		ld.setIdx(0,3,131);


		//tileMapDef.resize( 10, 10 );
		tileMap = tileMapDef.create();


		preview.addChild( tileMap );
		preview.addChild(selectedItemBorder);
		preview.addChild(cursor);
		preview.addChild( cursorTileGroup );

		updateScene();
	}

	public override function openFile( f: String )
	{
		fileName = f;

		try
		{
			// ....
			updateScene();
		} catch(e)
		{
			Utils.warning('Failed to open ${f}: $e');
			ImGuiToolManager.showPopup('Failed to load $f', 'Hit an exception: $e', ImGuiPopupType.Error);
			// do nothing
		}
	}

	function updateScene()
	{
		Metrics.begin();
		tileMap.rebuild();

		var w = 0;
		var h = 0;
		for( l in tileMapDef.layers )
		{
			w = cast Math.max( w, l.tileData.tileWidth * l.tileData.width );
			h = cast Math.max( w, l.tileData.tileHeight * l.tileData.height );
		}

		sceneRT.resize( w,h  );
		preview.scaleMode = Fixed(w,h, 1, Left, Top);

		Metrics.end();

	}


	function saveAs()
	{
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes Tile Map files", exts:["ctm"]}
			]
		});
		if( newFile != null )
		{
			fileName = Utils.toLocalFile( newFile );
			//CUIResource.writeObject(rootDef, timelines, preview,newFile);

			cerastes.tools.AssetBrowser.needsReload = true;
			lastSaved = Sys.time() * 1000;
			ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
		}
	}

	function save()
	{
		if( fileName == null )
		{
			saveAs();
			return;
		}

		//CUIResource.writeObject(rootDef,timelines,preview,fileName);

		lastSaved = Sys.time() * 1000;
		ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
	}

	function handleShortcuts()
	{
		if( ImGui.isWindowFocused( ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}
	}


	function menuBar()
	{

		handleShortcuts();


		if( ImGui.beginMenuBar() )
		{
			if( ImGui.beginMenu("File", true) )
			{
				if ( fileName != null && ImGui.menuItem("Save", "CTRL+S"))
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

	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		var saveString = ( Sys.time() * 1000 ) - lastSaved < 5000 ? " - Saved!" : "";

		if( forceFocus )
		{
			forceFocus = false;
			ImGui.setNextWindowFocus();
		}
		ImGui.setNextWindowSize({x: viewportWidth * 2, y: viewportHeight * 1.6}, ImGuiCond.Once);
		ImGui.begin('\uf108 Tile Map Editor ${fileName != null ? fileName : ""} ${saveString}###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar );

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.sameLine();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		if( ImGui.isWindowHovered() )
		{
			var startPos: ImVec2 = ImGui.getCursorScreenPos();
			var mousePos: ImVec2 = ImGui.getMousePos();

			mouseScenePos = {x: ( mousePos.x - startPos.x) / zoom, y: ( mousePos.y - startPos.y ) / zoom };
			// Should use imgui events here for consistency but GetIO isn't exposed to hl sooo...
			if (Key.isPressed(Key.MOUSE_WHEEL_DOWN))
			{
				zoom--;
				if( zoom <= 0 )
					zoom = 1;
			}
			if (Key.isPressed(Key.MOUSE_WHEEL_UP))
			{
				zoom++;
				if( zoom > 20 )
					zoom = 20;
			}
		}
		else
		{
			mouseScenePos = null;
		}

		ImGui.image(sceneRT, { x: sceneRT.width * zoom, y: sceneRT.height * zoom }, null, null, null, {x: 1, y: 1, z:1, w:1} );
		if( mouseScenePos != null )
			ImGui.text('${mouseScenePos.x}, ${mouseScenePos.y}');


		ImGui.end();


		layoutColumn();
		propertiesColumn();


		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

		processSceneMouse( delta );





	}

	function layoutColumn()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Layout##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		//ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.text("Layers");
		//ImGui.popFont();
		if( ImGui.beginChildFrame( ImGui.getID( "frame1" ), {x: -1, y: 100 * ImGuiToolManager.scaleFactor} ) )
		{
			if( ImGui.beginTable("table",3 ) )
			{
				var style = ImGui.getStyle();
				var cbw = ImGuiToolManager.defaultFontSize;

				ImGui.tableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch, 100 * ImGuiToolManager.scaleFactor - cbw);
                ImGui.tableSetupColumn("Hidden", ImGuiTableColumnFlags.None, cbw );
                ImGui.tableSetupColumn("Locked", ImGuiTableColumnFlags.None, cbw );
                ImGui.tableHeadersRow();

				for( i in 0 ... tileMapDef.layers.length )
				{
					ImGui.tableNextRow();
					ImGui.tableNextColumn();

					var l = tileMapDef.layers[i];

					var flags = ImGuiTreeNodeFlags.Leaf | ImGuiTreeNodeFlags.DefaultOpen;

					if( selectedLayer == l )
						flags |= ImGuiTreeNodeFlags.Selected;

					var name = 'Layer ${i}';
					if( ImGui.treeNodeEx( name, flags ) )
					{
						ImGui.treePop();
					}

					if( ImGui.isItemClicked() )
						selectedLayer = l;

					var isHidden = false;
					var isLocked = false;

					ImGui.tableNextColumn();
					ImGui.checkbox("##hidden", isHidden);
					ImGui.tableNextColumn();
					ImGui.checkbox("##locked", isLocked);


				}
				ImGui.endTable();
			}

			ImGui.endChildFrame();
		}

		var w = tileMapDef.width;
		var h = tileMapDef.height;

		var e = ImGui.inputInt("Width", w, 1, 10, ImGuiInputTextFlags.EnterReturnsTrue);
		imTooltip("Width in tiles. Press enter to resize.");
		var e = e || ImGui.inputInt("Height", h, 1, 10, ImGuiInputTextFlags.EnterReturnsTrue);
		imTooltip("Height in tiles. Press enter to resize.");

		if( e )
		{
			tileMapDef.resize(w, h);
			updateScene();
		}


		ImGui.end();
	}

	function propertiesColumn()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Properties##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		if( selectedLayer == null )
		{
			ImGui.text("No layer selected.");
			ImGui.end();
			return;
		}

		var newTexture = IG.inputTexture( "Tile Sheet", selectedLayer.tileData.tileSheet );
		if( newTexture != null )
		{
			selectedLayer.tileData.tileSheet = newTexture;
			updateScene();
		}

		ImGui.text("Palette");

		var tex = Utils.resolveTexture( selectedLayer.tileData.tileSheet );

		var startPos: ImVec2 = ImGui.getCursorScreenPos();
		var mousePos: ImVec2 = ImGui.getMousePos();

		var pickerZoom = 2;
		var pickerMousePos = {x: ( mousePos.x - startPos.x) / pickerZoom, y: ( mousePos.y - startPos.y ) / pickerZoom };
		var pw = tex.width * pickerZoom;
		var ph = tex.height * pickerZoom;
		ImGui.image( tex, {x: pw, y: ph }, null, null, null, {x: 1, y:1, z: 1, w: 1 } );
		var restorePos = ImGui.getCursorPos();

		if( pickerMousePos.x > 0 && pickerMousePos.x < pw && pickerMousePos.y > 0 && pickerMousePos.y < ph )
		{
			var tx: Int = Math.floor(pickerMousePos.x / selectedLayer.tileData.tileWidth );
			var ty: Int = Math.floor(pickerMousePos.y / selectedLayer.tileData.tileHeight );

			var px: Int = tx * selectedLayer.tileData.tileWidth * pickerZoom;
			var py: Int = ty * selectedLayer.tileData.tileHeight * pickerZoom;

			if( ImGui.isItemClicked())
			{
				selectedTile = cast tx + ty * ( tex.width / selectedLayer.tileData.tileWidth );
			}

			var offset: ImVec2 = {x: px, y: py};
			ImGui.setCursorScreenPos( startPos + offset );
			ImGui.imageTile( Tile.fromColor(0xFFFFFF, 1, 1, 0.25), {x:selectedLayer.tileData.tileWidth * pickerZoom, y: selectedLayer.tileData.tileHeight * pickerZoom} );


		}

		ImGui.setCursorPos( restorePos );

		ImGui.checkbox("Random rotation", randomRotation);


		ImGui.end();
	}


	function processSceneMouse( delta: Float )
	{
		if( mouseScenePos == null )
			return;

		var sceneWidth = sceneRT.width;
		var sceneHeight = sceneRT.height;

		var isMouseOverViewport = mouseScenePos.x > 0 && mouseScenePos.x < sceneWidth && mouseScenePos.y > 0 && mouseScenePos.y < sceneHeight;


		cursor.clear();
		cursorTileGroup.clear();
		if( isMouseOverViewport )
		{
			if( selectedLayer != null )
			{
				var cx: Int = cast mouseScenePos.x / selectedLayer.tileData.tileWidth;
				var cy: Int = cast mouseScenePos.y / selectedLayer.tileData.tileHeight;


				if( selectedTile >= 0 )
				{
					cursor.alpha = 0.7;
					var tile = Utils.getTile( selectedLayer.tileData.tileSheet );
					var t = selectedLayer.tileData.getTile( tile, selectedTile );

					var flipX = tileRotation & TileMapTileFlags.FlipHorizontal != 0;
					var flipY = tileRotation & TileMapTileFlags.FlipVertical != 0;
					var flipDiag = tileRotation & TileMapTileFlags.FlipDiagonal != 0;

					var fx = flipX ? -1 : 1;
					var fy = flipY ? -1 : 1;
					var rot = 0.;

					var xo = fx == -1 ? selectedLayer.tileData.tileWidth : 0;
					var yo = fy == -1 ? selectedLayer.tileData.tileHeight : 0;

					if( flipDiag )
					{
						fy = -fy;

						if( flipX  != flipY )
						{
							rot = -Math.PI / 2;
						}
						else
						{
							rot = Math.PI / 2;

						}
					}

					cursorTileGroup.addTransform( cx * selectedLayer.tileData.tileWidth + xo, cy * selectedLayer.tileData.tileHeight + yo, fx, fy, rot, t );


				}
				else
				{
					cursor.alpha = 0.35;
					cursor.beginFill(0xFFFFFF);
					cursor.drawRect( cx * selectedLayer.tileData.tileWidth, cy * selectedLayer.tileData.tileHeight, selectedLayer.tileData.tileWidth, selectedLayer.tileData.tileHeight );
					cursor.endFill();
				}

				if( ImGui.isMouseDown( ImGuiMouseButton.Left ) )
				{
					tileMapDown(cx, cy);
				}

				if( ImGui.isMouseClicked( ImGuiMouseButton.Left ) )
				{
					tileMapClicked(cx, cy);
				}

				if( ImGui.isMouseClicked( ImGuiMouseButton.Right ) )
				{
					tileMapClickedRight(cx, cy);
				}
			}


		}

	}

	function tileMapClickedRight(x: Int, y: Int )
	{
		var steps: Array<Int> = [
			TileMapTileFlags.None,
			TileMapTileFlags.FlipDiagonal | TileMapTileFlags.FlipHorizontal,
			TileMapTileFlags.FlipVertical | TileMapTileFlags.FlipHorizontal,
			TileMapTileFlags.FlipDiagonal | TileMapTileFlags.FlipVertical,
		];

		var step = 0;
		for( i in 0 ... steps.length )
		{
			if( tileRotation == steps[i] )
			{
				step = i;
				break;
			}
		}
		step++;
		if( step >= steps.length )
			step = 0;

		tileRotation = steps[step];
	}

	function tileMapClicked(x: Int, y: Int )
	{
		var flags = tileRotation;
		lastDownX = x;
		lastDownY = y;

		if( randomRotation )
		{
			flags = Std.random( TileMapTileFlags.FlipFlags );
			tileRotation = flags;
		}

		tileMapDef.layers[0].tileData.setIdx(x,y,selectedTile, flags);
		updateScene();
	}

	var lastDownX = -1;
	var lastDownY = -1;
	public function tileMapDown(x: Int, y: Int)
	{
		if( lastDownX == x && lastDownY == y )
			return;

		tileMapClicked(x, y);
	}


	public override inline function windowID()
	{
		return 'tmed${fileName != null ? fileName : ""+toolId}';
	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = "TileMapEditorDockspace";

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdBottom = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Down, 0.30, null, idOut);
			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.30, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.30, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}





	override public function render( e: h3d.Engine)
	{
		sceneRT.clear( 0 );

		var oldW = e.width;
		var oldH = e.height;

		e.pushTarget( sceneRT );
		e.clear(0,1);

		@:privateAccess// @:bypassAccessor
		{
			e.width = sceneRT.width;
			e.height = sceneRT.height;
			preview.checkResize();
			preview.render(e);
			e.width = oldW;
			e.height = oldH;
		}

		e.popTarget();
	}





}

#end