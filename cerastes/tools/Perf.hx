
package cerastes.tools;

#if hlimgui
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
import imgui.ImGuiMacro.wref;

@:keep
class Perf extends ImguiTool
{
	var fps = new hl.NativeArray<Single>(60);
	var frameTime = new hl.NativeArray<Single>(60);
	var allocs = new hl.NativeArray<Single>(60);
	var allocsLast = new hl.NativeArray<Single>(60);

	var scaleFactor = Utils.getDPIScaleFactor();

	//var totalAllocs = new hl.NativeArray<Single>(60);

	var peakDeltaAllocs: Float = 0;
	var flameScale: Float = 1.;

	var paused: Bool = false;
	var savedMetrics: TaskInfo = null;

	var flameOffset: ImVec2;

	var updateRate: Float = -1;
	var updateTimer: Float = 0;

	var vsync: Bool = true;

	public override function getName() { return "\uf201 Performance"; }

	override public function update( delta: Float )
	{
		Metrics.begin();
		var isOpen = true;
		var isOpenRef = hl.Ref.make(isOpen);
		var stats = hl.Gc.stats();

		fps.blit(0,fps,1,59);
		fps[59] = Engine.getCurrent().fps;

		frameTime.blit(0,frameTime,1,59);
		frameTime[59] = hxd.Timer.elapsedTime;

		allocs.blit(0,allocs,1,59);
		allocsLast.blit(0,allocsLast,1,59);
		allocsLast[59] = stats.allocationCount;
		allocs[59] = stats.allocationCount - allocsLast[58];


		if( allocs[59] > peakDeltaAllocs )
			peakDeltaAllocs = allocs[59];

		var widgetSize : ImVec2 = {x: 300, y:100};

		ImGui.begin("\uf201 Performance", isOpenRef);

		var precision = 1000;

		ImGui.plotLines("", fps, 0, 'FPS: ${Math.round( Engine.getCurrent().fps * 100 ) / 100.0 }',0,hxd.Timer.wantedFPS * 1.2,widgetSize);
		ImGui.sameLine();
		ImGui.plotLines("", frameTime, 0, 'Frame time: ${Math.round(hxd.Timer.elapsedTime * precision) / precision}s',0,0.02,widgetSize);
		//ImGui.plotLines("", allocs, 0, 'Allocations: ${ Math.round( allocs[59] )}',0,peakDeltaAllocs,widgetSize);
		//ImGui.plotLines("", totalAllocs, 0, 'Total Allocations: ${ Math.round(totalAllocs[59])}',0,peakDeltaTotalAllocs,widgetSize);

		var ramBudget =  4096; // @todo Arbitrary number hello!
		var ramUsage = Gc.stats().currentMemory /1024/1024;

		var usageString = '${ Math.round( ramUsage )}MB System';

		ImGui.sameLine();

		ImGui.progressBar( ramUsage / ramBudget,  widgetSize, usageString );

		ImGui.sameLine();

		var memStats = Engine.getCurrent().mem.stats();

		ramBudget =  4096; // @todo Arbitrary number hello!
		ramUsage = memStats.totalMemory /1024/1024;

		usageString = '${ Math.round( ramUsage )}MB GPU';


		ImGui.progressBar( ramUsage / ramBudget,  widgetSize, usageString );

		#if debug
		flameChart();
		#end

		ImGui.end();

		if( !isOpenRef.get() )
		{
			ImGuiToolManager.closeTool( this );
		}
		Metrics.end();
	}

