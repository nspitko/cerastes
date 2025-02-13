
package cerastes.tools;

#if hlimgui
using imgui.ImGui.ImGuiKeyStringExtender;
import haxe.rtti.Meta;
import cerastes.c2d.TileEntity.TileEntityDef;
import cerastes.fmt.TileMapResource.TileMapEntityDef;
import cerastes.tools.ImguiTools.ComboFilterState;
import h2d.TileGroup;
import cerastes.fmt.TileMapResource.TileMapTileFlags;
import h2d.Tile;
import cerastes.fmt.TileMapResource.TileMapDef;
import cerastes.fmt.TileMapResource.TileMapLayerDef;
import cerastes.fmt.TileMapResource.TileMapLayerDataDef;
import cerastes.fmt.TileMapResource.TileMap;

import h3d.scene.Object.ObjectFlags;
import cerastes.ui.Timeline;
import cerastes.macros.Metrics;
import cerastes.ui.UIEntity;
import cerastes.tools.ImguiTool.ImGuiPopupType;
import hxd.Key;
import hxd.res.Font;
import hxd.res.BitmapFont;
import h3d.Vector4;
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

enum PaintMode
{
	Normal;
	Fill;
	Entity;
	Select;
}

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

	var tileMapDefPreview: cerastes.fmt.TileMapResource.TileMapDef;
	var tileMapPreview: TileMap;

	var selectedLayer: TileMapLayerDef;
	var selectedTile: Int = -1;
	var selectedTileEnd: Int = -1;
	var selectedEntity: TileMapEntityDef = null;

	//
	var randomRotation = false;
	var randomFlip = false;
	var tileRotation: Int = 0;
	var paintMode: PaintMode = Normal;
	var paintEntityType: String = null;
	var paintEntityFilterState: ComboFilterState = {};

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

		tileMapDef = {
			width: 10,
			height: 10
		};
		tileMapDefPreview = {
			layers: [ {} ]
		};
		tileMapDef.layers.push({});


		// TEST
		//
		/*
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
		*/

		//tileMapDef.resize( 10, 10 );
		tileMap = tileMapDef.create();
		tileMapPreview = tileMapDefPreview.create();


		selectLayer(tileMapDef.layers[0]);


		preview.addChild( tileMap );
		preview.addChild(selectedItemBorder);
		preview.addChild(cursor);
		preview.addChild( tileMapPreview );


		updateScene();
	}

	function selectLayer( l: TileMapLayerDef )
	{
		selectedLayer = l;

		tileMapDefPreview.layers[0].tileData.tileSheet = l.tileData.tileSheet;
		tileMapDefPreview.resize( tileMapDefPreview.layers[0].tileData.width, tileMapDefPreview.layers[0].tileData.height );
		tileMapDefPreview.clear();
		tileMapPreview.rebuild();
	}

	public override function openFile( f: String )
	{
		fileName = f;

		//try
		//{
			tileMapDef =  cerastes.file.CDParser.parse( hxd.Res.loader.load(f).entry.getText(), TileMapDef );
			tileMapDef.unpack();
			selectLayer(tileMapDef.layers[0]);

			preview.removeChild( tileMap );
			tileMap = tileMapDef.create();
			preview.addChild(tileMap);
			preview.removeChild(tileMapPreview);
			preview.addChild(tileMapPreview);

			updateScene();
		/*} catch(e)
		{
			Utils.warning('Failed to open ${f}: $e');
			ImGuiToolManager.showPopup('Failed to load $f', 'Hit an exception: $e', ImGuiPopupType.Error);
			// do nothing
		}*/
	}

	function updateScene()
	{
		Metrics.begin();
		tileMap.rebuild();

		tileMapDefPreview.resize( tileMapDef.width, tileMapDef.height );
		tileMapPreview.rebuild();

		var w = 0;
		var h = 0;
		for( l in tileMapDef.layers )
		{
			w = cast Math.max( w, l.tileData.tileWidth * l.tileData.width );
			h = cast Math.max( h, l.tileData.tileHeight * l.tileData.height );
		}

		sceneRT.resize( w,h  );
		preview.scaleMode = Fixed(w,h, 1, Left, Top);
		//preview.width = w;
		//preview.height = h;

		Metrics.end();

	}


	function saveAs()
	{
		hxd.System.allowTimeout = false;
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes Tile Map files", exts:["ctm"]}
			]
		});
		hxd.System.allowTimeout = true;
		if( newFile != null )
		{
			fileName = Utils.toLocalFile( newFile );
			tileMapDef.pack();
			sys.io.File.saveContent(Utils.fixWritePath(fileName,"ctmap"), cerastes.file.CDPrinter.print( tileMapDef ) );

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

		tileMapDef.pack();
		sys.io.File.saveContent(Utils.fixWritePath(fileName,"ctmap"), cerastes.file.CDPrinter.print( tileMapDef ) );

		lastSaved = Sys.time() * 1000;
		ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
	}

	function handleShortcuts()
	{
		if( ImGui.isWindowFocused( ImGuiFocusedFlags.RootAndChildWindows ) && !ImGui.getIO().WantCaptureKeyboard )

		{
			var io = ImGui.getIO();
			if( ImGui.isWindowFocused( ImGuiFocusedFlags.RootAndChildWindows ) )
			{
				if( io.KeyCtrl )
				{
					if( ImGui.isKeyPressed( 'S'.imKey() ) )
						save();
				}
			}

			if( !io.KeyCtrl )
			{
				if( ImGui.isKeyDown( 'P'.imKey() ) )
					paintMode = Normal;
				if( ImGui.isKeyDown( 'F'.imKey() ) )
					paintMode = Fill;
				if( ImGui.isKeyDown( 'E'.imKey() ) )
					paintMode = Entity;
				if( ImGui.isKeyDown( 'S'.imKey() ) )
					paintMode = Select;
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

		toolBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.sameLine();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		var io = ImGui.getIO();
		if( ImGui.isWindowHovered() )
		{
			var startPos: ImVec2 = ImGui.getCursorScreenPos();
			var mousePos: ImVec2 = ImGui.getMousePos();

			mouseScenePos = {x: ( mousePos.x - startPos.x) / zoom, y: ( mousePos.y - startPos.y ) / zoom };


			if( io.KeyCtrl )
			{
				ImGui.setKeyOwner( ImGuiKey.MouseWheelY, 0 );
				if ( ImGui.isKeyPressed( ImGuiKey.MouseWheelY ) )
				{
					zoom += io.MouseWheel > 0 ? 1 : -1;
					zoom = CMath.iclamp(zoom,1,20);
				}

			}




		}
		else
		{
			mouseScenePos = null;
		}

		ImGui.image(sceneRT, { x: sceneRT.width * zoom, y: sceneRT.height * zoom }, null, null, null, {x: 1, y: 1, z:1, w:1} );


		ImGui.end();


		propertiesColumn();
		layoutColumn();



		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

		processSceneMouse( delta );





	}

	function toolBar()
	{
		var style = ImGui.getStyle();

		if( toolBarButton("\uf245", paintMode == Select ) )
			paintMode = Select;

		ImGui.sameLine();

		if( toolBarButton("\uf303", paintMode == Normal ) )
			paintMode = Normal;

		ImGui.sameLine();

		if( toolBarButton("\uf575", paintMode == Fill ) )
			paintMode = Fill;

		ImGui.sameLine();

		if( toolBarButton("\uf0eb", paintMode == Entity ) )
			paintMode = Entity;



	}

	function toolBarButton(text: String, selected: Bool )
	{
		if( !selected )
			ImGui.pushStyleColor(ImGuiCol.Button, ImVec4.getColor(0x555555) );

		var ret = ImGui.button(text);

		if( !selected )
			ImGui.popStyleColor();

		return ret;
	}

	function layoutColumn()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Layout##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		var classList = CompileTime.getAllClasses(cerastes.c2d.TileEntity);
		if( classList != null )
		{
			var options = cerastes.EntityBuilder.list( TileEntityDef );

			var ret = IG.comboFilter( "Entity", options, paintEntityFilterState, paintEntityType );
			if( ret != null )
			{
				paintEntityType = ret;
				paintEntityFilterState = {};
				paintMode = Entity;
			}
		}

		//ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.text("Layers");
		//ImGui.popFont();
		if( ImGui.beginChildFrame( ImGui.getID( "frame1" ), {x: -1, y: 100 * ImGuiToolManager.scaleFactor} ) )
		{
			if( ImGui.beginTable("table", 3, ImGuiTableFlags.SizingStretchProp ) )
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

					var name = l.name != null && l.name.length > 0 ? l.name : 'Layer ${i}';
					if( ImGui.treeNodeEx( name, flags ) )
					{
						ImGui.treePop();
					}

					if( ImGui.isItemClicked() )
						selectLayer( l );

					var popupIdRC = 'tme_rc_layer_${windowID()}_${i}';

					if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
					{
						ImGui.openPopup( popupIdRC );
					}

					if( ImGui.beginPopup( popupIdRC ) )
					{
						if( ImGui.menuItem( '\uf1f8 Delete') )
						{
							if( selectedLayer == l)
								selectedLayer = null;
							tileMapDef.layers.splice(i,1);
						}
						ImGui.endPopup();
					}

					ImGui.tableNextColumn();
					if( ImGui.checkbox("##hidden", l.hidden) )
						updateScene();
					ImGui.tableNextColumn();
					ImGui.checkbox("##locked", l.locked);


				}
				ImGui.endTable();
				if( ImGui.button("New Layer") )
				{
					var l: TileMapLayerDef = {};
					l.resize(tileMapDef.width, tileMapDef.height);
					tileMapDef.layers.push(l);
				}
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

		if( selectedLayer.name == null)
			selectedLayer.name = "";

		wref( ImGui.inputText("Name", _), selectedLayer.name );


		switch( paintMode )
		{
			case Select:
				ImGui.pushID("EntityEditor");
				if( selectedEntity != null )
				{
					ImGui.text( selectedEntity.type );

					// @todo DON"T DO THIS
					var clsInst = EntityBuilder.defMap[selectedEntity.type];
					var cls = Type.getClass( clsInst );
					if( Utils.verify( cls != null, 'Unknown TileMapEntity def type ${selectedEntity.type}Def'))
					{
						var meta: haxe.DynamicAccess<Dynamic> = Meta.getFields( cls );
						for( field => data in meta )
						{
							var metadata: haxe.DynamicAccess<Dynamic> = data;
							if( metadata.exists("editor") )
							{
								var tooltip = null;
								if( metadata.exists("editorTooltip") )
								{
									tooltip = metadata.get("editorTooltip")[0];
								}
								var args = metadata.get("editor");

								var changed = ImGuiToolManager.renderElement(
									field,
									args[1],
									args,
									(field) -> {
										return selectedEntity.properties != null ? selectedEntity.properties.get(field) : "";
									},
									(field, val) -> {
										if( selectedEntity.properties == null )
											selectedEntity.properties = [];
										selectedEntity.properties.set(field, val);
									},
									tooltip
								);

								if( changed )
									updateScene();
							}
						}
					}

				}
				else
				{
					ImGui.text("No entity selected");
				}
				ImGui.popID();

			case Fill | Normal:
				var newTexture = IG.inputTexture( "Tile Sheet", selectedLayer.tileData.tileSheet, "sheets" );
				if( newTexture != null )
				{
					selectedLayer.tileData.tileSheet = newTexture;
					updateScene();
					// re-select layer to update the preview tiles
					selectLayer( selectedLayer );

				}

				ImGui.text("Palette");

				var tex = Utils.resolveTexture( selectedLayer.tileData.tileSheet );

				var startPos: ImVec2 = ImGui.getCursorScreenPos();
				var mousePos: ImVec2 = ImGui.getMousePos();

				var pickerZoom = 2;
				var pickerMousePos = {x: ( mousePos.x - startPos.x) / pickerZoom, y: ( mousePos.y - startPos.y ) / pickerZoom };
				var pw = tex.width;
				var ph = tex.height;
				ImGui.image( tex, {x: pw * pickerZoom, y: ph * pickerZoom }, null, null, null, {x: 1, y:1, z: 1, w: 1 } );
				var restorePos = ImGui.getCursorPos();

				if( pickerMousePos.x > 0 && pickerMousePos.x < pw && pickerMousePos.y > 0 && pickerMousePos.y < ph )
				{
					var tx: Int = Math.floor(pickerMousePos.x / selectedLayer.tileData.tileWidth );
					var ty: Int = Math.floor(pickerMousePos.y / selectedLayer.tileData.tileHeight );

					var drawSelect = false;

					if( ImGui.isItemClicked() )
					{
						selectedTile = cast tx + ty * ( tex.width / selectedLayer.tileData.tileWidth );
						selectedTileEnd = selectedTile;
						drawSelect = true;
					}
					if( ImGui.isMouseDown( ImGuiMouseButton.Left ))
					{
						selectedTileEnd = cast tx + ty * ( tex.width / selectedLayer.tileData.tileWidth );
						drawSelect = true;
						if( selectedTileEnd != selectedTile )
						{
							randomRotation = false;
							tileRotation = tileRotation & ~TileMapTileFlags.FlipFlags;
							if( paintMode == Fill ) paintMode = Normal;
						}

					}

					var px, py, tw, th: Int;

					if( drawSelect )
					{
						var tsw: Int = cast tex.width / selectedLayer.tileData.tileWidth;

						var tsx: Int = selectedTile % tsw;
						var tsy: Int = cast selectedTile / tsw;

						var tex: Int = selectedTileEnd % tsw;
						var tey: Int = cast selectedTileEnd / tsw;

						tw = tex - tsx + 1;
						th = tey - tsy + 1;

						px = tsx * selectedLayer.tileData.tileWidth * pickerZoom;
						py = tsy * selectedLayer.tileData.tileHeight * pickerZoom;

					}
					else
					{
						tw = 1;
						th = 1;

						px = tx * selectedLayer.tileData.tileWidth * pickerZoom;
						py = ty * selectedLayer.tileData.tileHeight * pickerZoom;
					}


					var offset: ImVec2 = {x: px, y: py};
					ImGui.setCursorScreenPos( startPos + offset );
					ImGui.imageTile( Tile.fromColor(0xFFFFFF, 1, 1, 0.25), {x:selectedLayer.tileData.tileWidth * tw * pickerZoom, y: selectedLayer.tileData.tileHeight * th * pickerZoom} );
				}

				ImGui.setCursorPos( restorePos );

				ImGui.checkbox("Random rotation", randomRotation);

			case Entity:


		}


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
		tileMapDefPreview.clear();
		if( isMouseOverViewport )
		{
			switch( paintMode )
			{
				case Select:
					if( selectedLayer != null )
					{
						if( ImGui.isMouseDown( ImGuiMouseButton.Left ) )
						{
							for( e in selectedLayer.entities )
							{
								if( e.x <= mouseScenePos.x && e.x + e.width >= mouseScenePos.x && e.y <= mouseScenePos.y && e.y + e.height >= mouseScenePos.y )
								{
									selectedEntity = e;
								}
							}
						}
					}


				default:

					if( selectedLayer != null )
					{
						var cx: Int = cast mouseScenePos.x / selectedLayer.tileData.tileWidth;
						var cy: Int = cast mouseScenePos.y / selectedLayer.tileData.tileHeight;

						if( selectedTile == -1 )
						{
							cursor.alpha = 0.35;
							cursor.beginFill(0xFFFFFF);
							cursor.drawRect( cx * selectedLayer.tileData.tileWidth, cy * selectedLayer.tileData.tileHeight, selectedLayer.tileData.tileWidth, selectedLayer.tileData.tileHeight );
							cursor.endFill();
						}
						else
						{
							blit( cx, cy, selectedTile, selectedTileEnd, tileMapDefPreview.layers[0] );
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
		tileMapPreview.rebuild();

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
		// If we're intentionally chosing a rotation, stop picking them randomly.
		randomRotation = false;
	}

	function tileMapClicked(x: Int, y: Int )
	{
		lastDownX = x;
		lastDownY = y;

		switch( paintMode )
		{
			case Normal:
				blit( x, y, selectedTile, selectedTileEnd, selectedLayer );
			case Fill:
				var target = selectedLayer.tileData.getIdx(x, y);
				fill(x, y, selectedTile, target, selectedLayer );
			case Entity:
				if( paintEntityType != null )
				{
					var e: TileMapEntityDef = {
						type: paintEntityType,
						x: x * selectedLayer.tileData.tileWidth,
						y: y * selectedLayer.tileData.tileHeight,
						width: selectedLayer.tileData.tileWidth, // @ todo: Zones
						height: selectedLayer.tileData.tileHeight,
					};

					selectedLayer.entities.push(e);

				}
			case Select:
		}

		updateScene();
	}

	function fill( x: Int, y: Int, tile: Int, target: Int, layer: TileMapLayerDef )
	{
		if( x >= layer.tileData.width || x < 0 || y >= layer.tileData.height || y < 0 )
			return;

		var t = layer.tileData.getIdx(x,y);
		if( t != target || t == tile )
			return;

		blit(x,y,tile,tile,layer);

		fill(x+1, y, tile, target, layer);
		fill(x-1, y, tile, target, layer);
		fill(x, y+1, tile, target, layer);
		fill(x, y-1, tile, target, layer);
	}

	function blit(x: Int, y: Int, startTile: Int, endTile: Int, layer: TileMapLayerDef )
	{
		var flags = tileRotation;


		if( randomRotation )
		{
			flags = Std.random( TileMapTileFlags.FlipFlags );
			tileRotation = flags;
		}

		var tileTex = Utils.resolveTexture( layer.tileData.tileSheet );

		var tsw: Int = cast tileTex.width / layer.tileData.tileWidth;

		var tsx: Int = startTile % tsw;
		var tsy: Int = cast startTile / tsw;

		var tex: Int = endTile % tsw;
		var tey: Int = cast endTile / tsw;


		for( tileOffsetX in 0 ... tex - tsx + 1 )
		{
			for( tileOffsetY in 0 ... tey - tsy + 1 )
			{
				var selectedTileOffset: Int = tileOffsetX + ( tileOffsetY * tsw );
				layer.tileData.setIdx(x + tileOffsetX,y + tileOffsetY,startTile + selectedTileOffset, flags);
			}
		}
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

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.2, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.50, null, idOut);
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