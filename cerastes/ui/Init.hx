package cerastes.ui;

class Init
{
	public static function setup()
	{
		no.Spoon.bend('h2d.Object', macro class {
			public var timelineDefs: Array<cerastes.ui.Timeline.Timeline>;
			public var scripts: Map<cerastes.fmt.CUIResource.CUIScriptId,hscript.Expr>;

			public static var fnParseScript: (cerastes.fmt.CUIResource.UIScript) -> hscript.Expr;
			public static var fnRunScript: (hscript.Expr, h2d.Object ) -> Void;

			public function runTimeline( name: String )
			{
				var r = createTimelineRunner(name);
				if( r != null )
				{
					// runTimeline self disposes.
					r.removeOnComplete = true;
					cerastes.Tickable.TimeManager.register(r);
					r.play();
				}
				else
				{
					cerastes.Utils.error('Object $this does not have a timeline named $name');
				}
			}

			@:noCompletion
			public function setTimer( scriptId: cerastes.fmt.CUIResource.CUIScriptId, delay: Float )
			{
				new cerastes.Timer(delay, () ->{ triggerScript(scriptId); });
			}

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

			public function registerScript( scriptId: cerastes.fmt.CUIResource.CUIScriptId, script: cerastes.fmt.CUIResource.UIScript )
			{
				if( fnParseScript == null )
				{
					cerastes.Utils.warning('Trying to register script but no parser function is set!');
					return;
				}

				if(scripts == null ) scripts = [];
				scripts[scriptId] = fnParseScript( script );
			}

			public function triggerScript( scriptId )
			{
				if( fnRunScript == null )
				{
					cerastes.Utils.warning('Trying to run script but no interp function is set!');
					return;
				}

				if( scripts != null && scripts.exists(scriptId) )
				{
					fnRunScript( scripts[scriptId], this );
				}
			}

			// !! Overrides base type
			function onAdd()
			{
				allocated = true;
				if( filter != null )
					filter.bind(this);

				triggerScript( cerastes.fmt.CUIResource.CUIScriptId.OnAdd );

				if( children != null )
					for( c in children )
						if( c != null )
							c.onAdd();
			}

			// !! Overrides base type
			function onRemove()
			{
				allocated = false;
				if( filter != null )
					filter.unbind(this);

				triggerScript( cerastes.fmt.CUIResource.CUIScriptId.OnRemove );

				var i = children.length - 1;
				while( i >= 0 )
				{
					var c = children[i--];
					if( c != null ) c.onRemove();
				}
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
					if( !cerastes.Utils.verify( locToken != null, 'locToken cannot be null when calling formatLoc' ) )
						return;

					text = cerastes.LocalizationManager.localizeArray( locToken, rest.toArray() );
				}
			}, OnlyNew);
		  });

	}
}