	#if debug
	function flameChart()
	{
		if( !paused )
		{
			if( ImGui.button("\uf04c") )
				paused = true;
		}
		else
		{
			if( ImGui.button("\uf04b") )
				paused = false;
		}

		ImGui.sameLine();
		var str = '${updateRate}s';
		if( updateRate == 0 ) str = "Immediate";
		if( updateRate == -1 ) str = "Slow frame capture";

		ImGui.setNextItemWidth( 200 );
		if( ImGui.beginCombo("Update rate", str ) )
		{
			if( ImGui.selectable("60s",	updateRate == 60 ) )	updateRate = 60;
			if( ImGui.selectable("5s", 	updateRate == 5 ) )		updateRate = 5;
			if( ImGui.selectable("1s", 	updateRate == 1 ) )		updateRate = 1;
			if( ImGui.selectable("0.5s", updateRate == 0.5 ) )	updateRate = 0.5;
			if( ImGui.selectable("Immediate", updateRate == 0 ) )	updateRate = 0;
			if( ImGui.selectable("Slow frame capture", updateRate == -1 ) )	updateRate = -1;


			ImGui.endCombo();
		}

		ImGui.sameLine();

		if( wref( ImGui.checkbox( "VSync", _ ), vsync ) )
			hxd.Window.getInstance().vsync = vsync;

		ImGui.beginChild("flameChart", null, true, ImGuiWindowFlags.NoScrollWithMouse );

		flameOffset = ImGui.getWindowPos();

		if( savedMetrics == null )
			savedMetrics = Metrics.metricsLastFrame;

		if( !paused )
		{
			updateTimer += hxd.Timer.elapsedTime;

			if( updateRate == -1  )
			{
				if( Metrics.metricsLastFrame != null && Metrics.metricsLastFrame.duration > 1/55 )
					savedMetrics = Metrics.metricsLastFrame;
			}
			else if( updateTimer > updateRate )
			{
				updateTimer -= updateRate;
				savedMetrics = Metrics.metricsLastFrame;
			}
		}


		var m = savedMetrics;

		if( m != null )
		{

			var min = m.begin;
			var max = m.end;
			var width = ImGui.getContentRegionAvail().x * flameScale;

			renderChartTask( m, 0, min, max, width );


			if( ImGui.isWindowHovered() )
			{
				// Should use imgui events here for consistency but GetIO isn't exposed to hl sooo...
				if (Key.isPressed(Key.MOUSE_WHEEL_DOWN))
				{
					flameScale--;
					if( flameScale <= 0 )
						flameScale = 1;
				}
				if (Key.isPressed(Key.MOUSE_WHEEL_UP))
				{
					flameScale++;
					if( flameScale > 200 )
						flameScale = 200;
				}
			}


		}

		ImGui.endChild();
	}

	function renderChartTask( task: TaskInfo, depth: Int = 0, min: Float, max: Float, frameWidth: Float )
	{

		var texture = h3d.mat.Texture.fromColor(0xFFFFFF,1.);
		var height = 20 * scaleFactor;
		var x1 = ( task.begin - min) / ( max - min );
		var x2 = ( task.end - min) / ( max - min );
		var w = x2 - x1;

		var left = x1 * frameWidth + 10;
		var top = height * depth;
		var width = w * frameWidth;

		ImGui.setCursorPos({ x: left, y: top  });
		var c = hashStringToColor(task.label);
		var bc: ImVec4 = {
			x: Math.min( c.x + 0.2, 1 ),
			y: Math.min( c.y + 0.2, 1 ),
			z: Math.min( c.z + 0.2, 1 ),
			w: 1.0,
		};
		ImGui.image( texture, { x: Math.max( width - 2, 1), y: Math.max( height - 2,1) },null, null, c, bc );

		if( ImGui.isItemHovered() )
		{
			var precision = 1000;
			ImGui.beginTooltip();
			ImGui.pushFont( ImGuiToolManager.headingFont );
			ImGui.text('${task.label}');//${task.duration * 1000}
			ImGui.popFont();
			ImGui.separator();
			ImGui.text('Duration: ${Math.round(task.duration * 1000 * precision) / precision}ms');//
			ImGui.text('Begins: ${ Math.round((task.begin - min ) * 1000 * precision ) / precision}ms');//${task.duration * 1000}
			ImGui.separator();

			var stats = Metrics.taskStats[ task.label ];

			if( stats != null )
			{
				ImGui.text('Avg: ${Math.round(stats.avg * 1000 * precision) / precision}ms');
				ImGui.text('Min: ${Math.round(stats.min * 1000 * precision) / precision}ms');
				ImGui.text('Max: ${Math.round(stats.max * 1000 * precision) / precision}ms');
				// Yes, this is the dumbest way to do this.
				// No, I'm not sorry.
				var cpf = Std.parseFloat(haxe.Int64.toStr(stats.count)) / Std.parseFloat(haxe.Int64.toStr(Metrics.frames));
				ImGui.text('Calls/frame: ${ Math.round(cpf * precision) / precision }');
			}
			ImGui.endTooltip();
		}
		ImGui.setCursorPos({ x: left + 4, y: top + 3 });
		ImGui.pushClipRect({x: left + flameOffset.x, y: top + flameOffset.y }, { x: left + flameOffset.x + width, y: top + flameOffset.y + height }, true);
		ImGui.text(task.label);

		ImGui.popClipRect();


		for( st in task.subtasks )
			renderChartTask( st, depth+1, min, max, frameWidth );
	}

	#end

	// https://stackoverflow.com/questions/11120840/hash-string-into-rgb-color
	function djb2(str: String )
	{
		var hash = 5381;
		for( i in 0...str.length )
		{
			hash = ((hash << 5) + hash ) + str.charCodeAt(i); /* hash * 33 + c */
		}

		return hash;
	}

	function hashStringToColor(str: String ) : ImVec4
	{
		var hash = djb2(str);
		var r = (hash & 0xFF0000) >> 16;
		var g = (hash & 0x00FF00) >> 8;
		var b = (hash & 0x0000FF);

		return {x: r / 350, y: g / 350, z: b / 350, w: 1.};
	}
}

#end