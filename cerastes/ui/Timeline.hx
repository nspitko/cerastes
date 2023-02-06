package cerastes.ui;

@:structInit class TimelineModifier
{
	public var target: String; // The element we're going to change
	public var key: String; // Key to modify
	public var value: Dynamic; // Value to set

	#if tools
	@:noSerialize public var prevValue: Dynamic = null; // The value we were at before. This is used for rollback.
	#end
}

/**
 * A type of timeline item that is a one shot event.
 */
@:structInit class TimelineOneShot extends TimelineItem
{
	var lastTime: Float = 0;

	public var operations: Array<TimelineModifier> = [];

	public override function step(t: Float)
	{
		super.step(t);

		if( lastTime < start && time >= start )
			run();
		#if tools
		else if( lastTime >= start && time < start )
			revert();
		#end

		lastTime = time;
	}

	public override function run()
	{
		for( op in operations )
		{
			var target = ui.getObjectByName(op.target);
			if( Utils.assert(target != null, 'Timeline target ${op.target} is missing') )
				continue;

			//var field = Reflect.field(target, op.key );

			//if( Utils.assert(field != null, 'Timeline field ${op.key} is invalid') )
			//	continue;

			Reflect.setField(target, op.key, op.value);
		}

	}

	#if tools
	public function revert()
	{

	}
	#end


}

/**
 * Base interface for all timeline events.
 */
@:keepSub
@:structInit class TimelineItem
{
	@:noSerialize public var ui: h2d.Object = null;

	public var start: Float = 0;
	public var length(get, default): Float = 0;

	var time(get, never): Float;
	@:noSerialize var absTime: Float = 0;

	function get_length() { return length; }
	function get_time() { return absTime - start; }

	public function initialize( target: h2d.Object )
	{
		ui = target;
	}

	public function run()
	{

	}

	/**
	 * Step to this specific time. Step takes an absolute time, so it should be
	 * able to step backwards reasonably. Translation to localtime is done
	 * internally.
	 *
	 * @param t
	 */
	public function step( t: Float )
	{
		absTime = t;
	}
}

class Timeline
{
	public var items: Array<TimelineItem>;
	public var time: Float;
	public var ui: h2d.Object;

	public function new( ui: h2d.Object, it: Array<TimelineItem> )
	{
		items = it;
		this.ui = ui;

		for( i in items )
			i.initialize(ui);
	}

	public function tick(d: Float )
	{
		time += d;

		for( i in items )
			i.step( time );
	}
}