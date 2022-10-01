
package cerastes.tools;

#if hlimgui
import hl.UI;
import imgui.ImGuiMacro.wref;
import cerastes.file.CDParser;
import h3d.mat.DepthBuffer;
import h3d.mat.Texture;
import h3d.scene.Object;
import h3d.scene.Mesh;
import cerastes.c3d.Material.MaterialDef;
import h3d.prim.Sphere;
import haxe.rtti.Meta;
import haxe.crypto.Md5;


import cerastes.flow.Flow;
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


@:keep
@multiInstance(true)
class MaterialEditor extends ImguiTool
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

	var windowWidth: Float = 0;
	var windowHeight: Float = 0;

	var fileName: String = null;

	var materialDef : MaterialDef = null;

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

		materialDef = {};

		rebuildPreview();

	}

	public function openFile(f: String)
	{
		fileName = f;

		try
		{
			materialDef =  cerastes.file.CDParser.parse( hxd.Res.loader.load(f).entry.getText(), MaterialDef );
			rebuildPreview();
		} catch(e)
		{
			ImGuiToolManager.showPopup("Failed to open file",'$f could not be opened:\n${e}',Error);
		}
	}

	public static function buildMaterialPreview( scene: h3d.scene.Scene, def: MaterialDef )
	{
		var sphere = new h3d.prim.Sphere( 1, 128, 128, 1);
		//sphere.unindex();
		sphere.addNormals();
		sphere.addUVs();
		sphere.addTangents();

		// Create env
		//Create a background mesh
		var bg = new h3d.scene.Mesh(sphere, scene);
		bg.scale(10);
		//Make sure it is always rendered
		bg.material.mainPass.culling = Front;
		bg.material.mainPass.setPassName("overlay");

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

		var renderer = cast(preview.renderer, h3d.scene.pbr.Renderer);
		renderer.env = env;


		//Finally create a shader and apply it to the background mesh so we can actually render our environment on screen.
		var cubeShader = bg.material.mainPass.addShader(new h3d.shader.pbr.CubeLod(env.env));
		#end

		//sys.io.File.saveContent("res/mat/ribbed-chipped-metal.material", cerastes.file.CDPrinter.print( matDef ) );

		var previewMesh = new Mesh(sphere, def.toMaterial(), scene);

		//var cubeShader = bg.material.mainPass.addShader(new h3d.shader.pbr.CubeLod(env.env));
		#if pbr
		var light = new h3d.scene.pbr.PointLight(preview);

		light.range = 100;
		light.power = 8;
		#else
		var light = new h3d.scene.fwd.PointLight(scene);
		light.params.z /= 200;
		#end

		light.setPosition(-3, 15, 10);

		return previewMesh;
	}

	function rebuildPreview()
	{
		preview.removeChildren();

		previewMesh = buildMaterialPreview( preview, materialDef );



	}

	// Called every frame. Does a lighter version of rebuildPreview
	function refreshPreview()
	{
		previewMesh.material = materialDef.toMaterial();
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
		ImGui.begin('\uf1de Material Editor - ${ fileName != null ? fileName : "Untitled" }###${windowID()}', isOpenRef, ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.MenuBar);

		menuBar();

		dockSpace();

		ImGui.dockSpace( dockspaceId, null );

		ImGui.end();

		//ImGui.dockSpace(dockID);
		//ImGui.setNextWindowDockId(dockID, Once);

		ImGui.setNextWindowDockId( dockspaceIdCenter, dockCond );
		ImGui.begin('Editor##${windowID()}', null, ImGuiWindowFlags.NoMove | ImGuiWindowFlags.HorizontalScrollbar );
		handleShortcuts();

		var changed = false;

		ImGui.text("Textures");
		ImGui.separator();

		var ret = IG.inputTexture("Albedo", materialDef.albedo);
		if( ret != null )
			materialDef.albedo = ret == "" ? null : ret;

		ret = IG.inputTexture("Normal", materialDef.normal);
		if( ret != null )
			materialDef.normal = ret == "" ? null : ret;

		#if pbr
		ret = IG.inputTexture("Metalness", materialDef.pbr);
		if( ret != null )
			materialDef.pbr = ret == "" ? null : ret;

		// If no material set: add sliders for PBR values
		if( materialDef.pbr == null)
		{
			ImGui.text("Surface Properties");
			ImGui.separator();
			wref( ImGui.sliderDouble("Metalness##value", _, 0, 1 ), materialDef.metalness );
			wref( ImGui.sliderDouble("Roughness##value", _, 0, 1 ), materialDef.roughness );
			wref( ImGui.sliderDouble("Occlusion##value", _, 0, 1 ), materialDef.occlusion );
		}

		ImGui.text("Render settings");
		ImGui.separator();

		#end

		wref( ImGui.sliderDouble("Emissive##value", _, 0, 1 ), materialDef.emissive );
		wref( ImGui.checkbox("Alpha Kill", _ ), materialDef.alphaKill );
		wref( ImGui.checkbox("Shadows", _ ), materialDef.shadows );


		processMouse();


		ImGui.end();

		openfiles();
		materialPreview();



		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}

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
		var fs: hxd.fs.LocalFileSystem = cast hxd.Res.loader.fs;

		var newFile = UI.saveFile({
			title:"Save As...",
			fileName: '${fs.baseDir}mat/',
			filters:[
			{name:"Cerastes materials", exts:["material"]}
			]
		});
		if( newFile != null )
		{
			sys.io.File.saveContent(Utils.fixWritePath(newFile,"material"), cerastes.file.CDPrinter.print( materialDef ) );

			fileName = Utils.toLocalFile( newFile );

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

		sys.io.File.saveContent(Utils.fixWritePath(fileName,"material"), cerastes.file.CDPrinter.print( materialDef ) );

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
		return 'materialEditor${fileName != null ? fileName : ""+toolId}';
	}


	var mouseStart: ImVec2;
	function processMouse()
	{

	}


	function openfiles()
	{
		ImGui.setNextWindowDockId( dockspaceIdLeft, dockCond );
		ImGui.begin('Materials##${windowID()}');
		handleShortcuts();


		ImGui.end();

	}



	function materialPreview()
	{
		refreshPreview();

		ImGui.setNextWindowDockId( dockspaceIdRight, dockCond );
		ImGui.begin('Preview##${windowID()}');
		handleShortcuts();

		var size = ImGui.getWindowSize();


		ImGui.image(sceneRT, { x: size.x , y: size.x }, null, null, null );

		ImGui.end();

		var size = ImGui.getWindowSize();




	}






	function dockSpace()
	{
		if( dockspaceId == -1 || ImGui.dockBuilderGetNode( dockspaceId ) == null || dockCond == Always )
		{
			var str = 'FlowEditorDockspace${windowID()}';

			dockspaceId = ImGui.getID(str);
			dockspaceIdLeft = ImGui.getID(str+"Left");
			dockspaceIdRight = ImGui.getID(str+"Right");
			dockspaceIdCenter = ImGui.getID(str+"Center");

			// Clear any existing layout
			var flags: ImGuiDockNodeFlags = ImGuiDockNodeFlags.NoDockingInCentralNode | ImGuiDockNodeFlags.NoDockingSplitMe;

			ImGui.dockBuilderRemoveNode( dockspaceId );
			ImGui.dockBuilderAddNode( dockspaceId, flags );

			var idOut: hl.Ref<ImGuiID> = dockspaceId;

			dockspaceIdLeft = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Left, 0.20, null, idOut);
			dockspaceIdRight = ImGui.dockBuilderSplitNode(idOut.get(), ImGuiDir.Right, 0.4, null, idOut);
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