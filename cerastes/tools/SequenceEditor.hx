
package cerastes.tools;

#if hlimgui
import imgui.ImGuiMacro.wref;
import cerastes.c3d.GPUParticle.GPUParticleDef;
import hl.UI;
import hxd.Key;
import imgui.ImGui;
import h3d.col.Point;
import h3d.mat.DepthBuffer;
import cerastes.tools.ImguiTool.ImGuiToolManager;
import imgui.ImGui.ImGuiCond;
import imgui.ImGui.ImVec2;
import h3d.scene.CameraController;
import h3d.scene.Graphics;
import hxd.SceneEvents;
import cerastes.tools.ImguiTools.IG;
import h3d.parts.GpuParticles;
import imgui.ImGui.ImGuiID;
import h3d.mat.Texture;
import h3d.parts.Emitter;



@:keep
@multiInstance(true)
class SequenceEditor extends ImguiTool
{

	var scaleFactor = Utils.getDPIScaleFactor();

	// Preview
	var preview: h2d.Scene;
	var sceneRT: Texture;

	var viewportWidth: Int;
	var viewportHeight: Int;

	// Dockspace
	var dockspaceId: ImGuiID = -1;
	var dockspaceIdLeft: ImGuiID;
	var dockspaceIdRight: ImGuiID;
	var dockspaceIdCenter: ImGuiID;

	var dockCond = ImGuiCond.Appearing;

	//

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var fileName: String = null;

	var particleDef : cerastes.c3d.GPUParticle.GPUParticleDef = null;
	var particle: GpuParticles = null;


	var events: SceneEvents;

	var previewGraphics: Graphics;

	var drawAxis = true;
	var drawGrid = false;


	public function new()
	{

		var viewportDimensions = IG.getViewportDimensions();
		viewportWidth = viewportDimensions.width;
		viewportHeight = viewportDimensions.height;
		viewportScale = viewportDimensions.scale;
		preview = new h2d.Scene();
		preview.scaleMode = Fixed(viewportWidth,viewportHeight, 1, Left, Top);
		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );

		rebuildPreview();

		events = new SceneEvents();
		events.addScene(preview);

		//openFile("mdl/kronii.model");
		//openFile("particles/test.gparticle");


	}

	public function openFile(f: String)
	{
		fileName = f;

		try
		{
			//particleDef =  cerastes.file.CDParser.parse( hxd.Res.loader.load(f).entry.getText(), GPUParticleDef );
			//rebuildPreview();
		} catch(e)
		{
			ImGuiToolManager.showPopup("Failed to open file",'$f could not be opened:\n${e}',Error);
		}
	}

	function rebuildPreview()
	{
		preview.removeChildren();

	

	}

	// Called every frame. Does a lighter version of rebuildPreview
	function refreshPreview()
	{



	}

	override public function update( delta: Float )
	{

		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		if( forceFocus )
		{
			forceFocus = false;
			ImGui.setNextWindowFocus();
		}
		ImGui.setNextWindowSize({x: windowWidth * 0.9, y: windowHeight * 0.9}, ImGuiCond.Once);
		ImGui.begin('\uf183 Sequence Editor - ${ fileName != null ? fileName : "Untitled" }###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);



		actionSettings();
		drawPreview();



		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

	}

	function actionSettings()
	{

		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Actions##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();


		processMouse();


		ImGui.end();
	}


	function handleShortcuts()
	{
		if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}
	}

	function saveAs()
	{
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes particles", exts:["gparticle"]}
			]
		});
		if( newFile != null )
		{
			sys.io.File.saveContent(Utils.fixWritePath(newFile,"gparticle"), cerastes.file.CDPrinter.print( particleDef ) );

			fileName = Utils.toLocalFile( Utils.fixWritePath(newFile,"gparticle") );

			cerastes.tools.AssetBrowser.needsReload = true;
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

		sys.io.File.saveContent(Utils.fixWritePath(fileName,"gparticle"), cerastes.file.CDPrinter.print( particleDef ) );

		ImGuiToolManager.showPopup("File saved",'Wrote ${fileName} successfully.', Info);
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

	public override inline function windowID()
	{
		return 'modelEditor${fileName != null ? fileName : ""+toolId}';
	}


	var mouseStart: ImVec2;
	function processMouse()
	{

	}


	function drawPreview()
	{
		refreshPreview();

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		handleShortcuts();

		var size = ImGui.getWindowSize();
		var style = ImGui.getStyle();

		var startPos: ImVec2 = ImGui.getCursorScreenPos();


		ImGui.setCursorScreenPos( startPos );

		//var windowPos: ImVec2 = ImGui.getWindowPos();

		ImGui.pushStyleColor( ImGuiCol.Button, 0 );
		ImGui.pushStyleColor( ImGuiCol.ButtonActive, 0 );
		ImGui.pushStyleColor( ImGuiCol.ButtonHovered, 0 );


		var texSize: ImVec2 = {x: size.x, y: size.y};


		texSize.x -= style.WindowPadding.x * 2;
		texSize.y -= style.WindowPadding.y * 2;

		resizeRT(texSize);

		ImGui.imageButton(sceneRT, texSize, null, null, 0 );

		ImGui.popStyleColor();
		ImGui.popStyleColor();
		ImGui.popStyleColor();

		ImGuiToolManager.updatePreviewEvents( startPos, events );

		//var viewPos: ImVec2 = {x: startPos.x + 25, y: startPos.y + 25}; // {x: size.x - viewSize.x - viewPadding.x, y: viewPadding.y };
		var viewSize: ImVec2 = {x: 128, y: 128};
		var viewPadding: ImVec2 = {x: 40, y: 10};

		var viewPos: ImVec2 = {x: size.x - viewSize.x - viewPadding.x, y: viewPadding.y };
		viewPos += startPos;

		// CAMERA STUFF
		//var dc: cerastes.c3d.Camera = cast preview.camera;
		//dc.dumbMode = true;



		//ImGuizmo.viewManipulate( cameraView, 1, viewPos, viewSize, 0x10101010 );
		//readMatrix( preview.camera.mcam, cameraView  );

		//preview.camera.mcam.setPosition(new Vector(0,0, 10));

		/*

		//cameraController.


		@:privateAccess preview.camera.


		@:privateAccess {

			//preview.camera.follow = null;
			//preview.camera.m.multiply(preview.camera.mcam, preview.camera.mproj);

			//preview.camera.needInv = true;

			//preview.camera.mcamInv._44;
			//preview.camera.mprojInv._44;

			//preview.camera.frustum.loadMatrix(preview.camera.m);
		}




*/

		ImGui.end();

	}


	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'GPUParticleEditorDockspace${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.5, null, idOut);
			//dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
			dockspaceIdCenter = idOut.get();


			ImGui.dockBuilderFinish(dockspaceId);
		}
	}

	override public function render( e: h3d.Engine)
	{



		@:privateAccess// @:bypassAccessor
		{


			e.pushTarget( sceneRT );
			e.clear(0,1);

			preview.render(e);

			e.popTarget();


		}


	}


}

#end