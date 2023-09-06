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

		no.Spoon.bend('h2d.Anim', macro class {

			/**
			 * restart/play currently cued animation
			 */
			public function replay()
			{
				currentFrame = 0;
				pause = false;
			}
		});

		no.Spoon.bend('h2d.Text', function (fields, cls) {
			if( cls == null || cls.name != "Text" )
				return;

			fields.patch(macro class {
				public var locToken: String;

				public function formatLoc( ...rest: String ) : Void
				{
					if( cerastes.Utils.assert( locToken != null, 'locToken cannot be null when calling formatLoc' ) )
						return;

					text = cerastes.LocalizationManager.localizeArray( locToken, rest.toArray() );
				}
			}, OnlyNew);
		  });

	}
}