package cerastes.tools;

import h2d.Tile;
import hxd.res.Atlas;
import cerastes.tools.ImguiTool.ImguiToolManager;
import h2d.Text;
import h2d.Font;
import cerastes.tools.ImguiTools.IG;
import cerastes.tools.ImguiTools.ImVec2Impl;
import imgui.ImGuiDrawable.ImGuiDrawableBuffers;
import h3d.mat.Texture;
import h2d.Bitmap;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import imgui.ImGui;
import h2d.Object;
import haxe.ds.Map;


@multiInstance(true)
class AtlasBrowser  extends  ImguiTool
{
	var viewportWidth: Int;
	var viewportHeight: Int;

	var filterText: String = "";

	var scaleFactor = Utils.getDPIScaleFactor();

	var fileName: String = null;

	var atlas: Atlas;

	var previewWidth : Float;
	var previewHeight: Float;

	static var globalIndex = 0;
	var index = 0;

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

		previewWidth = 100 * scaleFactor;
		previewHeight = 50 * scaleFactor;

		index = globalIndex++;

		// TESTING
		openFile("spr/sample.atlas");
	}

	public function openFile( f: String )
	{
		fileName = f;

		atlas = hxd.Res.load( fileName ).to(hxd.res.Atlas);


	}


	override public function update( delta: Float )
	{
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);

		ImGui.setNextWindowSize({x: 700 * scaleFactor, y: 400 * scaleFactor}, ImGuiCond.Once);
		ImGui.begin('\uf247 Atlas browser (${fileName})###${windowID()}', isOpenRef);

		var text = IG.textInput("",filterText,"Filter");
		if( text != null )
			filterText = text;


		ImGui.beginChild("atlasbrowser_assets",null, false, ImGuiWindowFlags.AlwaysAutoResize);



		populateTiles();

		ImGui.endChild();

		ImGui.end();

		if( !isOpenRef.get() )
		{
			ImguiToolManager.closeTool( this );
		}
	}


	function populateTiles()
	{

		var windowPos : ImVec2 =  ImGui.getWindowPos();
		var windowContentRegionMax : ImVec2 = ImGui.getWindowContentRegionMax();
		var windowRight = windowPos.x + windowContentRegionMax.x;
		var style : ImGuiStyle = ImGui.getStyle();
		for(name => tiles in atlas.getContents() )
		{
			if( filterText.length > 0 && !StringTools.contains(name, filterText) )
				continue;

			for( i in 0... tiles.length )
			{

				var tile = tiles[i];

				var desiredW = ( previewHeight / tile.height ) * tile.width;


				if( IG.imageButton( tile.t, {x: desiredW, y: previewHeight}, -1, 2 ) )
				{
					trace('Asset select: ${name}');
				}

				if( ImGui.isItemHovered() )
				{
					onItemHover(name, tile.t);
					if( ImGui.isMouseDoubleClicked( ImGuiMouseButton.Left ) )
					{
						trace('Asset open: ${name}');
					}
				}



				if( ImGui.beginDragDropSource() )
				{
					ImGui.setDragDropPayloadString("tile_name",name);
					ImGui.setDragDropPayloadString("atlas",fileName);

					ImGui.beginTooltip();
					IG.image( tile.t );
					ImGui.endTooltip();

					ImGui.endDragDropSource();
				}

				var itemRectMax: ImVec2 = ImGui.getItemRectMax();
				var nextButtonX2 = itemRectMax.x + style.ItemSpacing.x + previewWidth;
				if( nextButtonX2 < windowRight )
					ImGui.sameLine();
			}


		}
	}

	function onItemHover( name: String, tile: Tile )
	{
		ImGui.beginTooltip();
		ImGui.text(name);
		IG.image( tile, {x: 2, y: 2} );

		ImGui.endTooltip();
	}

	inline function windowID()
	{
		return 'atlasbrs${index}';
	}


}