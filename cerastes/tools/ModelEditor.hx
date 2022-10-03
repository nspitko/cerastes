
package cerastes.tools;
#if hlimgui

import cerastes.tools.ImguiTool.ImGuiPopupType;
import h3d.Vector;
import h3d.scene.CameraController;
import h3d.Matrix;
import h3d.scene.Skin.Joint;
import h3d.scene.Graphics;
import hxd.res.Model;
import hxd.SceneEvents;
import h3d.col.Point;

import hl.UI;
import imgui.ImGuiMacro.wref;
import cerastes.file.CDParser;
import h3d.mat.DepthBuffer;
import h3d.mat.Texture;
import h3d.scene.Object;
import h3d.scene.Mesh;
import cerastes.c3d.Model.ModelDef;
import h3d.prim.Sphere;
import haxe.rtti.Meta;
import haxe.crypto.Md5;

import h3d.Engine;
import hxd.Key;
import h2d.Tile;
import cerastes.macros.Metrics;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTool.ImGuiToolManager;
import hl.Gc;
import hxd.App;
import hxd.System;
import imgui.ImGuiDrawable;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import imgui.ImGui;
import cerastes.data.Nodes;

#if imguizmo
import imgui.ImGuizmo;
#end


enum MESelectedObjectType {
	None;
	Animation;
	Joint;
	Library;
}

@:keep
@multiInstance(true)
class ModelEditor extends ImguiTool
{

	var scaleFactor = Utils.getDPIScaleFactor();

	// Preview
	var preview: h3d.scene.Scene;
	var previewMesh: Mesh;
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

	var selectedObjectType: MESelectedObjectType = None;
	var selectedObject: Any = null;

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var fileName: String = null;

	var modelDef : ModelDef = null;


	var events: SceneEvents;

	var modelLibrary: hxd.fmt.hmd.Library;
	var modelObject: Object;

	var previewGraphics: Graphics;

	var cameraController: CameraController;

	var showScaleBox = true;

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
		sceneRT.depthBuffer = new DepthBuffer(viewportWidth, viewportHeight );

		modelDef = { file:"" };

		rebuildPreview();

		events = new SceneEvents();
		events.addScene(preview);

