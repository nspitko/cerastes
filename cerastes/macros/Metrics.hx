package cerastes.macros;

import haxe.Int64;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.Json;
#if macro
using haxe.macro.Tools;
#end

@:structInit
class TaskInfo
{
	public var label: String;
	public var begin: Float;
	public var end: Float;

	public var subtasks: Array<TaskInfo>;
	public var parent: TaskInfo;

	public var duration(get,never): Float ;
	public function get_duration() { return end - begin; }

}

@:structInit
class TaskStats
{
	public var min: Float;
	public var max: Float;
	public var avg: Float;
	public var count: Int64;
}


class Metrics
{
	#if debug
	public static var frames: Int64 = 0;
	public static var taskStats: Map<String, TaskStats> = [];
	public static var metricsLastFrame: TaskInfo;
	public static var metrics: TaskInfo = {
		label:"Frame",
		begin: -1,
		end: -1,
		subtasks: [],
		parent: null
	};
	#end

	public static function time() : Float
	{
		#if sys
		return Sys.time();
		#elseif js
		return js.lib.Date.now();
		#end
	}


	static var currentItem: TaskInfo = null;

	macro static public function begin( label:String = null ):Expr
	{
		#if debug
		if( label == null )
			label = '${Context.getLocalClass().toString()}.${ Context.getLocalMethod().toString() }';

		var exprs:Array<Expr> = [];
		exprs.push(macro cerastes.macros.Metrics.beginTask({ label: $v{label}, begin: Metrics.time(), end: -1, subtasks: [], parent: null }));

		return macro $b{exprs};
		#else
		return macro null;
		#end
	}

	@:noCompletion
	public static function beginTask( task: TaskInfo )
	{
		#if debug
		if( currentItem == null )
		{
			metrics = task;
			currentItem = task;
			return;
		}

		task.parent = currentItem;
		currentItem.subtasks.push(task);
		currentItem = task;
		#end
	}

	public static function end()
	{
		#if debug
		currentItem.end = time();

		if( taskStats.exists(currentItem.label))
		{
			var t = taskStats[currentItem.label];
			t.min = Math.min( t.min, currentItem.duration );
			t.max = Math.max( t.max, currentItem.duration );
			var c = 60 * 5;
			t.avg = ( ( t.avg * c ) + currentItem.duration ) / (c+1);
			t.count++;
		}
		else
		{
			taskStats.set(currentItem.label, {
				min: currentItem.duration,
				max: currentItem.duration,
				avg: currentItem.duration,
				count: 1
			});
		}

		currentItem = currentItem.parent;


		#end
	}

	public static function render( depth: Int = 0, ?subTask: TaskInfo = null )
	{
		#if debug
		if( subTask == null ) subTask = metricsLastFrame;
		if( subTask == null ) return;

        var w =  [for (i in 0...depth) "\t"].join("");

		trace('${w}${subTask.label}');
		trace('${w}duration: ${subTask.duration}');
		trace('${w}subtasks: ${subTask.subtasks.length}');
		for( t in subTask.subtasks )
			render(depth+1,t);

		#end
	}

	public static function endFrame()
	{
		#if debug
		metricsLastFrame = metrics;
		metricsLastFrame.end = time();
		metrics =  {
			label:"Frame",
			begin: time(),
			end: -1,
			subtasks: [],
			parent: null
		};
		currentItem = metrics;

		frames++;
		#end
	}
}