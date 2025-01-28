package cerastes;

typedef Tasklet = (Void->Void)->Void;

class TaskletRunner
{
	var tasks:Array<Tasklet> = [];

    public function new() {}

    public function then(tasklet: Tasklet ):TaskletRunner {
        tasks.push(tasklet);
        return this;
    }

    public function execute()
	{
        if ( tasks.length > 0 )
		{
            var currentTask = tasks.shift();
            currentTask(() -> execute());
        }
    }
}