
package cerastes.tools;

#if hlimgui
using imgui.ImGui.ImGuiKeyStringExtender;
import cerastes.tools.ImguiTools.ImGuiTools;
import cerastes.tools.ImguiTools.IGTimelineState;
import cerastes.c2d.Vec2;
import h2d.BlendMode;

import h3d.scene.Object.ObjectFlags;
import cerastes.ui.Timeline;
import cerastes.macros.Metrics;
import cerastes.ui.UIEntity;
import cerastes.tools.ImguiTool.ImGuiPopupType;
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

enum UIEInspectorMode
{
	Element;
	Timeline;
}

enum UIDraggingOpType
{
	Start;
	End;
	Line;
}


@:keep
@multiInstance(true)
class UIEditor extends ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;
	var viewportScale: Int;

	var preview: h2d.Scene;
	var previewRoot: Object;
	var sceneRT: Texture;
	var sceneRTId: Int;

	var rootDef: CUIObject;
	var timelines: Array<Timeline>;

	var treeIdx = 0;
	var selectedInspectorTree: CUIObject;
	var selectedDragDrop: CUIObject;
	var selectedTimeline: Timeline;
	var selectedTimelineOperation: TimelineOperation;
	var selectedScript: UIScript;
	var inspectorMode: UIEInspectorMode = Element;

	var scaleFactor = Utils.getDPIScaleFactor();

	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;
	var dockspaceIdBottom: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	var selectedItemBorder: Graphics;
	var cursor: Graphics;

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

	public override function getName() { return '\uf108 UI Editor ${fileName != null ? '($fileName)' : ""}'; }

	public function new()
	{
		var size = haxe.macro.Compiler.getDefine("windowSize");

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;
		viewportScale = viewportDimensions.scale;
		preview = new h2d.Scene();
		preview.scaleMode = Fixed(viewportWidth,viewportHeight, 1, Left, Top);
		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		selectedItemBorder = new h2d.Graphics();
		cursor = new h2d.Graphics();


		rootDef = {
			type: "h2d.Object",
			name:"root",
			children: []
		};
		timelines = [];

		updateScene();
	}

	public override function openFile( f: String )
	{
		fileName = f;

		try
		{
			var res = new cerastes.fmt.CUIResource( hxd.Res.loader.load(fileName).entry );
			var data = res.getData();
			rootDef = data.root;

			timelines = data.timelines != null ? data.timelines : [];
			CUIResource.recursiveUpgradeObjects( rootDef, data.version );
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
		preview.removeChildren();
		//previewRoot = new Object(preview);

		// @todo: This really sucks. We should find a better way to do this.
		var f: CUIFile = {
			version: 3,
			root: null,
			timelines: timelines
		};
		var res = new CUIResource(null);
		@:privateAccess res.data = f;

		rootDef.initChildren();
		cerastes.fmt.CUIResource.initializeEntities = initializeObjects;
		previewRoot = res.defToObject(rootDef, null, true);
		previewRoot.timelineDefs = timelines;
		preview.addChild(previewRoot);

		//selectedItemBorder = new Graphics();
		preview.addChild(selectedItemBorder);
		preview.addChild(cursor);

		cerastes.fmt.CUIResource.initializeEntities = true;
		Metrics.end();

	}

	function updateDef( e: Object, o: CUIObject )
	{
		Metrics.begin();
		cerastes.fmt.CUIResource.initializeEntities = initializeObjects;
		cerastes.fmt.CUIResource.updateObject(o, e, initializeObjects);
		@:privateAccess e.onContentChanged();
		cerastes.fmt.CUIResource.initializeEntities = true;
		Metrics.end();
	}

	function updateDefRecursive( e: Object, o: CUIObject )
	{
		Metrics.begin();
		cerastes.fmt.CUIResource.initializeEntities = initializeObjects;
		cerastes.fmt.CUIResource.recursiveUpdateObjects(o, e, initializeObjects);
		@:privateAccess e.onContentChanged();
		cerastes.fmt.CUIResource.initializeEntities = true;
		Metrics.end();
	}

	function scriptEditor()
	{
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		if( focusScript )
		{
			focusScript = false;
			ImGui.setNextWindowFocus();
		}
		if( ImGui.begin('Script##${windowID()}') )
		{
			if( selectedScript != null )
			{
				var area = ImGui.getContentRegionAvail();
				var ref: hl.Ref<String> = selectedScript.script;
				wref( ImGui.inputTextMultiline('##scripted${windowID()}', _, area), selectedScript.script);

			}
			else
			{
				ImGui.text("No script selected...");
			}
		}
		ImGui.end();
	}

	function inspectorColumn()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Inspector##${windowID()}') )
		{
			handleShortcuts();

			// Buttons
			if( ImGui.button("Add") )
			{
				ImGui.openPopup("uie_additem");
			}

			if( ImGui.beginPopup("uie_additem") )
			{
				var types = ["h2d.Object", "h2d.Text", "h2d.TextInput", "h2d.Bitmap", "h2d.Anim", "h2d.Flow", "h2d.Mask", "h2d.Interactive", "h2d.ScaleGrid", "cerastes.ui.Button", "cerastes.ui.AdvancedText", "cerastes.ui.Reference", "cerastes.ui.Sound", "cerastes.ui.Anim"];

				for( t in types )
				{
					if( ImGui.menuItem( '${getIconForType(t)} ${getNameForType(t)}') )
						addItem(t);
				}

				ImGui.endPopup();
			}
			ImGui.sameLine();

			if( ImGui.button("Delete") && selectedInspectorTree != null )
			{
				var parent = getDefParent( selectedInspectorTree );
				if( parent == null )
				{
					Utils.error("?????");
				}
				else
				{
					parent.children.remove(selectedInspectorTree);
					selectDef( null );
					updateScene();
				}


			}


			if( ImGui.beginChild("uie_inspector_tree",null, false, ImGuiWindowFlags.AlwaysAutoResize) )
			{

				populateInspector();

				ImGui.endChild();
			}



			//ImGui.endChild();
		}
		ImGui.end();

	}

	function timelineColumn()
	{

		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		if( ImGui.begin('Timelines##${windowID()}') )
		{
			handleShortcuts();

			// Buttons
			if( ImGui.button("Add") )
			{
				var t: Timeline = {};
				t.name = "New Timeline";
				timelines.push( t );
			}


			ImGui.sameLine();

			if( ImGui.button("Delete") && selectedTimeline != null )
			{
				timelines.remove(selectedTimeline);
				selectedTimeline = null;
			}


			if( ImGui.beginChild("uie_timeline_list",null, false, ImGuiWindowFlags.AlwaysAutoResize) )
			{

				var idx = 0;
				for( t in timelines)
				{
					var flags = ImGuiTreeNodeFlags.Leaf | ImGuiTreeNodeFlags.DefaultOpen;

					if( selectedTimeline == t )
						flags |= ImGuiTreeNodeFlags.Selected;

					var name = t.name;
					var isOpen: Bool = ImGui.treeNodeEx( name, flags );

					var popupIdRC = 'timeline_entry_rc${windowID()}_${idx++}';

					if( ImGui.isItemClicked() )
					{
						selectedTimeline = t;
						timelineState = null;
						timelineRunner = new TimelineRunner( t, rootDef.handle );
						timelineRunner.playing = true;
						inspectorMode = Timeline;
						selectedTimelineOperation = null;
					}

					if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
					{
						selectedTimeline = t;
						ImGui.openPopup( popupIdRC );
					}

					if( ImGui.beginPopup( popupIdRC ) )
					{
						if( ImGui.menuItem( '\uf084 Clone') )
						{
							var nt = t.clone();
							timelines.push(nt);
						}
						ImGui.endPopup();
					}

					if( isOpen )
						ImGui.treePop();

				}



				ImGui.endChild();
			}
		}
		ImGui.end();

	}

	var timelineState: IGTimelineState = null;
	var dragStartFrame = -1;
	var draggingOp: TimelineOperation = null;
	var draggingOpType: UIDraggingOpType = Start;

	function timeline()
	{
		ImGui.pushStyleVar( ImGuiStyleVar.WindowPadding,{x: 0, y: 0} );
		ImGui.setNextWindowDockId( dockspaceIdBottom, dockCond );
		var style = ImGui.getStyle();


		if( ImGui.begin('Timeline##${windowID()}', null, ImGuiWindowFlags.NoMove ) )
		{
			handleShortcuts();

			if( selectedTimeline != null )
			{
				if( timelinePlay )
					frame = timelineRunner.frame;

				// Unset
				if( timelineState == null )
				{
					timelineState = {
						frameMax: selectedTimeline.frames,
						rowHeight: 18 * scaleFactor,
						headerHeight: 16 * scaleFactor,
						frames: selectedTimeline.frames,
					};
				}


				var groupings = new Map<String,Array<TimelineOperation>>();
				var groupWidth: Float = 0;


				for( op in selectedTimeline.operations )
				{
					var key = '${op.target}';
					if( !groupings.exists(key) )
						groupings.set(key, [op]);
					else
						groupings[key].push(op);

					var w = ImGui.calcTextSize(op.key );
					if( w.x > groupWidth )
						groupWidth = w.x;
				}

				groupWidth += style.CellPadding.x * 4;

				timelineState.groupWidth = groupWidth;
				timelineState.frames = selectedTimeline.frames;

				var childSize = ImGui.getContentRegionAvail();

				var scrubPosition = timelineRunner.time * selectedTimeline.frameRate;
				var scrubWidth = timelineState.regionWidth;
				var pixelsPerFrame = ( selectedTimeline.frames / scrubWidth );

				var opIdx = 0;

				if( ImGuiTools.beginTimeline( timelineState, childSize, scrubPosition ) )
				{
					// Scrub head was clicked
					if( ImGui.isItemClicked() || ( ImGui.isItemHovered() && ImGui.isMouseDown( ImGuiMouseButton.Left ) ) )
					{
						var mousePos = ImGui.getMousePos();
						var cursorPos = ImGui.getCursorScreenPos();
						var scrubX = mousePos.x - cursorPos.x - timelineState.groupWidth;// + scrollX;
						var frame = pixelsPerFrame * scrubX;
						@:privateAccess
						{
							timelineRunner.setTime( Math.max( frame / selectedTimeline.frameRate, 0 ) );
						}
					}

					// null is a valid key for new keyframes so.... just pick something
					// very unlikely to be invalid.
					// If you ever hit this bug then CONGRATULATIONS!
					var invalidKey = "☃__=-./*-+";
					var lastKey = invalidKey;
					for( key => ops in groupings )
					{
						ops.sort((a, b) -> {return Reflect.compare(a.key, b.key); });
						// Grouping header

						IG.timelineGroup(ops[0].target );

						for( op in ops )
						{
							opIdx++;
							var popupId = '${opIdx}_item_context';

							// Item header (only first time we see this key)
							if( lastKey != op.key )
							{
								if( lastKey != invalidKey )
									IG.endTimelineRow();
								lastKey = op.key;

								IG.beginTimelineRow( op.key != null ? op.key : "Unassigned" );


							}

							if( op.duration > 0 )
							{
								// Line
								IG.timelineLine(op.frame, op.frame + op.duration);
								imTooltip('${op.target}/${op.key}=${op.value}');
								if( ImGui.isItemClicked() )
								{
									inspectorMode = Timeline;
									selectedTimelineOperation = op;
								}
								if( draggingOp == null && ImGui.isItemHovered() && ImGui.isMouseDown( ImGuiMouseButton.Left ) )
								{
									draggingOp = op;
									dragStartFrame = op.frame;
									draggingOpType = Line;
								}
								if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
									ImGui.openPopup(popupId);

							}

							// Start handle
							IG.timelineHandle( op.frame );
							imTooltip('${op.target}/${op.key}=${op.value}');
							if( ImGui.isItemClicked() )
							{
								inspectorMode = Timeline;
								selectedTimelineOperation = op;
							}
							if( draggingOp == null && ImGui.isItemHovered() && ImGui.isMouseDown( ImGuiMouseButton.Left ) )
							{
								draggingOp = op;
								dragStartFrame = op.frame;
								draggingOpType = Start;
							}
							if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
								ImGui.openPopup(popupId);


							if( op.duration > 0 )
							{
								// End handle
								IG.timelineHandle( op.frame + op.duration );
								imTooltip('${op.target}/${op.key}=${op.value}');
								if( ImGui.isItemClicked() )
								{
									inspectorMode = Timeline;
									selectedTimelineOperation = op;
								}
								if( draggingOp == null && ImGui.isItemHovered() && ImGui.isMouseDown( ImGuiMouseButton.Left ) )
								{
									draggingOp = op;
									dragStartFrame = op.frame + op.duration;
									draggingOpType = End;
								}
								if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
									ImGui.openPopup(popupId);
							}

							// Right click context menu
							if( ImGui.beginPopup('${opIdx}_item_context') )
							{
								if( ImGui.menuItem( 'Delete') )
								{
									selectedTimeline.operations.remove(op);
									timelineRunner.stop();
									@:privateAccess timelineRunner.ensureState();
								}
								if( ImGui.menuItem( 'Clone') )
								{
									var c = op.clone();
									c.frame++;
									selectedTimeline.operations.push(c);
									// Flush state
									timelineRunner.stop();
									@:privateAccess timelineRunner.ensureState();
								}
								ImGui.endPopup();
							}

						}

						if( lastKey != invalidKey )
						{
							lastKey = invalidKey;
							IG.endTimelineRow();
						}
					}

					// Handle dragging
					if( !ImGui.isMouseDown( ImGuiMouseButton.Left ) )
						draggingOp = null;

					if( draggingOp != null && ImGui.isMouseDragging( ImGuiMouseButton.Left ) )
					{
						var delta = ImGui.getMouseDragDelta( ImGuiMouseButton.Left );
						var newFrame = Math.round( delta.x * pixelsPerFrame ) + dragStartFrame;

						if( draggingOpType == Line || ( draggingOpType == Start && draggingOp.duration == 0 ) )
						{
							if( draggingOp.frame != newFrame )
							{
								draggingOp.frame = newFrame;
								@:privateAccess timelineRunner.setTime( timelineRunner.time );
							}
						}
						else if( draggingOpType == Start )
						{
							if( draggingOp.frame != newFrame )
							{
								var delta = draggingOp.frame - newFrame;
								draggingOp.frame = newFrame;
								draggingOp.duration += delta;
								@:privateAccess timelineRunner.setTime( timelineRunner.time );
							}
						}
						else if ( draggingOpType == End )
						{
							if( draggingOp.frame + draggingOp.duration != newFrame )
							{
								var delta = draggingOp.frame + draggingOp.duration - newFrame;
								draggingOp.duration -= delta;
								@:privateAccess timelineRunner.setTime( timelineRunner.time );
							}
						}
					}

					ImGuiTools.endTimeline();

				}



			}
		}

		ImGui.end();
		ImGui.popStyleVar();
	}



	var frame: Int = 0;

	function editorColumn()
	{
		//ImGui.beginChild("uie_editor",{x: 300 * scaleFactor, y: viewportHeight}, false, ImGuiWindowFlags.AlwaysAutoResize);
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		if( ImGui.begin('Editor##${windowID()}') )
		{
			handleShortcuts();

			if( inspectorMode == Element )
			{

				if( selectedInspectorTree == null )
				{
					ImGui.text("No item selected...");
				}
				else
				{
					populateEditor();
				}
			}
			else if( inspectorMode == Timeline )
			{
				if( selectedTimelineOperation == null )
				{
					populateTimelineEditor();
				}
				else
				{
					populateKeyframeEditor();
				}
			}

			//ImGui.endChild();
		}
		ImGui.end();
	}

	function saveAs()
	{
		hxd.System.allowTimeout = false;
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes UI files", exts:["ui"]}
			]
		});
		hxd.System.allowTimeout = true;
		if( newFile != null )
		{
			fileName = Utils.toLocalFile( newFile );
			CUIResource.writeObject(rootDef, timelines, preview,newFile);

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

		CUIResource.writeObject(rootDef,timelines,preview,fileName);

		lastSaved = Sys.time() * 1000;
		ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
	}

	function handleShortcuts()
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
		Metrics.begin();
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		var saveString = ( Sys.time() * 1000 ) - lastSaved < 5000 ? " - Saved!" : "";

		if( forceFocus )
		{
			forceFocus = false;
			ImGui.setNextWindowFocus();
		}
		ImGui.setNextWindowSize({x: viewportWidth * 2, y: viewportHeight * 1.6}, ImGuiCond.Once);
		if( ImGui.begin('\uf108 UI Editor ${fileName != null ? fileName : ""} ${saveString}###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar ) )
		{

			menuBar();

			dockSpace();

			ImGui.dockSpace( dockspaceId, null );
		}
		ImGui.end();

		// Selected Border stuff
		processSelection();


		timelineColumn();
		inspectorColumn();

		timeline();
		scriptEditor();

		//ImGui.sameLine();

		// Preview
		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		if( ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar ) )
		{
			handleShortcuts();

			ImGui.checkbox("Show markers", showMarkers );
			ImGui.sameLine();
			if( ImGui.checkbox("Initialize Objects", initializeObjects ) )
				updateScene();

			ImGui.image(sceneRT, { x: viewportWidth * zoom, y: viewportHeight * zoom }, null, null, null, {x: 1, y: 1, z:1, w:1} );

			// Lock mouse wheel when hovering image (for zoom)
			// @todo: This crashes under linux
			// hl: /home/spitko/work/titan/haxe_modules/hlimgui/extension/lib/imgui/imgui.cpp:9382: void ImGui::SetKeyOwner(ImGuiKey, ImGuiID, ImGuiInputFlags): Assertion `IsNamedKeyOrModKey(key) && (owner_id != ((ImGuiID)0) || (flags & (ImGuiInputFlags_LockThisFrame | ImGuiInputFlags_LockUntilRelease)))' failed.

			if( ImGui.isItemHovered() && Sys.systemName() != "Linux" )
				ImGui.setKeyOwner( ImGuiKey.MouseWheelY, 0 );

			if( ImGui.isWindowHovered() )
			{
				var startPos: ImVec2 = ImGui.getCursorScreenPos();
				var mousePos: ImVec2 = ImGui.getMousePos();

				mouseScenePos = {x: ( mousePos.x - startPos.x) / zoom, y: ( mousePos.y - startPos.y ) / zoom };

				var io = ImGui.getIO();
				if ( ImGui.isKeyPressed( ImGuiKey.MouseWheelY ) )
				{
					zoom += io.MouseWheel > 0 ? 1 : -1;
					zoom = CMath.iclamp(zoom,1,20);
				}

			}
			else
			{
				mouseScenePos = null;
			}
		}
		ImGui.end();

		//ImGui.sameLine();

		editorColumn();


		//ImGui.end();

		// Editor window

		dockCond = ImGuiCond.Appearing;

		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

		processSceneMouse( delta );

		var io = ImGui.getIO();
		if( !io.WantCaptureKeyboard )
		{
			if( ImGui.isKeyPressed( ImGuiKey.Space ) && selectedTimeline != null )
			{
				if( timelineRunner.playing )
					timelineRunner.pause();
				else
				{
					if( timelineRunner.frame >= selectedTimeline.frames )
						timelineRunner.play();
					else
						timelineRunner.resume();
				}
			}
		}

		if( timelineRunner != null )
		{
			try
			{
				timelineRunner.tick(delta);
				if( timelineRunner.playing )
				{
					frame = Utils.clampInt( timelineRunner.frame, 0, selectedTimeline.frames );
				}
				else
				{
					// @todo WHY
					//timelineRunner.setFrame( frame );
				}
			}
			catch(e)
			{
				Utils.warning("Timeline crashed. :(");
			}
		}


		Metrics.end();
	}

	function processSelection()
	{
		selectedItemBorder.clear();
		if( selectedInspectorTree == null )
			return;

		if( !showMarkers )
			return;

		var o = selectedInspectorTree.handle;
		if( o == null )
			return;

		var type = Type.getClassName( Type.getClass( o ) );

		var bounds = o.getBounds();
		var size = o.getSize();

		var colBounds = 0x6666ff;
		var colMins = 0x66ff66;
		var colMaxs = 0xff6666;

		final lineWidth = 1;
		final lineAlpha = 0.75;

		if( bounds.getSize().x > 0 || bounds.getSize().y > 0 )
		{
			selectedItemBorder.lineStyle( lineWidth,colBounds, lineAlpha);
			selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, bounds.width, bounds.height);

			var flow: CUIFlow = Std.downcast( selectedInspectorTree, CUIFlow );
			if( flow != null )
			{
				selectedItemBorder.lineStyle( lineWidth,colMins, lineAlpha);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, flow.minWidth, flow.minHeight);
				selectedItemBorder.lineStyle( lineWidth,colMaxs, lineAlpha);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, flow.maxWidth, flow.maxHeight);

				var fe: h2d.Flow = Std.downcast( o, h2d.Flow );

				selectedItemBorder.lineStyle( lineWidth,0xffff00, lineAlpha);
				selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, @:privateAccess fe.calculatedWidth, @:privateAccess  fe.calculatedHeight);


			}
			else
			{
				var text: CUIText = Std.downcast( selectedInspectorTree, CUIText );
				if( text != null )
				{
					var t: h2d.Text = cast o;
					selectedItemBorder.lineStyle( lineWidth,colMaxs, lineAlpha);
					selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, text.maxWidth, t.textHeight);
				}
				else
				{

					var size = o.getSize();
					size.x += o.x;
					size.y += o.y;
					if( size.width != bounds.width || size.height != bounds.height )
					{
						selectedItemBorder.lineStyle( lineWidth, colBounds, lineAlpha);
						selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, bounds.width, bounds.height);

						selectedItemBorder.lineStyle( lineWidth, colMaxs, lineAlpha);
						selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, bounds.xMin + size.width, bounds.yMin + size.height);

					}

				}
			}




		}
		else if( size.xMax > 0 || size.yMax > 0 )
		{
			selectedItemBorder.lineStyle( lineWidth,colBounds, lineWidth);
			selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, bounds.width, bounds.height);

			selectedItemBorder.lineStyle( lineWidth,colMaxs, lineWidth);
			selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, size.width, size.height);
		}
		else if( Std.downcast( selectedInspectorTree, CUIMask ) != null )
		{
			var mask: h2d.Mask = cast o;
			selectedItemBorder.lineStyle( lineWidth,colBounds, lineWidth);
			selectedItemBorder.drawRect(bounds.xMin, bounds.yMin, mask.width, mask.height);

		}
		else
		{
			selectedItemBorder.lineStyle( lineWidth,colBounds, lineWidth);
			selectedItemBorder.drawRect(bounds.x, bounds.y, 1, 1);
		}


	}

	function selectDef( d: CUIObject )
	{
		var changed = d != selectedInspectorTree;
		if( !changed )
			return;

		selectedInspectorTree = d;
		selectedScript = null;
	}

	function processSceneMouse( delta: Float )
	{
		if( mouseScenePos == null )
			return;

		var isMouseOverViewport = mouseScenePos.x > 0 && mouseScenePos.x < viewportWidth && mouseScenePos.y > 0 && mouseScenePos.y < viewportHeight;
		if( isMouseOverViewport && ImGui.isMouseClicked(ImGuiMouseButton.Left) && previewRoot != null )
		{

			var matches = previewRoot.findAll(function(o: Object){
				var bounds = o.getBounds();
				return bounds.contains( new Point(mouseScenePos.x, mouseScenePos.y) ) ? o : null;
			});

			// return the highest match

			if( matches.length > 0 )
			{
				var target = matches[matches.length-1];
				while( target.name == null && target.parent != null )
					target = target.parent;

				var def = getElementDefByName( target.name, rootDef );
				if( def != null )
					selectDef( def );


			}
		}

		// Drag
		if( selectedInspectorTree != null )
		{
			var o = selectedInspectorTree.handle;
			if( o == null )
			{
				Utils.warning("Lost selected object...");
				selectDef( null );
				return;
			}
			var bounds = o.getBounds();

			if( ImGui.isMouseDown( ImGuiMouseButton.Left ) )
			{
				if( mouseDragDuration == 0 )
				{
					// Make sure we're STARTING on bounds, we can leave it while we drag
					if( bounds.contains( new Point( mouseScenePos.x, mouseScenePos.y ) ) )
					{
						mouseDragStartPos = mouseScenePos;
						mouseDragDuration = delta;
					}
				}
				else
				{
					mouseDragDuration += delta;
				}
			}
			else
			{
				mouseDragDuration = 0;
			}

			if( mouseDragDuration > 0.1 && selectedInspectorTree != null )
			{

				o.x += mouseScenePos.x - mouseDragStartPos.x;
				o.y += mouseScenePos.y - mouseDragStartPos.y;

				mouseDragStartPos = mouseScenePos;
			}
		}
	}

	function getElementDefByName( name: String, def: CUIObject ) : CUIObject
	{
		if( def.name == name )
			return def;

		for( c in def.children )
		{
			var def = getElementDefByName(name, c );
			if( def != null )
				return def;
		}

		return null;
	}

	public override inline function windowID()
	{
		return 'spre${fileName != null ? fileName : ""+toolId}';
	}

	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = "UIEditorDockspace";

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



	function populateInspector()
	{
		if( rootDef == null )
			return;
		// @todo this is dumb.
		var dd: CUIObject = {
			type:"dummy",
			name:"dummy",
			children: [rootDef]
		};
		treeIdx = 0;
		populateChildren(dd);


	}

	function getAutoName( type: String )
	{
		var name;
		var n = 0;
		do
		{
			name = '${getNameForType(type)} ${++n}';
		} while( preview.getObjectByName(name) != null );

		return name;
	}

	function populateChildren( def: CUIObject )
	{
		for( idx in 0 ... def.children.length )
		{
			var c = def.children[idx];
			if( c == null )
				break;

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			if( c.children.length == 0)
				flags |= ImGuiTreeNodeFlags.Leaf;

			if( selectedInspectorTree == c )
				flags |= ImGuiTreeNodeFlags.Selected;

			var name = c.name  != null ? c.name : '${c.type}/{$treeIdx}';
			name = '${getIconForType( c.type )} ${name}';
			var isOpen = ImGui.treeNodeEx( name, flags );

			if( ImGui.isItemClicked() )
			{
				selectDef( c );
				inspectorMode = Element;
			}

			if( ImGui.isItemClicked( ImGuiMouseButton.Right ) )
				ImGui.openPopup('${c.name}_uie_context');

			// Drag source
			var srcFlags: ImGuiDragDropFlags  = 0;
			srcFlags |= ImGuiDragDropFlags.SourceNoPreviewTooltip;

			if( ImGui.beginDragDropSource( srcFlags ) )
			{
				ImGui.setDragDropPayloadObject("uiDef", c );

				ImGui.beginTooltip();


				ImGui.text(name);


				ImGui.endTooltip();

				ImGui.endDragDropSource();
			}

			if( ImGui.beginDragDropTarget() )
			{
				var targetFlags : ImGuiDragDropFlags = 0;

				var dropDef: CUIObject = cast ImGui.acceptDragDropPayloadObject("uiDef");
				if( dropDef != null )
				{
					selectedDragDrop = dropDef;
					ImGui.openPopup('${c.name}_uie_popup');
				}

				ImGui.endDragDropTarget();
			}

			if( ImGui.beginPopup('${c.name}_uie_popup') )
			{
				if( ImGui.menuItem( '\uf30c Move Above') )
				{
					var oldParent = getDefParent(selectedDragDrop);
					oldParent.children.remove(selectedDragDrop);

					var newIdx = def.children.indexOf(c);
					def.children.insert(newIdx,selectedDragDrop);

					updateScene();
				}
				if( ImGui.menuItem( '\uf2f5 Make child') )
				{
					var oldParent = getDefParent(selectedDragDrop);
					// Make sure we're not about to orphan this tree
					var isChildOfParent = getDefParent( c,selectedDragDrop ) != null;

					if( !isChildOfParent && oldParent != null )
					{
						oldParent.children.remove(selectedDragDrop);

						c.children.push(selectedDragDrop);

						updateScene();
					}


				}
				if( ImGui.menuItem( '\uf309 Move Below') )
				{
					var oldParent = getDefParent(selectedDragDrop);
					oldParent.children.remove(selectedDragDrop);

					var newIdx = def.children.indexOf(c);
					def.children.insert(newIdx+1,selectedDragDrop);

					updateScene();
				}


				ImGui.endPopup();
			}

			// Right click context menu
			if( ImGui.beginPopup('${c.name}_uie_context') )
			{
				if( ImGui.menuItem( '\uf24d Clone') )
				{
					var parent: h2d.Object = preview;
					if( c.handle != null && c.handle.parent != null )
						parent = c.handle.parent;

					var clone = c.clone((name) -> {
						var reg = ~/([0-9]+)([^0-9]*)$/;
						if( reg.match(name) )
						{
							var endNum = reg.matched(0);
							var num = Std.parseInt( endNum );
							var newName: String;
							do
							{
								num++;
								newName = reg.replace( name, '${Std.string( num )}$2' );
							}
							while( parent.getObjectByName(newName) != null );

							return newName;

						}
						return name + " 1";

					});
					var defParent = getDefParent(c);

					defParent.children.push( clone );

					updateScene();
				}

				if( selectedTimeline != null && ImGui.menuItem('\uf084 Keyframe here') )
				{
					var t: TimelineOperation = {};
					t.target = c.name;
					t.frame = frame >= selectedTimeline.frames ? selectedTimeline.frames - 1 : frame;
					selectedTimeline.operations.push(t);
					selectedTimelineOperation = t;
					inspectorMode = Timeline;

				}

				ImGui.endPopup();
			}

			if( isOpen  )
			{
				if( c.children.length > 0)
				{
					ImGui.pushID( name );
					populateChildren(c);
					ImGui.popID();
				}
				ImGui.treePop();
			}

		}
	}

	function getDefByName(name: String, def: CUIObject = null )
	{
		if( def == null )
			def = rootDef;

		if( def.name == name )
			return def;

		for( c in def.children )
		{
			var d = getDefByName( name, c );
			if( d != null )
				return d;
		}
		return null;
	}

	function getDefParent(find: CUIObject, ?def: CUIObject = null )
	{
		if( def == null )
			def = rootDef;

		for( c in def.children )
		{
			if( c == find )
				return def;

			var d = getDefParent(find, c );
			if( d != null )
				return d;
		}
		return null;
	}


	override public function render( e: h3d.Engine)
	{
		Metrics.begin();
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
			preview.setElapsedTime( ImGui.getIO().DeltaTime );
			preview.render(e);
			e.width = oldW;
			e.height = oldH;
		}

		e.popTarget();
		Metrics.end();
	}

	function replaceDef( start: CUIObject, search: CUIObject, replace: CUIObject )
	{
		for( i in 0 ... start.children.length )
		{
			if( start.children[i] == search )
			{
				start.children[i] = replace;
				return;
			}
			else
			{
				replaceDef( start.children[i], search, replace );
			}
		}

	}

	function populateKeyframeEditor()
	{
		//var frame = populateKeyframeEditor.frame;

		if( populateOp( selectedTimelineOperation ) )
		{
			selectedTimeline.operations.remove(selectedTimelineOperation);
			selectedTimelineOperation = null;
		}

	}

	function populateTimelineEditor()
	{
		if( selectedTimeline == null )
		{
			ImGui.text("No timeline selected");
			return;
		}

		var nt = IG.textInput( "Name", selectedTimeline.name );
		if( nt != null && nt.length > 0 )
		{
			selectedTimeline.name = nt;
		}

		ImGui.inputInt( "Frames", selectedTimeline.frames );
		imTooltip("Total Number of frames. You can change this number at any time, the timeline will not rescale, so it's usually best to leave it high and reduce it when you're done.");

		ImGui.inputInt( "Frame rate", selectedTimeline.frameRate );
		imTooltip("Number of timeline to run per game frame. 10 is usually fine. Note this does NOT affect how smooth animations are, just how often we update the timeline.");

		var flags = ImGuiTreeNodeFlags.DefaultOpen;
		if( ImGui.collapsingHeader("Variables", flags) )
		{
			if( selectedTimeline.variables != null )
			{
				for( i in 0 ... selectedTimeline.variables.length )
				{
					ImGui.pushID('var${i}');
					var v = selectedTimeline.variables[i];
					wref( ImGui.inputText("Name", _), v.name);
					IG.combo("Type", v.type, cerastes.ui.Timeline.VariableType );
					var strVal = Std.string(v.val);
					if( ImGui.inputText("Default", strVal) )
					{
						v.val = TimelineVariable.convertString( v.type, strVal );
					}
					ImGui.popID();
				}
			}
			if( ImGui.button("Add"))
			{
				if( selectedTimeline.variables == null )
					selectedTimeline.variables = [];

				selectedTimeline.variables.push({
					val: "",
					type: Float,
					name: "variable"
				});
			}

		}
	}

	function populateOp( o: TimelineOperation )
	{
		var def = rootDef.getObjectByName(o.target);
		var validTarget = def != null;
		if( !validTarget )
			ImGui.pushStyleColor( ImGuiCol.Text, {x: 1, y: 0, z: 0, w: 1} );

		var nt = IG.textInput( "Target", o.target );
		if( nt != null && nt.length > 0 )
		{
			var isValid = preview.getObjectByName( nt ) != null;
			if( isValid )
				o.target = nt;
		}

		if( !validTarget )
			ImGui.popStyleColor();

		// Figure out what properties we can control
		if( def == null )
			return false;

		if( def.filter != null )
		{

			if( ImGui.beginCombo("Field Group", o.targetType == Filter ? "Filter" : "Properties") )
			{
				if( ImGui.selectable("Object", 	o.targetType == Object) )		o.targetType = Object;
				if( ImGui.selectable("Filter", 	o.targetType == Filter) )		o.targetType = Filter;

				ImGui.endCombo();
			}
			if( ImGui.isItemHovered() )
			{
				ImGui.beginTooltip();
				ImGui.text("Select \"Filter\" to adjust filter properties, else use Object for everything else");
				ImGui.endTooltip();
			}
		}

		var td: Dynamic = o.targetType == Filter ? def.filter : def;

		var canTween: Bool = false;
		var mType: String = null;

		if( def != null )
		{
			if( ImGui.beginCombo( "Field", o.key ) )
			{
				if( ImGui.selectable("None", o.key == null ) )
					o.key = null;

				var fields = Reflect.fields( td );
				for( f in fields )
				{
					var fv = Reflect.field(td,f);
					if( fv is Int || fv is Float || fv is Bool || fv is String )
					{
						if( ImGui.selectable(f, f == o.key) )
						{
							o.key = f;
							o.value = fv;
						}
					}
				}
				ImGui.endCombo();
			}

			if( o.key != null )
			{
				mType = CUIObject.getMetaForField(o.key, "cd_type", Type.getClass( td ) );

				var isVar: Bool = false;
				if( Std.string(o.value).charAt(0) == "$")
				{
					var t: String = o.value;
					if( ImGui.inputText( o.key, t ) )
						o.value = '☄☄TILE☄☄$t';

					if( o.value.charAt(0) != '$')
						o.value = 0;

					if( mType != "Bool" && mType != "String")
						canTween = true;
					isVar = true;
				}
				else if( mType == "Float" )
				{
					var v: Float = o.value;
					if( ImGui.inputDouble( o.key, v, 0.1, 1, "%.4f") )
						o.value = v;

					canTween = true;
				}
				else if( mType == "Int" )
				{
					var v: Int = o.value;
					if( ImGui.inputInt( o.key, v, 1,10 ) )
						o.value = v;

					canTween = true;
				}
				else if( mType == "Bool" )
				{
					var v: Bool = o.value;
					if( ImGui.checkbox( o.key, v ) )
						o.value = v;
				}
				else if( mType == "String" )
				{
					var v: String = o.value;
					if( ImGui.inputText( o.key, v ) )
						o.value = v;
				}
				else
				{
					trace( mType );
				}

				if( !isVar )
				{
					ImGui.sameLine();
					if( ImGui.button("\uf6e8"))
					{
						o.value = "$";
					}
				}

			}
			else
			{
				// Self referencing properties
				var anim = Std.downcast( def, CUIAnim );
				if( anim != null )
				{
					if( ImGui.beginCombo("Event type", o.type.toString() ) )
					{
						if( ImGui.selectable( OperationType.AnimPlay.toString(), 		o.type == AnimPlay ) )		o.type = AnimPlay;
						if( ImGui.selectable( OperationType.AnimPause.toString(), 		o.type == AnimPause ) )		o.type = AnimPause;
						if( ImGui.selectable( OperationType.AnimSetFrame.toString(), 	o.type == AnimSetFrame ) )	o.type = AnimSetFrame;

						ImGui.endCombo();
					}

					if( o.type == AnimSetFrame )
					{
						var v: Int = o.value;
						if( ImGui.inputInt( "Anim Frame", v, 1,10 ) )
							o.value = v;
					}
				}

				var sound = Std.downcast( def, CUISound );
				if( sound != null )
				{
					if( ImGui.beginCombo("Event type", o.type.toString() ) )
					{
						if( ImGui.selectable( OperationType.SoundPlay.toString(), 		o.type == SoundPlay ) )		o.type = SoundPlay;
						if( ImGui.selectable( OperationType.SoundStop.toString(), 		o.type == SoundStop ) )		o.type = SoundStop;

						ImGui.endCombo();
					}
				}
			}
		}



		ImGui.inputInt("Timeline Frame", o.frame );

		if( canTween )
		{
			if( ImGui.beginCombo("Tween type", o.type.toString() ) )
			{
				if( ImGui.selectable( OperationType.None.toString(), 		o.type == None ) )		o.type = None;
				if( ImGui.selectable( OperationType.Linear.toString(), 		o.type == Linear ) )	o.type = Linear;
				if( ImGui.selectable( OperationType.ExpoIn.toString(), 		o.type == ExpoIn ) )	o.type = ExpoIn;
				if( ImGui.selectable( OperationType.ExpoOut.toString(), 	o.type == ExpoOut ) )	o.type = ExpoOut;
				if( ImGui.selectable( OperationType.ExpoInOut.toString(), 	o.type == ExpoInOut ) )	o.type = ExpoInOut;

				ImGui.endCombo();
			}

			if( o.type != None )
			{
				ImGui.inputInt("Duration", o.duration );
				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("In timeline frames, so if your timeline is set to 10fps, a duration of 10 means 1s duration.");
					ImGui.endTooltip();
				}

				ImGui.inputDouble("Step Rate", o.stepRate, 1/15, 1/60, "%.4f" );
				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Sets how much time (in seconds) must pass before a transition is updated when playing. examples: 60fps -> 1/60 -> 0.016. 15fps -> 1/15 -> 0.06. By default (0) it will update every (screen) frame.");
					ImGui.endTooltip();
				}

				ImGui.checkbox("Int snap", o.intSnap );
				ImGui.checkbox("Specify start value", o.hasInitialValue );
				if( o.hasInitialValue )
				{
					ImGui.pushID("initialval");
					if( o.initialValue == null )
						o.initialValue = 0;

					var isVar = false;

					if( Std.string(o.initialValue).charAt(0) == "$")
					{
						var v: String = cast o.initialValue;
						if( ImGui.inputText( o.key, v ) )
						{
							o.initialValue = v;
							if( o.initialValue.charAt(0) != '$')
								o.initialValue = 0;
						}

						isVar = true;
					}
					else if( mType == "Float" )
					{
						var v: Float = o.initialValue;
						if( ImGui.inputDouble( o.key, v, 0.1, 1, "%.4f") )
							o.initialValue = v;

						canTween = true;
					}
					else if( mType == "Int" )
					{
						var v: Int = o.initialValue;
						if( ImGui.inputInt( o.key, v, 1,10 ) )
							o.initialValue = v;

						canTween = true;
					}
					else if( mType == "Bool" )
					{
						var v: Bool = o.initialValue;
						if( ImGui.checkbox( o.key, v ) )
							o.initialValue = v;
					}
					if( !isVar )
					{
						ImGui.sameLine();
						if( ImGui.button("\uf6e8"))
						{
							o.initialValue = "$";
						}
					}

					ImGui.popID();
				}
				else
				{
					o.initialValue = null;
				}
			}
		}


		if( ImGui.button("Delete"))
			return true;


		ImGui.separator();
		return false;

	}

	function populateEditor()
	{
		var def = selectedInspectorTree;
		ImGui.pushFont( ImGuiToolManager.headingFont );
		ImGui.text(def.type);
		ImGui.popFont();



		var obj = def.handle;
		if( obj == null )
			return;

		var newName = IG.textInput( "ID", def.name );
		if( newName != null && newName.length > 0 )
		{
			// Allow ID collisions in other heirarchy trees.
			var parent = obj;
			if( obj.parent != null )
				parent = obj.parent;


			var other = parent.getObjectByName(newName);
			if( other == null )
			{
				def.name = newName;
				updateScene();
			}
		}

		//if( def == rootDef )
		{
			// Add custom objects
			var classList = CompileTime.getAllClasses(UIEntity);
			if( classList != null )
			{
				var options = [ for(c in classList) Type.getClassName(c) ];

				if( ImGui.beginCombo( "Class", def.type ) )
				{
					if( ImGui.selectable( "h2d.Object", "h2d.Object" == def.type ) )
					{
						def.type = "h2d.Object";
						updateScene();
					}

					for( c in classList )
					{
						var cls = Type.getClassName(c);
						if( ImGui.selectable( cls, cls == def.type ) )
						{
							var fn = Reflect.field(c, "getDef");
							if( fn != null )
							{
								var newDef = fn();
								newDef.children = def.children;
								newDef.name = def.name;
								newDef.type = cls;
								newDef.x = def.x;
								newDef.y = def.y;
								newDef.scaleX = def.scaleX;
								newDef.scaleY = def.scaleY;
								newDef.rotation = def.rotation;
								newDef.visible = def.visible;

								if( def == rootDef )
								{
									rootDef = newDef;
								}
								else
								{
									replaceDef(rootDef, def, newDef );
								}
								updateScene();
							}

						}
					}
					ImGui.endCombo();
				}
			}

		}

		ImGui.pushID(def.name);

		ImGui.separator();


		populateEditorFields(obj, def, def.type);

		var s =  Type.getSuperClass( Type.getClass( obj ) );
		while( s != null )
		{
			var nt = Type.getClassName(s);
			if( nt != def.type )
				populateEditorFields( obj, def, Type.getClassName(s) );
			s = Type.getSuperClass( s );
		}

		updateDef( obj, def );

		ImGui.popID();
	}

	function editScript( script: UIScript )
	{
		focusScript = true;

		selectedScript = script;
	}

	//
	// Field related functions
	//
	function populateEditorFields(obj: Object, def: CUIObject, type: String )
	{
		switch( type )
		{
			case "cerastes.ui.UIEntity":
				return;
		}

		ImGui.pushID(type);

		if (!ImGui.collapsingHeader(type, ImGuiTreeNodeFlags.DefaultOpen ))
			return;

		switch( type )
		{
			case "h2d.Object":
				wref( ImGui.inputDouble("X",_,1,10,"%.2f"), def.x );
				wref( ImGui.inputDouble("Y",_,1,10,"%.2f"), def.y );
				var single: Single = def.rotation;
				if( wref( ImGui.sliderAngle("Rotation", _), single ) )
					def.rotation = single;

				wref( ImGui.inputDouble("Scale X",_,1,10,"%.2f"), def.scaleX );
				wref( ImGui.inputDouble("Scale Y",_,1,10,"%.2f"), def.scaleY );

				wref( ImGui.checkbox( "Visible", _ ), def.visible );

				ImGui.inputDouble("Alpha", def.alpha);

				var out = IG.combo("Blend Mode", def.blendMode, BlendMode );
				if( out != null )
					def.blendMode = out;


				var classList = CompileTime.getAllClasses(cerastes.pass.SelectableFilter);

				var curFilterName: String = null;
				if( def.filter != null )
				{
					var cl = Type.resolveClass(def.filter.type);
					var fn = Reflect.field(cl, "getEditorName");
					curFilterName = fn();
				}


				ImGui.separator();
				if( ImGui.beginCombo( "Filter", curFilterName != null ? curFilterName : "None" ) )
				{
					if( ImGui.selectable( "None", def.filter == null ) )
					{
						def.filter = null;
						updateScene();
					}

					for( c in classList )
					{
						var cls = Type.getClassName(c);
						var nameFn = Reflect.field(c, "getEditorName");

						if( ImGui.selectable( nameFn(), cls == def.type ) )
						{
							var fn = Reflect.field(c, "getDef");
							if( fn != null )
							{
								var filterDef = fn();
								filterDef.type = cls;
								def.filter = filterDef;
								updateScene();
							}

						}
					}
					ImGui.endCombo();
				}

				if( def.filter != null )
				{
					var cls = Type.resolveClass(def.filter.type);
					var fn = Reflect.field(cls, "getInspector");
					fn( def.filter );
				}

				if( ImGui.collapsingHeader( "Scripts" ) )
				{

					if( ImGui.button("OnAdd") ) { if( def.onAdd == null ) def.onAdd = {}; editScript( def.onAdd ); };
					if( ImGui.button("OnRemove") ) { if( def.onRemove == null ) def.onRemove = {}; editScript( def.onRemove ); };
					ImGui.separator();
					//if( ImGui.button("Timer1") ) editScript( def.onTimer1 );
					//if( ImGui.button("Timer2") ) editScript( def.onTimer2 );
					//if( ImGui.button("Timer3") ) editScript( def.onTimer3 );
					//if( ImGui.button("Timer4") ) editScript( def.onTimer4 );
				}



			case "h2d.Drawable":
				var d : CUIDrawable = cast def;
				// Color
				var nc = IG.inputColorInt( d.color );
				if( nc != null )
					d.color = nc;

				var smooth: Bool = d.smooth == CUITristateBool.True;

				ImGui.checkbox("Smooth", smooth);
				if( smooth == preview.defaultSmooth )
					d.smooth = CUITristateBool.Null;
				else
					d.smooth = smooth ? CUITristateBool.True : CUITristateBool.False;






			case "h2d.Text":
				var d: CUIText = cast def;

				var val = IG.textInputMultiline("Text", d.text, null, ImGuiInputTextFlags.Multiline);
				if( val != null )
					d.text = val;

				var newFont = IG.textInput( "Font", d.font );
				if( newFont != null && hxd.Res.loader.exists( newFont ) )
					d.font = newFont;

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && hxd.Res.loader.exists( payload ) )
						d.font = payload;

					ImGui.endDragDropTarget();
				}

				if( StringTools.endsWith( d.font, ".msdf.fnt" ) )
				{
					wref( ImGui.inputInt( "Font Size", _ ), d.sdfSize );
					wref( ImGui.inputDouble( "Alpha Cutoff", _ ), d.sdfAlpha );
					wref( ImGui.inputDouble( "Smoothing", _ ), d.sdfSmoothing );
				}

				var out = IG.combo("Text Align", d.textAlign, h2d.Text.Align );
				if( out != null )
					d.textAlign = out;


				var maxWidth: Float = d.maxWidth > 0 ? d.maxWidth : 0;
				if( wref( ImGui.inputDouble("Max Width",_,1,10,"%.2f"), maxWidth ) )
				{
					if( maxWidth > 0 )
						d.maxWidth = maxWidth;
					else
						d.maxWidth = -1;
				}

				ImGui.inputDouble( "Line Spacing", d.lineSpacing, 0.5, 1, "%.2f" );

			case "cerastes.ui.AdvancedText":

				var d: CUIAdvancedText = cast def;

				wref( ImGui.checkbox( "Ellipsis", _ ), d.ellipsis );
				wref( ImGui.inputInt( "Max Lines", _ ), d.maxLines );

				var newFont = IG.textInput( "Bold font", d.boldFont );
				if( newFont != null && hxd.Res.loader.exists( newFont ) )
					d.boldFont = newFont;

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Optional!Required to use bold text overrides though. The text will use the line height of whichever font is taller.");
					ImGui.endTooltip();
				}


				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && hxd.Res.loader.exists( payload ) )
						d.boldFont = payload;

					ImGui.endDragDropTarget();
				}
			case "h2d.TextInput":
				var d: CUITextInput = cast def;

				ImGui.checkbox( "Can Edit", d.canEdit );
				ImGui.inputInt( "Input Width", d.inputWidth );
				ImGui.inputInt( "Input Height", d.inputHeight );
				ImGui.checkbox( "Multiline", d.multiline );



			case "h2d.Bitmap":
				var d: CUIBitmap = cast def;


				var newTile = IG.inputTile( "Tile", d.tile );
				if( newTile != null )
					d.tile = newTile;

				var width: Float = d.width > 0 ? d.width : 0;
				if( wref( ImGui.inputDouble("Width",_,1,10,"%.2f"), width ) )
				{
					if( width > 0 )
						d.width = width;
					else
						d.width = -1;
				}

				var height: Float = d.height > 0 ? d.height : 0;
				if( wref( ImGui.inputDouble("Height",_,1,10,"%.2f"), height ) )
				{
					if( height > 0 )
						d.height = height;
					else
						d.height = -1;
				}

			case "cerastes.ui.AdvancedBitmap":
				var d: CUIAdvancedBitmap = cast def;

				wref( ImGui.inputInt("Clip X",_,1,10), d.clipX );
				wref( ImGui.inputInt("Clip Y",_,1,10), d.clipY );

				wref( ImGui.inputInt("Scroll X",_,1,10), d.scrollX );
				wref( ImGui.inputInt("Scroll Y",_,1,10), d.scrollY );

			case "h2d.Anim":
				var d: CUIAnim = cast def;


				var newTile = IG.inputTile( "Entry", d.entry );
				if( newTile != null )
					d.entry = newTile;

				wref( ImGui.inputDouble("Speed", _, 1, 5, "%.1f" ),  d.speed );
				ImGui.checkbox("Loop", d.loop );
				ImGui.checkbox("Autoplay", d.autoplay );


			case "cerastes.ui.Anim":
				var d: CUICAnim = cast def;


				var newTile = IG.inputTile( "Entry", d.entry );
				if( newTile != null )
					d.entry = newTile;

				ImGui.checkbox("Loop", d.loop );
				ImGui.checkbox("Autoplay", d.autoplay );

			case "h2d.Flow":
				var d: CUIFlow = cast def;
				var o: h2d.Flow = cast obj;


				var layout = IG.combo("Layout", d.layout, h2d.Flow.FlowLayout );
				if( layout != null )
					d.layout = layout;

				wref( ImGui.checkbox( "Wrap", _ ), d.multiline );
				imTooltip("When set to true, uses specified lineHeight/colWidth instead of maxWidth/maxHeight for alignment.");

				var align = IG.combo("Vertical Align", d.verticalAlign, h2d.Flow.FlowAlign );
				if( align != null )
					d.verticalAlign = align;

				align = IG.combo("Horizontal Align", d.horizontalAlign, h2d.Flow.FlowAlign );
				if( align != null )
					d.horizontalAlign = align;

				var overflow = IG.combo("Overflow", d.overflow, h2d.Flow.FlowOverflow );
				if( overflow != null )
					d.overflow = overflow;

				var minW: Int = d.minWidth != -1 ? cast d.minWidth : 0;
				var minH: Int = d.minHeight != -1 ? cast d.minHeight : 0;

				if( wref( ImGui.inputInt("Min Width",_,1,10), minW ) )
					d.minWidth = minW;

				if( wref( ImGui.inputInt("Min Height",_,1,10), minH ) )
					d.minHeight = minH;

				var maxW: Int = d.maxWidth != -1 ? cast d.maxWidth : 0;
				var maxH: Int = d.maxHeight != -1 ? cast d.maxHeight : 0;

				if( wref( ImGui.inputInt("Max Width",_,1,10), maxW ) )
					d.maxWidth = maxW;

				if( wref( ImGui.inputInt("Max Height",_,1,10), maxH ) )
					d.maxHeight = maxH;


				wref( ImGui.inputInt("Vertical Spacing",_,1,10), d.verticalSpacing );
				wref( ImGui.inputInt("Horizontal Spacing",_,1,10), d.horizontalSpacing );

				wref( ImGui.inputInt("Padding Top",_,1,10), d.paddingTop );
				wref( ImGui.inputInt("Padding Bottom",_,1,10), d.paddingBottom );
				wref( ImGui.inputInt("Padding Left",_,1,10), d.paddingLeft );
				wref( ImGui.inputInt("Padding Right",_,1,10), d.paddingRight );

				wref( ImGui.inputInt("Column Width",_,1,10), d.colWidth );
				imTooltip("Sets the minimum colum width when `Flow.layout` is `Vertical`.  (Wrap only)");

				wref( ImGui.inputInt("Line Height",_,1,10), d.lineHeight );
				imTooltip("Sets the minimum row height when `Flow.layout` is `Horizontal`. (Wrap only)");



				var newTile = IG.inputTile( "Background Tile", d.backgroundTile );
				if( newTile != null )
					d.backgroundTile = newTile;

				if( ImGui.isItemHovered() )
				{
					ImGui.beginTooltip();
					ImGui.text("Setting a background tile will create an ScaleGrid background which uses the borderWidth / borderHeigh values for its borders.");
					ImGui.endTooltip();
				}


				wref( ImGui.inputInt("Border Width",_,1,10), d.borderWidth );
				wref( ImGui.inputInt("Border Height",_,1,10), d.borderHeight );

				o.needReflow = true;

			case "h2d.Mask":
				var t : CUIMask = cast def;

				wref( ImGui.inputInt("Width",_,1,10), t.width );
				wref( ImGui.inputInt("Height",_,1,10), t.height );

				wref( ImGui.inputDouble("Scroll X",_,1,10,"%.2f"), t.scrollX );
				wref( ImGui.inputDouble("Scroll Y",_,1,10,"%.2f"), t.scrollY );

			case "h2d.ScaleGrid":
				var d : CUIScaleGrid = cast def;


				wref( ImGui.inputDouble("Width",_,1,10), d.width );
				wref( ImGui.inputDouble("Height",_,1,10), d.height );

				wref( ImGui.inputInt("Border Top",_,1,10), d.borderTop );
				wref( ImGui.inputInt("Border Bottom",_,1,10), d.borderBottom );
				wref( ImGui.inputInt("Border Left",_,1,10), d.borderLeft );
				wref( ImGui.inputInt("Border Right",_,1,10), d.borderRight );

				wref( ImGui.inputInt("Border Width",_,1,10), d.borderWidth );
				wref( ImGui.inputInt("Border Height",_,1,10), d.borderHeight );

				var newTile = IG.inputTile( "Background Tile", d.contentTile );
				if( newTile != null )
					d.contentTile = newTile;


			case "cerastes.ui.Button":
				var d : CUIButton = cast def;

				var e = IG.combo("Button Type", d.buttonMode, cerastes.ui.Button.ButtonType );
				if( e != null ) d.buttonMode = e;

				var e = IG.combo("Tile mode", d.bitmapMode, cerastes.ui.Button.BitmapMode );
				if( e != null ) d.bitmapMode = e;

				if( ImGui.collapsingHeader( "Tiles" ) )
				{
					var orientation = IG.combo("Orientation", d.orientation, cerastes.ui.Button.Orientation );
					if( orientation != null )
					{
						d.orientation = orientation;
					}

					var newTile = IG.inputTile( "Default Tile", d.defaultTile );
					if( newTile != null )
						d.defaultTile = newTile;

					if( d.buttonMode == Toggle )
					{
						var newTile = IG.inputTile( "Toggled (on) Tile", d.onTile );
						if( newTile != null )
							d.onTile = newTile;
					}

					var newTile = IG.inputTile( "Hover Tile", d.hoverTile );
					if( newTile != null )
						d.hoverTile = newTile;

					var newTile = IG.inputTile( "Press Tile", d.pressTile );
					if( newTile != null )
						d.pressTile = newTile;

					var newTile = IG.inputTile( "Disabled Tile", d.disabledTile );
					if( newTile != null )
						d.disabledTile = newTile;
				}

				if( ImGui.collapsingHeader("Tints") )
				{
					wref( ImGui.checkbox( "Color Children", _ ), d.colorChildren );

					var nc = IG.inputColorInt( d.defaultColor, "Default Color" );
					if( nc != null )
						d.defaultColor = nc;

					if( d.buttonMode == Toggle )
					{
						ImGui.text("Toggled (on) color");
						var nc = IG.inputColorInt( d.onColor, "On Color" );
						if( nc != null )
							d.onColor = nc;
					}

					ImGui.text("Hover Color");
					var nc = IG.inputColorInt( d.hoverColor, "Hover Color" );
					if( nc != null )
						d.hoverColor = nc;

					ImGui.text("Press Color");
					var nc = IG.inputColorInt( d.pressColor, "Press Color" );
					if( nc != null )
						d.pressColor = nc;

					if( d.buttonMode == Toggle )
					{
						ImGui.text("Toggled (on) hover color");
						var nc = IG.inputColorInt( d.onHoverColor, "On Hover Color" );
						if( nc != null )
							d.onHoverColor = nc;
					}

					ImGui.text("Disabled Color");
					var nc = IG.inputColorInt( d.disabledColor, "Disabled Color" );
					if( nc != null )
						d.disabledColor = nc;


				}

				if( ImGui.collapsingHeader( "Label" ) )
				{
					var val = IG.textInput("Text", d.text);
					if( val != null )
						d.text = val;

					var newFont = IG.textInput( "Font", d.font );
					if( newFont != null && hxd.Res.loader.exists( newFont ) )
						d.font = newFont;

					if( ImGui.beginDragDropTarget() )
					{
						var payload = ImGui.acceptDragDropPayloadString("asset_name");
						if( payload != null && hxd.Res.loader.exists( payload ) )
							d.font = payload;

						ImGui.endDragDropTarget();
					}

					if( d.font != null && StringTools.endsWith( d.font, ".msdf.fnt" ) )
					{
						wref( ImGui.inputInt( "Font Size", _ ), d.sdfSize );
						wref( ImGui.inputDouble( "Alpha Cutoff", _ ), d.sdfAlpha );
						wref( ImGui.inputDouble( "Smoothing", _ ), d.sdfSmoothing );
					}

					wref( ImGui.checkbox( "Ellipsis", _ ), d.ellipsis );
				}

				if( ImGui.collapsingHeader("Label Tints") )
				{
					var nc = IG.inputColorInt( d.defaultTextColor, "Default Text Color" );
					if( nc != null )
						d.defaultTextColor = nc;

					if( d.buttonMode == Toggle )
					{
						ImGui.text("Toggled Text color");
						var nc = IG.inputColorInt( d.onTextColor, "On Text Color" );
						if( nc != null )
							d.onTextColor = nc;
					}

					ImGui.text("Hover Text Color");
					var nc = IG.inputColorInt( d.hoverTextColor, "Hover Text Color" );
					if( nc != null )
						d.hoverTextColor = nc;

					ImGui.text("Press Text Color");
					var nc = IG.inputColorInt( d.hoverTextColor, "Press Text Color" );
					if( nc != null )
						d.pressTextColor = nc;

					ImGui.text("Disabled Text Color");
					var nc = IG.inputColorInt( d.disabledTextColor, "Disabled Text Color" );
					if( nc != null )
						d.disabledTextColor = nc;

				}

				if( ImGui.collapsingHeader( "Sounds" ) )
				{

					var newSound = IG.textInput( "Hover", d.hoverSound );
					if( newSound != null ) d.hoverSound = newSound;

					var newSound = IG.textInput( "Activate", d.activateSound );
					if( newSound != null ) d.activateSound = newSound;

					var newSound = IG.textInput( "Deactivate", d.deactivateSound );
					if( newSound != null ) d.deactivateSound = newSound;

					var newSound = IG.textInput( "Disabled", d.disabledSound );
					if( newSound != null ) d.disabledSound = newSound;

				}

				if( ImGui.collapsingHeader( "Tweens" ) )
				{

					var e: cerastes.ui.Button.ButtonHoverTween = IG.combo("Tween Hover Start", d.tweenModeHover, cerastes.ui.Button.ButtonHoverTween );
					if( e != null ) d.tweenModeHover = e;

					var e: cerastes.ui.Button.ButtonHoverTween = IG.combo("Tween Hover End", d.tweenModeUnHover, cerastes.ui.Button.ButtonHoverTween );
					if( e != null ) d.tweenModeUnHover = e;

					 ImGui.inputDouble("Tween Duration",d.tweenDuration ,0.1,1,"%.2f");

				}

				if( ImGui.collapsingHeader("Scripts") )
				{
					if( ImGui.button("OnPress") ) editScript( d.onPress );
					imTooltip("Code to run every time this button is pressed. Runs on the \"down\" stroke");

					if( ImGui.button("OnRelease") ) editScript( d.onRelease );
					imTooltip("Code to run every time this button is released.");
				}

			case "cerastes.ui.BitmapButton":
				var d : CUIBButton = cast def;

				var newTile = IG.inputTile( "Default Tile", d.defaultTile );
				if( newTile != null )
					d.defaultTile = newTile;

				var newTile = IG.inputTile( "Hover Tile", d.hoverTile );
				if( newTile != null )
					d.hoverTile = newTile;

				var newTile = IG.inputTile( "Disabled Tile", d.disabledTile );
				if( newTile != null )
					d.disabledTile = newTile;

				if( ImGui.collapsingHeader("Tints") )
				{
					var nc = IG.inputColorHVec( d.defaultColor, "defaultColor" );
					if( nc != null )
						d.defaultColor = nc;

					ImGui.text("Disabled Color");
					var nc = IG.inputColorHVec( d.disabledColor, "disabledColor" );
					if( nc != null )
						d.disabledColor = nc;

					ImGui.text("Hover Color");
					var nc = IG.inputColorHVec( d.hoverColor, "hoverColor" );
					if( nc != null )
						d.hoverColor = nc;


					var newTile = IG.inputTile( "Press Tile", d.pressTile );
					if( newTile != null )
						d.pressTile = newTile;

					ImGui.text("Press Color");
					var nc = IG.inputColorHVec( d.pressColor, "pressColor" );
					if( nc != null )
						d.pressColor = nc;
				}

				var orientation = IG.combo("Orientation", d.orientation, cerastes.ui.Button.Orientation );
				if( orientation != null )
				{
					d.orientation = orientation;
				}

			case "cerastes.ui.Reference":
				var d : CUIReference = cast def;

				var newFile = IG.textInput( "File", d.file );
				imTooltip("Another cui file to include. References count as an object, so the included file's root will be a child of this reference object.");
				if( d.file?.length > 0 )
				{
					ImGui.sameLine();
					if( ImGui.button("\uf3bf") )
						ImGuiToolManager.openAssetEditor( d.file );
				}
				if( newFile != null && hxd.Res.loader.exists( newFile ) )
				{
					d.file = newFile;
					d.def = null;
				}

				if( ImGui.beginDragDropTarget() )
				{
					var payload = ImGui.acceptDragDropPayloadString("asset_name");
					if( payload != null && hxd.Res.loader.exists( payload ) )
					{
						d.file = payload;
						d.def = null;
					}

					ImGui.endDragDropTarget();
				}


				// Fields for the thing we're referencing

				if( d.file != null && obj.numChildren == 1 )
				{
					// figure out what our child is
					var child = obj.getChildAt(0);
					var cui = Std.downcast( child, UIEntity );
					if( cui != null )
					{
						var cls = Type.getClass( cui );
						var clsName = Type.getClassName( cls );

						if (!ImGui.collapsingHeader('Ref: $clsName', ImGuiTreeNodeFlags.DefaultOpen ))
							return;

						if( d.def == null )
						{
							d.def = cast createDef( clsName );
						}

						var fn = Reflect.field(cls, "getInspector");
						fn( d.def );
						d.def.children = null;

					}
				}

			case "cerastes.ui.Sound":
				var d : CUISound = cast def;

				var newCue = IG.textInput( "Cue", d.cue );
				imTooltip("Can be either a filename in the audio folder (without extension), or a cue name.");
				if( newCue != null )
					d.cue = newCue;

				wref( ImGui.inputDouble("Volume",_,0.05,0.1), d.volume );
				imTooltip("Applied after all other mixer settings");

				wref( ImGui.checkbox( "Loop", _ ), d.loop );
				imTooltip("Overrides cue settings.");

				var channel = IG.combo("Channel", d.channel, cerastes.ui.Sound.CueChannel );
				imTooltip("Sets the mixer channel. Mostly controls which volume slider applies.");
				if( channel != null )
					d.channel = channel;


			case "h2d.Interactive":
				var d : CUIInteractive = cast def;

				wref( ImGui.inputDouble("Width",_,1,10), d.width );
				imTooltip("Width of the actual interactive area. If both width and height are 0, it will try to figure it out based on content bounds.");
				wref( ImGui.inputDouble("Height",_,1,10), d.height );
				imTooltip("Height of the actual interactive area. If both width and height are 0, it will try to figure it out based on content bounds.");

				var cursor = IG.combo("Cursor", d.cursor, hxd.Cursor );
				if( cursor != null )
				{
					d.cursor = cursor;
				}
