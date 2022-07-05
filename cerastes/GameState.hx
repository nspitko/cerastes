package cerastes;

import cerastes.flow.Flow.FlowRunner;
import cerastes.data.Nodes;

@:keep
class FlowState
{
	public static var seen: Array<String> = [];
	public static var usedSelectors: Array<NodeId32> = [];
	public static var doneActions: Array<String> = [];

	public static function reset()
	{
		seen = [];
		usedSelectors = [];
		doneActions = [];
	}
}