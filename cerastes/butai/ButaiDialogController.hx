package cerastes.butai;

import h2d.Flow;
import h3d.Vector;
import cerastes.ui.AdvancedText;

import cerastes.InputManager;
import cerastes.LocalizationManager;
import cerastes.Utils;
import h2d.Anim;
import h2d.Bitmap;
import h2d.Mask;
import h2d.Object;
import h2d.Text;
import h2d.Tile;
import tweenxcore.Tools.Easing;

class ButaiDialogController
{
	public static var instance : ButaiDialogController;
	public var container: h2d.Flow;

	private var currentLine = 0;

	public var busy = false;

	var stweenDone = false;
	var stweenTarget: Tile;
	var stween: Tween;

	private var bufferText = "";
	private var lines = new Array<{speaker: String, text: String}>();

	private var currentText : AdvancedText = null;
	public var textSizer : Text = null;
	private var textSpeed : Float = 0.01;

	private var cleanupBusy = false;
	private var advancing = false;

	private var lastSpeaker: String;

	private var advanceTimer : Timer = null;

	private var onComplete : Void -> Void = null;

	private var loopyTransition : Tween;

	var ticksSinceLastVisible = 90;

	public var font: h2d.Font;
	public var color: Vector = new Vector(1,1,1);
	public var multiline: Bool = false;
	public var autoadvance: Bool = false;
	public var dropShadow : { dx : Float, dy : Float, color : Int, alpha : Float } = null;


	public function new()
	{

		font = hxd.Res.fnt.kodenmanhou16.toFont();

		textSizer = new h2d.Text( font );

		textSizer.maxWidth = 1500;

		container = new Flow();
		container.layout = Vertical;
		container.verticalSpacing = 15;




		InputManager.register({callback: onInput, priority: 500 });




	}

	public function show( node: db.Butai.DialogueNode, cb: Void->Void )
	{

		container.visible = true;
		onComplete = cb;
		var split = node.dialogue.split("\n");
		lines = [];
		for( s in split )
		{
			var line = StringTools.trim(s);
			if( line == "" )
				continue;

			var speakerIdx = line.indexOf(':');


			// @todo probably a better way to solve this
			if( speakerIdx == -1 )
			{
				lines.push({
					speaker: "",
					text: StringTools.trim( line.substring(speakerIdx+1) ),
				});
			}
			else
			{

				lines.push({
					speaker: StringTools.trim( line.substring(0,speakerIdx) ),
					text:StringTools.trim( line.substring(0,speakerIdx) ) + ": " + StringTools.trim( line.substring(speakerIdx+1) ),
				});
			}
		}

		if( lines.length == 0 )
		{
			Utils.assert(false, 'dialogue node ${node.id} contains no dialogue.');
			return;
		}


		busy = true;

		// Pause the node manager until we're done with this line
		//ButaiNodeManager.pause();
		currentLine = -1;



		showNextLine();




	}


	private function onInput( button: InputButton, state: InputState, delta: Float )
	{
		if( !busy )
			return false;

		if( button == MOUSE_LEFT || button == ENTER || button == A || button == B || button == X || button == Y )
		{

			showNextLine();
			return true;
		}

		if( button == START )
		{
			endDialog();
			return true;
		}

		return false;
	}