/*
				// But why?
				wref( ImGui.checkbox( "Ellipse", _ ), t.isEllipse );

				var c = Vector.fromColor( t.backgroundColor );
				var color = new hl.NativeArray<Single>(4);
				color[0] = c.r;
				color[1] = c.g;
				color[2] = c.b;
				color[3] = c.a;
				var flags = ImGuiColorEditFlags.AlphaBar | ImGuiColorEditFlags.AlphaPreview
						| ImGuiColorEditFlags.DisplayRGB | ImGuiColorEditFlags.DisplayHex
						| ImGuiColorEditFlags.AlphaPreviewHalf;
				if( wref( ImGui.colorPicker4( "Color", _, flags), color ) )
				{
					c.set(color[0], color[1], color[2], color[3] );
					t.backgroundColor = c.toColor();
				}

*/

			case "h2d.TileGroup":

			default:
				var cl = Type.resolveClass(type);
				var fn = Reflect.field(cl, "getInspector");
				if( fn != null )
					fn( def );
				else
					Utils.assert( false, 'Type ${type} does not have getInspector.' );


		}

		ImGui.popID();

		ImGui.separator();
	}
/*
	function loadFont(text: h2d.Text, def: CUIElementDef )
	{
		var isSDF = StringTools.endsWith( def.props["font"], ".msdf.fnt" );

		if( !isSDF )
		{
			text.font = hxd.Res.loader.loadCache( def.props["font"], BitmapFont).toFont();
		}
		else
		{
			if( !def.props.exists("sdf_size") )
			{
				// Defaults
				def.props["sdf_size"] = 14;
				def.props["sdf_alpha"] = 0.5;
				def.props["sdf_smoothing"] = 32;
			}
			text.font = hxd.Res.loader.loadCache( def.props["font"], BitmapFont).toSdfFont(def.props["sdf_size"],4,def.props["sdf_alpha"],1/def.props["sdf_smoothing"]);
		}
	}
*/
	function getNameForType( type: String )
	{
		return switch(type)
		{
			case "h2d.Anim": 'Simple Animation';
			case "cerastes.ui.Anim": 'Animation';
			default: type.substr( type.lastIndexOf(".") +1 );
		}
	}

	function getIconForType( type: String )
	{
		switch( type )
		{
			case "h2d.Object": return "\uf0b2";
			case "h2d.Text": return "\uf031";
			case "h2d.Bitmap": return "\uf03e";
			case "h2d.Anim": return "\uf008"; // DEPRECATED?, used cerastes.ui.anim?
			case "cerastes.ui.Anim": return "\uf008";
			case "h2d.Flow": return "\uf0db";
			case "h2d.Mask": return "\uf125";
			case "h2d.Interactive": return "\uf125";
			case "h2d.ScaleGrid": return "\uf00a";
			case "cerastes.ui.Button": return "\uf04d";
			case "cerastes.ui.BitmapButton": return "\uf04d";
			//case "cerastes.ui.TextButton": return "\uf04d";
			case "cerastes.ui.AdvancedText": return "\uf033";
			case "cerastes.ui.Reference": return "\uf07c";
			case "cerastes.ui.Sound": return "\uf001";
			default:
				var cl = Type.resolveClass(type);
				var fn = Reflect.field(cl, "getEditorIcon");
				if( fn != null )
					return fn();

				return "";
		}
	}

	function createDef( type:String ) : CUIObject
	{
		switch( type )
		{
			case "h2d.Object":

				var def: CUIObject = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.Text":
				var def: CUIText = {
					type: type,
					name: getAutoName(type),
					children: []
				};
				return def;

			case "cerastes.ui.AdvancedText":
				var def: CUIAdvancedText = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.TextInput":
				var def: CUITextInput = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.Bitmap":
				var def: CUIBitmap = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.Anim":
				var def: CUIAnim = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "cerastes.ui.Anim":
				var def: CUICAnim = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;


			case "h2d.Flow":
				var def: CUIFlow = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.ScaleGrid":
				var def: CUIScaleGrid = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.Mask":
				var def: CUIMask = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "h2d.Interactive":
				var def: CUIInteractive = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "cerastes.ui.Button":
				var def: CUIButton = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "cerastes.ui.BitmapButton":
				var def: CUIBButton = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "cerastes.ui.TextButton":
					var def: CUITButton = {
						type: type,
						name: getAutoName(type),
						children: []
					};

					return def;

			case "cerastes.ui.Reference":
				var def: CUIReference = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			case "cerastes.ui.Sound":
				var def: CUISound = {
					type: type,
					name: getAutoName(type),
					children: []
				};

				return def;

			default:
				var cl = Type.resolveClass(type);
				var fn = Reflect.field(cl, "getDef");
				if( fn != null )
				{
					var def = fn();
					def.type = type;
					def.children = [];
					def.name = getAutoName(type);

					return def;
				}
				else
				{
					Utils.warning('UIEntity ${type} is missing getDef!!');
				}
			}

			return {};
	}

	function addItem(type: String)
	{
		var parent = selectedInspectorTree != null ? selectedInspectorTree : rootDef;

		parent.children.push(createDef(type));


		updateScene();
	}
}

#end