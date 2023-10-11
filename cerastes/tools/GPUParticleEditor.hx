
package cerastes.tools;

#if hlimgui
import imgui.ImGuiMacro.wref;
import cerastes.c3d.GPUParticle.GPUParticleDef;
import hl.UI;
import hxd.Key;
import imgui.ImGui;
import h3d.col.Point;
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
class GPUParticleEditor extends ImguiTool
{

	var scaleFactor = Utils.getDPIScaleFactor();

	// Preview
	var preview: h3d.scene.Scene;
	var previewParticle: Emitter;
	var sceneRT: Texture;
	var sceneRTId: Int;

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

	var particleDef : cerastes.c3d.GPUParticle.GPUParticleDef = null;
	var particle: GpuParticles = null;


	var events: SceneEvents;


	var previewGraphics: Graphics;

	var cameraController: CameraController;

	var drawAxis = true;
	var drawGrid = false;

	public override function getName() { return "\uf183 GPU Particle Editor"; }

	public function new()
	{

		var dimensions = IG.getWindowDimensions();
		windowWidth = dimensions.width;
		windowHeight = dimensions.height;

		//
		viewportWidth = Math.floor( 1024 * ImGuiToolManager.scaleFactor );
		viewportHeight = viewportWidth;

		preview = new h3d.scene.Scene();
		sceneRT = new Texture(viewportWidth,viewportHeight, [Target] );
		sceneRT.depthBuffer = new Texture(viewportWidth, viewportHeight, [Target] );

		particleDef = { };

		//trace(preview.camera.pos);
		preview.camera.pos.set(20,-30,40);
		preview.camera.target.set(0,0,0);


		rebuildPreview();

		events = new SceneEvents();
		events.addScene(preview);

		//openFile("mdl/kronii.model");
		openFile("particles/test.gparticle");


	}

	public override function openFile(f: String)
	{
		fileName = f;

		try
		{
			particleDef =  cerastes.file.CDParser.parse( hxd.Res.loader.load(f).entry.getText(), GPUParticleDef );
			rebuildPreview();
		} catch(e)
		{
			ImGuiToolManager.showPopup("Failed to open file",'$f could not be opened:\n${e}',Error);
		}
	}