		//openFile("mdl/kronii.model");
		openFile("models/placeholder/vanguard_gltf.model");
		//openFile("models/placeholder/vanguard.model");


	}

	public function openFile(f: String)
	{
		fileName = f;

		try
		{
			modelDef =  cerastes.file.CDParser.parse( hxd.Res.loader.load(f).entry.getText(), ModelDef );
			rebuildPreview();
		} catch(e)
		{
			ImGuiToolManager.showPopup("Failed to open file",'$f could not be opened:\n${e}',Error);
			Utils.warning( e.toString() );
		}
	}

	function resizeRT( newSize: ImVec2 )
	{
		if( sceneRT.width == newSize.x && sceneRT.height == newSize.y )
			return;

		sceneRT.resize( CMath.floor( newSize.x ), CMath.floor( newSize.y ) );
		sceneRT.depthBuffer = new DepthBuffer( CMath.floor( newSize.x ), CMath.floor( newSize.y ) );
	}

	public static function buildModelPreview(scene: h3d.scene.Scene, def: ModelDef)
	{
		//Create an environment map texture
		var envMap = new h3d.mat.Texture(512, 512, [Cube]);

		inline function set(face:Int, res:hxd.res.Image) {
			var pix = res.getPixels();
			envMap.uploadPixels(pix, 0, face);
		}
		#if pbr
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

		var renderer = cast(scene.renderer, h3d.scene.pbr.Renderer);
		renderer.env = env;

		//sys.io.File.saveContent("res/mat/ribbed-chipped-metal.material", cerastes.file.CDPrinter.print( matDef ) );


		//var cubeShader = bg.material.mainPass.addShader(new h3d.shader.pbr.CubeLod(env.env));
		var light = new h3d.scene.pbr.PointLight(scene);
		light.setPosition(30, 10, 40);
		light.range = 100;
		light.power = 8;
		#else

		//cast( scene.lightSystem, h3d.scene.fwd.LightSystem).ambientLight.set(1,1,1,1);
		var light = new h3d.scene.fwd.PointLight(scene);
		light.setPosition(30, 10, 40);
		light.params.z /= 300 * 10;
		#end


		var modelObject = def.toObject(scene);
		// Draw axis
		var g = new h3d.scene.Graphics( scene );

		var lineSize = 1;

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


		var gridSize = 10;
		g.lineStyle(1, 0x888888, 1);
		for( x in -gridSize ... gridSize )
			g.drawLine(new Point(x,-gridSize,0), new Point(x,gridSize,0));

		for( y in -gridSize ... gridSize )
			g.drawLine(new Point(-gridSize,y,0), new Point(gridSize,y,0));


		//new h3d.scene.CameraController(preview).loadFromCamera();



		//var dc = new cerastes.c3d.Camera();
		//dc.mcam = preview.camera.mcam;


		//trace(preview.camera.pos);
		scene.camera.pos.set(20,-30,40);
		scene.camera.target.set(0,0,8);

		return modelObject;
	}

	function rebuildPreview()
	{
		preview.removeChildren();

		modelObject = buildModelPreview( preview, modelDef );

		cameraController = new h3d.scene.CameraController(preview);
		cameraController.loadFromCamera();

		//preview.camera = dc;

		//dc.mproj.initRotation(Math.PI/4,0,0);
		//dc.mproj.translate(-10,0,10);

		modelLibrary = null;

		if( modelDef.file != null && hxd.Res.loader.exists( modelDef.file ) )
		{
			var modelResource = hxd.Res.loader.loadCache( modelDef.file, Model );
			modelLibrary = modelResource.toHmd();
		}

		previewGraphics = new Graphics(preview);


	}

	// Called every frame. Does a lighter version of rebuildPreview
	function refreshPreview()
	{
		var g = previewGraphics;
		g.clear();

		switch( selectedObjectType )
		{
			case Joint:
				var joint: Joint = cast selectedObject;


			default:
		}

		//previewMesh.material = materialDef.toMaterial();
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
		ImGui.begin('\uf183 Model  Editor - ${ fileName != null ? fileName : "Untitled" }###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);



		modelOutline();
		modelPreview();
		modelSettings();



		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

	}

	function modelSettings()
	{

		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Properties##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		var newFile = IG.inputFile("Mesh", modelDef.file, "models", "fbx", false);
		if( newFile != null )
		{
			modelDef.file = newFile;
			rebuildPreview();
		}

		if( imgui.ImGuiMacro.wref( ImGui.inputDouble("Scale", _, 0.1, 0.5, "%.2f"), modelDef.scale ) )
		{
			rebuildPreview();
		}

		ImGui.text("Materials");
		ImGui.separator();

		if( modelLibrary != null )
		{
			for( idx in 0 ... modelLibrary.header.materials.length )
			{
				var defMat = idx < modelDef.materials.length ? modelDef.materials[idx] : "";
				var mat = modelLibrary.header.materials[idx];

				var name = mat.name;
				if( mat.name.length == 0 )
					name = 'Material ${idx}';


				var newMat = IG.inputMaterial( name, defMat );
				if( newMat != null )
				{
					if( modelDef.materials.length >= idx )
						modelDef.materials[idx] = newMat;
					else
						modelDef.materials.insert(idx, newMat);

					rebuildPreview();
				}
			}
		}


		ImGui.text("Libraries");
		ImGui.separator();
		ImGui.beginChildFrame( ImGui.getID( "libraries" ), {x: -1, y: 100 * ImGuiToolManager.scaleFactor});

		for( l in 0 ... modelDef.libraries.length )
		{
			var lib = modelDef.libraries[l];
			var bits = lib.split("/");
			var name = bits.length > 0 ? bits[bits.length - 1] : "???";

			var flags = ImGuiTreeNodeFlags.DefaultOpen | ImGuiTreeNodeFlags.Leaf;
			if( selectedObjectType == Library && l == selectedObject )
				flags |= ImGuiTreeNodeFlags.Selected;

			if( ImGui.treeNodeEx( '${name}', flags ) )
			{
				if( ImGui.isItemClicked( ) )
				{
					selectedObject = l;
					selectedObjectType = Library;
				}
				ImGui.treePop();
			}

		}


		ImGui.endChild();

		var newFile = IG.inputFile( 'Add Library', "", "models/", "glb", false, true );
		if( newFile != null )
		{
			modelDef.libraries.push(newFile);
		}

		processMouse();


		ImGui.end();
	}


	function handleShortcuts()
	{
		if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.CTRL ) && Key.isPressed( Key.S ) )
		{
			save();
		}

		if( ImGui.isWindowFocused(  ImGuiFocusedFlags.RootAndChildWindows ) && Key.isDown( Key.DELETE ) )
		{
			switch( selectedObjectType )
			{
				case Library:
					modelDef.libraries.splice(selectedObject,1);
					selectedObjectType = None;
				default:
			}
		}
	}

	function saveAs()
	{
		var newFile = UI.saveFile({
			title:"Save As...",
			filters:[
			{name:"Cerastes models", exts:["model"]}
			]
		});
		if( newFile != null )
		{
			sys.io.File.saveContent(Utils.fixWritePath(newFile,"model"), cerastes.file.CDPrinter.print( modelDef ) );

			fileName = Utils.toLocalFile( Utils.fixWritePath(newFile,"model") );

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

		sys.io.File.saveContent(Utils.fixWritePath(fileName,"model"), cerastes.file.CDPrinter.print( modelDef ) );

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


	function modelOutline()
	{
		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Outline##${windowID()}');
		handleShortcuts();

		if( modelLibrary != null )
		{

			var flags = ImGuiTreeNodeFlags.OpenOnArrow | ImGuiTreeNodeFlags.DefaultOpen;
			if( ImGui.treeNodeEx( "Animations", flags ) )
			{
				for( a in modelLibrary.header.animations )
				{
					if( ImGui.treeNodeEx( '${modelLibrary.resource.name}/${a.name}', flags | ImGuiTreeNodeFlags.Leaf ) )
					{
						if( ImGui.isItemClicked() )
						{
							var anim = modelLibrary.loadAnimation( a.name );
							modelObject.playAnimation( anim );


							selectedObject = anim;
							selectedObjectType = Animation;
						}
						ImGui.treePop();
					}
				}

				// Additionally, load in animations from sub-libraries
				for( l in modelDef.libraries )
				{
					//try
					{
						var res = hxd.Res.loader.loadCache( l, Model );
						var lib = res.toHmd();

						for( a in lib.header.animations )
						{
							if( ImGui.treeNodeEx( '${lib.resource.name}/${a.name}', flags | ImGuiTreeNodeFlags.Leaf ) )
							{
								if( ImGui.isItemClicked() )
								{
									var anim = lib.loadAnimation( a.name );
									modelObject.playAnimation( anim );

									selectedObject = anim;
									selectedObjectType = Animation;
								}
								ImGui.treePop();
							}
						}

					}
					/*
					catch( e )
					{
						ImGuiToolManager.showPopup("Invalid Library",'${l} could not be loaded.\nReason: ${e}', ImGuiPopupType.Error );
						modelDef.libraries.remove(l);
						break;
					}
					*/

				}

				ImGui.treePop();
			}

			if( ImGui.treeNodeEx( "Material Slots", flags ) )
			{
				for( idx in 0 ... modelLibrary.header.materials.length )
				{
					var mat = modelLibrary.header.materials[idx];
					if( ImGui.treeNodeEx( '[${idx}] ${ mat.name}', flags | ImGuiTreeNodeFlags.Leaf ) )
					{
						ImGui.treePop();
					}
				}
				ImGui.treePop();
			}

			if( ImGui.treeNodeEx( "Objects", flags ) )
			{
				for( mod in modelLibrary.header.models )
				{
					if( ImGui.treeNodeEx( mod.name, flags ) )
					{
						// Bones
						if( mod.skin != null && ImGui.treeNodeEx( "Skeleton", flags ) )
						{
							for( joint in mod.skin.joints )
							{
								if( ImGui.treeNodeEx( joint.name, flags | ImGuiTreeNodeFlags.Leaf ) )
								{
									if( ImGui.isItemClicked() )
									{
										// Find the runtime model bone
										var joint = modelObject.getObjectByName( joint.name );
										if( joint == null )
											Utils.warning('Failed to look up joint ${joint.name} in loaded rig');

										selectedObject = joint;
										selectedObjectType = Joint;
									}

									ImGui.treePop();
								}
							}
							ImGui.treePop();

						}
						ImGui.treePop();
					}
				}
				ImGui.treePop();
			}


		}

		ImGui.end();

	}



	function modelPreview()
	{
		refreshPreview();

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Preview##${windowID()}', null, ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		#if imguizmo
		ImGuizmo.setDrawlist();
		#end
		handleShortcuts();

		var size = ImGui.getWindowSize();
		var style = ImGui.getStyle();

		var startPos: ImVec2 = ImGui.getCursorScreenPos();
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
		#if imguizmo
		ImGuizmo.setRect(startPos.x, startPos.y, size.x, size.x);
		#end
		//ImGuizmo.setRect(0, 0, 1920, 1080);
		var gizmoWindowFlags = ImGui.isItemHovered() ? ImGuiWindowFlags.NoMove : 0;

		// Copy matrices
		var cameraView = new hl.NativeArray<Single>(16);
		var cvm = preview.camera.mcam;

		copyMatrix( cvm, cameraView, 0 );

		var cameraProject = new hl.NativeArray<Single>(16);
		var cp = preview.camera.mproj;

		copyMatrix( cp, cameraProject, 0 );

		var identityMatrix = new hl.NativeArray<Single>(16);
		var im = new Matrix();
		im.identity();
		copyMatrix(im, identityMatrix, 0 );

		var modelMatrix = modelObject.getAbsPos();
		var objectMatrix = new hl.NativeArray<Single>(16);
		copyMatrix( modelMatrix, objectMatrix);

		switch( selectedObjectType )
		{
			case Joint:

				var joint: Joint = cast selectedObject;
				var jm = joint.getAbsPos();
				var jointMatrix = new hl.NativeArray<Single>(16);
				copyMatrix(jm, jointMatrix);

				#if imguizmo
				ImGuizmo.manipulate( cameraView, cameraProject, TRANSLATE, WORLD, jointMatrix );
				#end


			default:
		}




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

	function copyMatrix( src: Matrix, dest: hl.NativeArray<Single>, start: Int = 0 )
	{
		dest[start] = src._11;
		dest[start + 1] = src._12;
		dest[start + 2] = src._13;
		dest[start + 3] = src._14;

		dest[start + 4] = src._21;
		dest[start + 5] = src._22;
		dest[start + 6] = src._23;
		dest[start + 7] = src._24;

		dest[start + 8] = src._31;
		dest[start + 9] = src._32;
		dest[start + 10] = src._33;
		dest[start + 11] = src._34;

		dest[start + 12] = src._41;
		dest[start + 13] = src._42;
		dest[start + 14] = src._43;
		dest[start + 15] = src._44;
	}

	function readMatrix( dest: Matrix, src: hl.NativeArray<Single>, start: Int = 0)
	{
		dest._11 = src[0];
		dest._12 = src[1];
		dest._13 = src[2];
		dest._14 = src[3];

		dest._21 = src[4];
		dest._22 = src[5];
		dest._23 = src[6];
		dest._24 = src[7];

		dest._31 = src[8];
		dest._32 = src[9];
		dest._33 = src[10];
		dest._34 = src[11];

		dest._41 = src[12];
		dest._42 = src[13];
		dest._43 = src[14];
		dest._44 = src[15];



	}





	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'ModelEditorDockspace${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut = hl.Ref.make( dockspaceId );

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.3, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.3, null, idOut);
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