	function showNextLine()
	{

		//textContainer.overflow = Hidden;

		var text : AdvancedText = new cerastes.ui.AdvancedText( font );
		text.maxWidth = 1600;
		text.color = color;


		if( bufferText == "" )
		{
			// If we're done then eject
			if( lines.length == 0 )
			{
				endDialog();

				return;
			}

			var line = lines.shift();


			bufferText = LocalizationManager.localize( line.text );


		}

		if( advancing && bufferText != "")
		{
			advanceTimer.cancel();
			currentText.animate = false;

			var char = advanceCharacter();
			while( char != "")
			{
				/*
				if( char == "\n")
				{
					currentText = text;
					showNextLine();
					return;
				}
				*/

				char = advanceCharacter();
			}

			advancing = false;
			//if( autoadvance )
			//	showNextLine();
			return;
		}

		currentText = text;
		//var img: h2d.Bitmap = cast Utils.findElementTraverse( view, "dialog_avatar").obj;
		//text.text = "";

		new Timer(textSpeed, timedAdvance);
		if( !multiline )
			container.removeChildren();
		container.addChild( text );



/*

		*/
		//trace('Final size: '+ text.textHeight + " for text: " + text.text);

		//img.tile = hxd.Res.loader.load( line.speaker.sprites[0].texture ).toTile();
		//img.tile.scaleToSize(36,36);


	}

	function timedAdvance()
	{

		var char = advanceCharacter();
		if( char == "." )
			advanceTimer = new Timer(textSpeed * 20, timedAdvance);
		else if(char == ",")
			advanceTimer = new Timer(textSpeed * 10 , timedAdvance);
		else if( char == "\n" )
			advanceTimer = new Timer(textSpeed * 50, showNextLine);
		else if( char != "")
			advanceTimer = new Timer(textSpeed, timedAdvance);
	}

	function advanceCharacter() : String
	{
		advancing = true;
		if( bufferText.length == 0 )
		{
			advancing = false;

			if( autoadvance && lines.length > 0 )
				showNextLine();
			return "";
		}

		var char = bufferText.substr(0,1);
		var wordIdx = bufferText.indexOf(" ");
		var lineIdx = bufferText.indexOf("\n");

		if( char == "\n")
		{
			//advancing = false;
			bufferText = bufferText.substr(1);
			return "\n";
		}

		if( lineIdx > 0 )
			wordIdx = wordIdx > lineIdx ? lineIdx : wordIdx;

		if( wordIdx == -1 )
			wordIdx = bufferText.length;

		var word = bufferText.substr(0,wordIdx);

		// Escape sequence checks
		if( char == "$" )
		{

			if( StringTools.startsWith(word, "$sfx") )
			{
				// PLAY SFX
				var sfx = word.substr(5);
				SoundManager.sfx('${sfx}');


				bufferText = bufferText.substr(wordIdx);
				if( bufferText.substr(0,1) == " ")
					bufferText = bufferText.substr(1);

				return advanceCharacter();
			}
		}

		var oldText = currentText.text;
		var oldTextSize = textSizer.textHeight;
		textSizer.text = currentText.text + word;

		if( textSizer.textHeight > oldTextSize && textSizer.textHeight < 200 )
		{
			//trace('WRAP: char: $char, word: $word, old: ${StringTools.replace(oldText, "\n", "-NL-") }, $oldTextSize tall. new: ${StringTools.replace(textSizer.text, "\n", "-NL-") }, ${textSizer.textHeight} tall. ');
			oldText = oldText.substr(0, oldText.length-1 ) + "\n";

		}

		if( textSizer.textHeight > 200 )
		{
			//trace('SPLIT: char: $char, word: $word, old: ${StringTools.replace(oldText, "\n", "-NL-") }, $oldTextSize tall. new: ${StringTools.replace(textSizer.text, "\n", "-NL-") }, ${textSizer.textHeight} tall. ');

			lines.insert(0, {
				speaker: lastSpeaker,
				text: bufferText
			} );
			bufferText = "";

			advancing = false;


			//showNextLine();
			return "";
		}

		currentText.text = oldText + char;

		bufferText = bufferText.substr(1);

		return char;

	}

	function endDialog()
	{
		if( !container.visible )
			return;

		container.removeChildren();

		container.visible =false;

		bufferText = "";
		//Utils.info('Completed dialog event.');

		busy = false;
		//ButaiNodeManager.resume();
		if( onComplete != null )
			onComplete();

	}

	public function forceHide()
	{
		endDialog();

	}

	public function tick( delta: Float )
	{

	}
}