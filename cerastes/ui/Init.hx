package cerastes.ui;

class Init
{
	public static function setup()
	{
		no.Spoon.bend('h2d.Object', macro class {
			public var timelineDefs: Array<cerastes.ui.Timeline.Timeline>;

			public function createTimelineRunner( name: String, ?registerWithTimeManager: Bool = true )
			{
				if( timelineDefs == null )
					return null;

				for( t in timelineDefs )
				{
					if( t.name == name )
					{
						var i = new cerastes.ui.Timeline.TimelineRunner(t, this);
						if( registerWithTimeManager )
							cerastes.Tickable.TimeManager.register(i);

						return i;
					}
				}

				return null;
			}
		});


	}
}