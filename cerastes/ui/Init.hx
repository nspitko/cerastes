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

			public function runTimeline( name: String, loop: Bool = false )
			{
				var r = createTimelineRunner(name);
				if( r != null )
				{
					// runTimeline self disposes.
					r.loop = loop;

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

		no.Spoon.bend('h2d.TextInput', macro class {

			/**
			 * restart/play currently cued animation
			 */

			 public var inputHeight: Null<Int>;


			 override function sync(ctx) {
				var lines = getAllLines();
				interactive.width = (inputWidth != null ? inputWidth : maxWidth != null ? Math.ceil(maxWidth) : textWidth);
				interactive.height = inputHeight != null ? inputHeight : font.lineHeight * lines.length;
				super.sync(ctx);
			}

			override function draw(ctx:RenderContext) {
				if( inputWidth != null ) {
					var h = localToGlobal(new h2d.col.Point(inputWidth, inputHeight != null ? inputHeight : font.lineHeight));
					ctx.clipRenderZone(absX, absY, h.x - absX, h.y - absY);
				}

				if( cursorIndex >= 0 && (text != cursorText || cursorIndex != cursorXIndex) ) {
					if( cursorIndex > text.length ) cursorIndex = text.length;
					cursorText = text;
					cursorXIndex = cursorIndex;
					cursorX = getCursorXOffset();
					cursorY = getCursorYOffset();
					if( inputWidth != null && cursorX - scrollX >= inputWidth )
						scrollX = cursorX - inputWidth + 1;
					else if( cursorX < scrollX && cursorIndex > 0 )
						scrollX = cursorX - hxd.Math.imin(inputWidth, Std.int(cursorX));
					else if( cursorX < scrollX )
						scrollX = cursorX;
				}

				absX -= scrollX * matA;
				absY -= scrollX * matC;

				if( selectionRange != null ) {
					var lines = getAllLines();
					var lineOffset = 0;

					for(i in 0...lines.length) {
						var line = lines[i];

						var selEnd = line.length;

						if(selectionRange.start > lineOffset + line.length || selectionRange.start + selectionRange.length < lineOffset) {
							lineOffset += line.length;
							continue;
						}

						var selStart = Math.floor(Math.max(0, selectionRange.start - lineOffset));
						var selEnd = Math.floor(Math.min(line.length - selStart, selectionRange.length + selectionRange.start - lineOffset - selStart));

						selectionPos = calcTextWidth(line.substr(0, selStart));
						selectionSize = calcTextWidth(line.substr(selStart, selEnd));
						if( selectionRange.start + selectionRange.length == text.length ) selectionSize += cursorTile.width; // last pixel

						selectionTile.dx += selectionPos;
						selectionTile.dy += i * font.lineHeight;
						selectionTile.width += selectionSize;
						emitTile(ctx, selectionTile);
						selectionTile.dx -= selectionPos;
						selectionTile.dy -= i * font.lineHeight;
						selectionTile.width -= selectionSize;
						lineOffset += line.length;
					}
				}

				super.draw(ctx);
				absX += scrollX * matA;
				absY += scrollX * matC;

				if( cursorIndex >= 0 ) {
					cursorBlink += ctx.elapsedTime;
					if( cursorBlink % (cursorBlinkTime * 2) < cursorBlinkTime ) {
						cursorTile.dx += cursorX - scrollX;
						cursorTile.dy += cursorY;
						emitTile(ctx, cursorTile);
						cursorTile.dx -= cursorX - scrollX;
						cursorTile.dy -= cursorY;

					}
				}

				if( inputWidth != null )
					ctx.popRenderZone();
			}
		});

		no.Spoon.bend('hxd.Window', function (fields, cls) {
			if( cls == null || cls.name != "Window" )
				return;
			fields.patch(macro class {
				function new(title:String, width:Int, height:Int, fixed:Bool = false, sdlFlags: Int = 0, createCtx: Bool = true ) {
					this.windowWidth = width;
					this.windowHeight = height;
					eventTargets = new List();
					resizeEvents = new List();
					dropTargets = new List();
					#if hlsdl
					sdlFlags |= if (!fixed) sdl.Window.SDL_WINDOW_SHOWN | sdl.Window.SDL_WINDOW_RESIZABLE else sdl.Window.SDL_WINDOW_SHOWN;
					#if heaps_vulkan
					if( USE_VULKAN ) sdlFlags |= sdl.Window.SDL_WINDOW_VULKAN;
					#end
					window = new sdl.Window(title, width, height, sdl.Window.SDL_WINDOWPOS_CENTERED, sdl.Window.SDL_WINDOWPOS_CENTERED, sdlFlags);//, createCtx);
					this.windowWidth = window.width;
					this.windowHeight = window.height;
					#elseif hldx
					final dxFlags = if (!fixed) dx.Window.RESIZABLE else 0;
					window = new dx.Window(title, width, height, dx.Window.CW_USEDEFAULT, dx.Window.CW_USEDEFAULT, dxFlags);
					#end
					WINDOWS.push(this);
					#if multidriver
					id = window.id;
					#end
				}
			}, OnlyExisting);
		  });

/*
		  no.Spoon.bend('sdl.Window', function (fields, cls) {
			if( cls == null || cls.name != "Window" )
				return;

			fields.patch( macro class {
				public var destroyCtx = true;

				public function new( title : String, width : Int, height : Int, x : Int = sdl.Window.SDL_WINDOWPOS_CENTERED, y : Int = sdl.Window.SDL_WINDOWPOS_CENTERED, sdlFlags : Int = sdl.Window.SDL_WINDOW_SHOWN | sdl.Window.SDL_WINDOW_RESIZABLE, createCtx:Bool = true ) {
					while( true ) {
						this.win = winCreateEx(x, y, width, height, sdlFlags);
						if( win == null ) throw "Failed to create window";
						
						if( createCtx && glctx == null )
						{
							trace("Create new CTX");
							glctx = winGetGLContext(win);
							if( glctx == null || !GL.init() || !testGL() ) {
								destroy();
								if( Sdl.onGlContextRetry() ) continue;
								Sdl.onGlContextError();
							}
						}
						else 
							this.destroyCtx = false;
						break;
					}
					this.title = title;
					windows.push(this);
					vsync = true;
				}

				public function destroy() {
					
					try winDestroy(win, this.destroyCtx ? glctx : null) catch( e : Dynamic ) {};
					win = null;
					glctx = null;
					windows.remove(this);
				}
			}, All);
		});

*/
		#if multidriver
		no.Spoon.bend('h3d.impl.GlDriver', function (fields, cls) {
			if( cls == null || cls.name != "GlDriver" )
				return;

			fields.patch( macro class {

				override function present() {
					// We'll do it ourselves.
				}
			}, All);
		});
		#end


	}
}