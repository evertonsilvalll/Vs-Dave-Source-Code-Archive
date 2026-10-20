import flash.system.System;
import flixel.*;
import flixel.FlxState;

class CrasherState extends FlxState
{
	override public function create()
	{
		super.create();
		#if android
		FlxG.switchState(new MainMenuState());
		#else
		System.exit(0);
		#end
	}
}