	function rebuildPreview()
	{
		preview.removeChildren();

		#if pbr

		//Create an environment map texture
		var envMap = new h3d.mat.Texture(512, 512, [Cube]);

		inline function set(face:Int, res:hxd.res.Image) {
			var pix = res.getPixels();
			envMap.uploadPixels(pix, 0, face);
		}

		//Set the faces for the environment cube map
		set(0, hxd.Res.tex.front);
		set(1, hxd.Res.tex.back);
		set(2, hxd.Res.tex.right);
		set(3, hxd.Res.tex.left);
		set(4, hxd.Res.tex.top);
		set(5, hxd.Res.tex.bottom);

		//Create a new environment that we can use to control some of the material behavior
		var env = new h3d.scene.pbr.Environment(envMap);
		env.compute();

		//Set the environment on the custom PBR renderer

		var renderer = cast(preview.renderer, h3d.scene.pbr.Renderer);
		renderer.env = env;

		//sys.io.File.saveContent("res/mat/ribbed-chipped-metal.material", cerastes.file.CDPrinter.print( matDef ) );


		//var cubeShader = bg.material.mainPass.addShader(new h3d.shader.pbr.CubeLod(env.env));
		var light = new h3d.scene.pbr.PointLight(preview);
		light.setPosition(30, 10, 40);
		light.range = 100;
		light.power = 8;
		#else

		cast( preview.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(1,1,1,1);
		#end


		particle = new GpuParticles(preview);
		particleDef.addToEmitter( particle );


		// Draw axis
		var g = new h3d.scene.Graphics( preview );




		//new h3d.scene.CameraController(preview).loadFromCamera();



		//var dc = new cerastes.c3d.Camera();
		//dc.mcam = preview.camera.mcam;


		cameraController = new h3d.scene.CameraController(preview);
		cameraController.loadFromCamera();

		previewGraphics = new Graphics(preview);


	}

	// Called every frame. Does a lighter version of rebuildPreview
	function refreshPreview()
	{
		var g = previewGraphics;
		g.clear();


		var lineSize = 1;
		if( drawAxis )
		{
			// X (Red)
			g.lineStyle(10, 0xFF0000, 1);
			g.drawLine(new Point(0,0,0), new Point(lineSize,0,0));

			// Y (Green)
			g.lineStyle(10, 0x00FF00, 1);
			g.drawLine(new Point(0,0,0), new Point(0,lineSize,0));

			// Z (Blue)
			g.lineStyle(10, 0x0000FF, 1);
			g.drawLine(new Point(0,0,0), new Point(0,0,lineSize));

			// Grid lines
		}

		if( drawGrid )
		{

			var gridSize = 10;
			g.lineStyle(1, 0x888888, 1);
			for( x in -gridSize ... gridSize )
				g.drawLine(new Point(x,-gridSize,0), new Point(x,gridSize,0));

			for( y in -gridSize ... gridSize )
				g.drawLine(new Point(-gridSize,y,0), new Point(gridSize,y,0));
		}


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
		ImGui.begin('\uf183 GPU Particle Editor - ${ fileName != null ? fileName : "Untitled" }###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);



		particleSettings();
		drawPreview();



		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

	}

	function particleSettings()
	{

		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Properties##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		var texture = IG.inputTexture("Texture", particleDef.texture, "textures");
		if( texture != null )
		{
			particleDef.texture = texture;
			rebuildPreview();
		}

		var texture = IG.inputTexture("Gradient", particleDef.colorGradient, "textures");
		if( texture != null )
		{
			particleDef.colorGradient = texture;
			rebuildPreview();
		}

		// @todo sortmode
		// @todo emitMode

		var changed = false;
		changed = changed || wref( ImGui.inputDouble("Amount", _, 0.001, 0.1, "%.4f"), particleDef.amount );
		changed = changed || wref( ImGui.inputInt("Num Parts", _ ), particleDef.nparts );

		var ret = IG.combo("Sort Mode", particleDef.sortMode, GpuSortMode );
		if( ret != null )
		{
			particleDef.sortMode = ret;
			changed = true;
		}

		var ret = IG.combo("Emit Mode", particleDef.emitMode, GpuEmitMode );
		if( ret != null )
		{
			particleDef.emitMode = ret;
			changed = true;
		}



		ImGui.separator();
		changed = changed || wref( ImGui.inputDouble("Distance", _, 0.1, 1, "%.4f"), particleDef.emitStartDist );
		changed = changed || wref( ImGui.inputDouble("Distance Delta", _, 0.1, 1, "%.4f"), particleDef.emitDist );
		changed = changed || wref( ImGui.inputDouble("Angle", _, 0.1, 1, "%.4f"), particleDef.emitAngle );
		changed = changed || wref( ImGui.inputDouble("Sync", _, 0.1, 1, "%.4f"), particleDef.emitSync );
		changed = changed || wref( ImGui.inputDouble("Delay", _, 0.1, 1, "%.4f"), particleDef.emitDelay );
		changed = changed || wref( ImGui.checkbox("Emit On Border", _ ), particleDef.emitOnBorder );
//		ImGui.separator();
		// @todo: Allow specification of bounds
		//changed = changed || wref( ImGui.checkbox("Clip bounds", _ ), particleDef.clipBounds );
		changed = changed || wref( ImGui.checkbox("Transform 3d", _ ), particleDef.transform3d );
		ImGui.separator();
		changed = changed || wref( ImGui.inputDouble("Size", _, 0.1, 1, "%.4f"), particleDef.size );
		changed = changed || wref( ImGui.inputDouble("Size Delta", _, 0.1, 1, "%.4f"), particleDef.sizeIncr );
		changed = changed || wref( ImGui.inputDouble("Size Noise", _, 0.1, 1, "%.4f"), particleDef.sizeRand );
		ImGui.separator();
		changed = changed || wref( ImGui.inputDouble("Life", _, 0.1, 1, "%.4f"), particleDef.life );
		changed = changed || wref( ImGui.inputDouble("Life Noise", _, 0.1, 1, "%.4f"), particleDef.lifeRand );
		ImGui.separator();
		changed = changed || wref( ImGui.inputDouble("Speed", _, 0.1, 1, "%.4f"), particleDef.speed );
		changed = changed || wref( ImGui.inputDouble("Speed Delta", _, 0.1, 1, "%.4f"), particleDef.speedIncr );
		changed = changed || wref( ImGui.inputDouble("Speed Noise", _, 0.1, 1, "%.4f"), particleDef.speedRand );
		changed = changed || wref( ImGui.inputDouble("Gravity", _, 0.1, 1, "%.4f"), particleDef.gravity );
		ImGui.separator();
		changed = changed || wref( ImGui.inputDouble("Rotation", _, 0.1, 1, "%.4f"), particleDef.rot );
		changed = changed || wref( ImGui.inputDouble("Rotation Delta", _, 0.1, 1, "%.4f"), particleDef.rotSpeed );
		changed = changed || wref( ImGui.inputDouble("Rotation Noise", _, 0.1, 1, "%.4f"), particleDef.rotSpeedRand );
		ImGui.separator();
		changed = changed || wref( ImGui.inputDouble("Fade In", _, 0.1, 1, "%.4f"), particleDef.fadeIn );
		changed = changed || wref( ImGui.inputDouble("Fade Out", _, 0.1, 1, "%.4f"), particleDef.fadeOut );

		if( changed )
			rebuildPreview();

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

	function resizeRT( newSize: ImVec2 )
	{
		if( sceneRT.width == newSize.x && sceneRT.height == newSize.y )
			return;

		sceneRT.resize( CMath.floor( newSize.x ), CMath.floor( newSize.y ) );
		sceneRT.depthBuffer.resize( CMath.floor( newSize.x ), CMath.floor( newSize.y ) );
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

		if ( wref( ImGui.checkbox("Draw Axis", _), drawAxis ) ) refreshPreview();
		ImGui.sameLine();
		if ( wref( ImGui.checkbox("Draw Grid", _), drawGrid ) ) refreshPreview();

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

		ImGuiToolManager.updatePreviewEvents( startPos, texSize, events );

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