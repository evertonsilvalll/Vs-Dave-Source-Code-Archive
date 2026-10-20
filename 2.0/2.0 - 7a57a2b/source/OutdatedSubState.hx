package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxSubState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;

class OutdatedSubState extends MusicBeatState
{
	public static var leftState:Bool = false;

	public static var needVer:String = "IDFK LOL";

	override function create()
	{
		super.create();
		var bg:FlxSprite = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
		add(bg);
		var txt:FlxText = null;
		if (FlxG.save.data.begin_thing == true)
		{
			txt = new FlxText(0, 0, FlxG.width,
				"Hello! \nThis mod utilizes shaders that may be of disturbance to some. \nIf you wish to disable these, \nturn off the Eyesores option in the options menu. \n Also, Supernovae and Glitch are not meant to be taken seriously and are not composed by me. \n Supernovae is by ArchWk, and Glitch is by The Boneyard. \nPress Enter to continue.",
				32);
		}
		else
		{
			txt = new FlxText(0, 0, FlxG.width,
				"Hello! \nThis mod utilizes shaders that may be of disturbance to some. \nIf you wish to disable these, \npress N, otherwise press Y. You can change this in options. \n Also, Supernovae and Glitch are not meant to be taken seriously and are not composed by me. \n Supernovae is by ArchWk, and Glitch is by The Boneyard.",
				32);
		}
		#if android
		txt.text = "This mod contains flashing shader effects.\n"
			+ (FlxG.save.data.begin_thing == true ? "Tap OK to continue." : "Tap OK to enable effects, or BACK to disable them.")
			+ "\nYou can change Eyesores in Options at any time.";
		#end
		txt.setFormat("Comic Sans MS Bold", 32, FlxColor.WHITE, CENTER);
		txt.screenCenter();
		txt.antialiasing = true;
		add(txt);
	}

	override function update(elapsed:Float)
	{
		if (controls.ACCEPT && FlxG.save.data.begin_thing == true)
		{
			leftState = true;
			FlxG.save.flush();
			FlxG.switchState(new MainMenuState());
			return;
		}
		if ((FlxG.keys.justPressed.Y #if android || controls.ACCEPT #end) && FlxG.save.data.begin_thing != true)
		{
			FlxG.save.data.begin_thing = true;
			FlxG.save.data.eyesores = true;
			leftState = true;
			FlxG.save.flush();
			FlxG.switchState(new MainMenuState());
			return;
		}
		if ((FlxG.keys.justPressed.N #if android || controls.BACK #end) && FlxG.save.data.begin_thing != true)
		{
			FlxG.save.data.begin_thing = true;
			FlxG.save.data.eyesores = false;
			leftState = true;
			FlxG.save.flush();
			FlxG.switchState(new MainMenuState());
			return;
		}
		super.update(elapsed);
	}
}
