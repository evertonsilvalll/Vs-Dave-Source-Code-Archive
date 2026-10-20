package;

import flixel.tweens.FlxTween;
import flixel.tweens.FlxEase;
import Controls.KeyboardScheme;
import Controls.Control;
import flash.text.TextField;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxMath;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.utils.Assets;
import Discord.DiscordClient;

class OptionsMenu extends MusicBeatState
{
	var selector:FlxText;
	var curSelected:Int = 0;

	var controlsStrings:Array<String> = [];

	private var grpControls:FlxTypedGroup<Alphabet>;
	var versionShit:FlxText;

	override function create()
	{
		DiscordClient.changePresence("In the Options Menu", null);

		var menuBG:FlxSprite = new FlxSprite().loadGraphic(Paths.image('backgrounds/SUSSUS AMOGUS'));
		controlsStrings = optionLabels();

		trace(controlsStrings);

		menuBG.color = 0xFFea71fd;
		menuBG.setGraphicSize(Std.int(menuBG.width * 1.1));
		menuBG.updateHitbox();
		menuBG.screenCenter();
		menuBG.antialiasing = true;
		menuBG.loadGraphic(MainMenuState.randomizeBG());
		add(menuBG);

		grpControls = new FlxTypedGroup<Alphabet>();
		add(grpControls);

		for (i in 0...controlsStrings.length)
		{
			var controlLabel:Alphabet = new Alphabet(0, (70 * i) + 30, controlsStrings[i], true, false);
			controlLabel.isMenuItem = true;
			controlLabel.targetY = i;
			grpControls.add(controlLabel);
			// DONT PUT X IN THE FIRST PARAMETER OF new ALPHABET() !!
		}

		versionShit = new FlxText(5, FlxG.height - 18, 0, "Offset (Left, Right): " + FlxG.save.data.offset, 12);
		versionShit.scrollFactor.set();
		versionShit.setFormat("VCR OSD Mono", 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(versionShit);

		super.create();
	}

	override function update(elapsed:Float)
	{
		super.update(elapsed);

		if (controls.BACK)
			FlxG.switchState(new MainMenuState());
		if (controls.UP_P)
			changeSelection(-1);
		if (controls.DOWN_P)
			changeSelection(1);

		if (controls.RIGHT_R)
		{
			FlxG.save.data.offset++;
			versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
		}

		if (controls.LEFT_R)
		{
			FlxG.save.data.offset--;
			versionShit.text = "Offset (Left, Right): " + FlxG.save.data.offset;
		}

		if (controls.ACCEPT)
		{
			switch (curSelected)
			{
				case 0:
					FlxG.save.data.dfjk = !FlxG.save.data.dfjk;
					if (FlxG.save.data.dfjk)
						controls.setKeyboardScheme(KeyboardScheme.Solo, true);
					else
						controls.setKeyboardScheme(KeyboardScheme.Duo(true), true);
				case 1:
					FlxG.save.data.newInput = !FlxG.save.data.newInput;
				case 2:
					FlxG.save.data.downscroll = !FlxG.save.data.downscroll;
				case 3:
					FlxG.save.data.accuracyDisplay = !FlxG.save.data.accuracyDisplay;
				case 4:
					FlxG.save.data.eyesores = !FlxG.save.data.eyesores;
				case 5:
					FlxG.save.data.donoteclick = !FlxG.save.data.donoteclick;
				case 6:
					FlxG.save.data.middlescroll = !FlxG.save.data.middlescroll;
				case 7:
					FlxG.save.data.ghostTapping = !FlxG.save.data.ghostTapping;
				#if android
				case 8:
					FlxG.save.data.mobileHitbox = !FlxG.save.data.mobileHitbox;
				case 9:
					FlxG.save.data.visibleHitbox = !FlxG.save.data.visibleHitbox;
				#end
			}
			controlsStrings = optionLabels();
			var previous = grpControls.members[curSelected];
			var label = new Alphabet(previous.x, previous.y, controlsStrings[curSelected], true, false);
			label.isMenuItem = true;
			label.targetY = 0;
			label.alpha = 1;
			// Keep the row at its index; remove/add would shift every later setting.
			grpControls.replace(previous, label);
			previous.destroy();
			FlxG.save.flush();
		}
	}

	function optionLabels():Array<String>
	{
		var labels = [
			FlxG.save.data.dfjk ? 'DFJK' : 'WASD',
			FlxG.save.data.newInput ? 'New Input' : 'Old Input',
			FlxG.save.data.downscroll ? 'Downscroll' : 'Upscroll',
			'Accuracy ' + (FlxG.save.data.accuracyDisplay ? 'off' : 'on'),
			FlxG.save.data.eyesores ? 'Eyesores Enabled' : 'Eyesores Disabled',
			FlxG.save.data.donoteclick ? 'Hitsounds On' : 'Hitsounds Off',
			FlxG.save.data.middlescroll ? 'Middlescroll On' : 'Middlescroll Off',
			FlxG.save.data.ghostTapping ? 'Ghost Tapping On' : 'Ghost Tapping Off'
		];
		#if android
		labels.push(FlxG.save.data.mobileHitbox ? 'Mobile Hitbox' : 'Mobile Psych Pad');
		labels.push(FlxG.save.data.visibleHitbox ? 'Hitbox Visible' : 'Hitbox Invisible');
		#end
		return labels;
	}

	var isSettingControl:Bool = false;

	override function beatHit()
	{
		super.beatHit();
		FlxTween.tween(FlxG.camera, {zoom: 1.05}, 0.3, {ease: FlxEase.quadOut, type: BACKWARD});
	}

	function changeSelection(change:Int = 0)
	{
		#if !switch
		// NGio.logEvent('Fresh');
		#end

		FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		curSelected += change;

		if (curSelected < 0)
			curSelected = grpControls.length - 1;
		if (curSelected >= grpControls.length)
			curSelected = 0;

		// selector.y = (70 * curSelected) + 30;

		var bullShit:Int = 0;

		for (item in grpControls.members)
		{
			item.targetY = bullShit - curSelected;
			bullShit++;

			item.alpha = 0.6;
			// item.setGraphicSize(Std.int(item.width * 0.8));

			if (item.targetY == 0)
			{
				item.alpha = 1;
				// item.setGraphicSize(Std.int(item.width));
			}
		}
	}
}
