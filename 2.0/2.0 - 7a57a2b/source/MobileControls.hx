package;

#if android
import flixel.FlxG;
import flixel.FlxState;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import openfl.Lib;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.events.TouchEvent;
import openfl.geom.Point;
import openfl.geom.Rectangle;
import openfl.text.TextField;
import openfl.text.TextFormat;
import openfl.ui.Multitouch;
import openfl.ui.MultitouchInputMode;

/** Android overlay, independent of cameras so menus, dialogue and substates can use it. */
class MobileControls extends Sprite
{
	public static var instance(default, null):MobileControls;
	public static inline var LEFT:Int = 0;
	public static inline var DOWN:Int = 1;
	public static inline var UP:Int = 2;
	public static inline var RIGHT:Int = 3;
	public static inline var ACCEPT:Int = 4;
	public static inline var BACK:Int = 5;
	public static inline var PAUSE:Int = 6;

	static inline var BACK_POINTER:Int = -1000;

	var input:MobileInputState = new MobileInputState(7);
	var buttons:Array<Sprite> = [];
	var areas:Array<Rectangle> = [];
	var context:FlxState;
	var gameplay:Bool = false;

	public function new()
	{
		super();
		instance = this;
		mouseEnabled = false;
		mouseChildren = false;
		addButton("<", 28, 548, 184, 144);
		addButton("v", 232, 548, 184, 144);
		addButton("^", 864, 548, 184, 144);
		addButton(">", 1068, 548, 184, 144);
		addButton("OK", 1072, 24, 180, 88);
		addButton("BACK", 868, 24, 180, 88);
		addButton("PAUSE", 868, 24, 180, 88);
		Multitouch.inputMode = MultitouchInputMode.TOUCH_POINT;
		var stage = Lib.current.stage;
		stage.addEventListener(TouchEvent.TOUCH_BEGIN, onTouchBegin);
		stage.addEventListener(TouchEvent.TOUCH_MOVE, onTouchMove);
		stage.addEventListener(TouchEvent.TOUCH_END, onTouchEnd);
		stage.addEventListener(Event.DEACTIVATE, onDeactivate);
		stage.addEventListener(Event.RESIZE, onResize);
		// Lime's Android default backgrounds the application on BACK key-up.
		// Cancel both native events before OpenFL translates them into keyboard input.
		Lib.application.window.onKeyDown.add(onBackDown, false, 1000);
		Lib.application.window.onKeyUp.add(onBackUp, false, 1000);
		FlxG.signals.preUpdate.add(updateInput);
		FlxG.signals.preStateSwitch.add(clear);
		onResize(null);
	}

	function addButton(label:String, x:Float, y:Float, width:Float, height:Float):Void
	{
		var button = new Sprite();
		button.x = x;
		button.y = y;
		button.graphics.lineStyle(3, 0xFFFFFF, 0.8);
		button.graphics.beginFill(0x111111, 0.6);
		button.graphics.drawRoundRect(0, 0, width, height, 20, 20);
		button.graphics.endFill();
		var text = new TextField();
		text.defaultTextFormat = new TextFormat("_sans", label.length == 1 ? 60 : 28, 0xFFFFFF, true, null, null, null, null, "center");
		text.text = label;
		text.width = width;
		text.height = height;
		text.y = (height - (label.length == 1 ? 78 : 40)) / 2;
		text.selectable = false;
		button.addChild(text);
		addChild(button);
		buttons.push(button);
		areas.push(new Rectangle(x, y, width, height));
	}

	function onResize(event:Event):Void
	{
		var stage = Lib.current.stage;
		scaleX = scaleY = Math.min(stage.stageWidth / 1280, stage.stageHeight / 720);
		x = (stage.stageWidth - 1280 * scaleX) / 2;
		y = (stage.stageHeight - 720 * scaleY) / 2;
		clear();
	}

	/** Clear even between getters if a state opens/closes a substate during update. */
	function syncContext():Void
	{
		var current:FlxState = FlxG.state;
		while (current != null && current.subState != null)
			current = current.subState;
		if (current != context)
		{
			context = current;
			clear();
		}
		gameplay = Std.isOfType(FlxG.state, PlayState) && FlxG.state.subState == null;
		buttons[BACK].visible = !gameplay;
		buttons[PAUSE].visible = gameplay;
	}

	function updateInput():Void
	{
		syncContext();
		input.nextFrame();
		for (i in 0...buttons.length)
			buttons[i].alpha = input.held[i] ? 1 : 0.65;
	}

	function hit(event:TouchEvent):Int
	{
		var point = globalToLocal(new Point(event.stageX, event.stageY));
		for (i in 0...areas.length)
			if (buttons[i].visible && areas[i].contains(point.x, point.y))
				return i;
		return -1;
	}

	function onTouchBegin(event:TouchEvent):Void
	{
		syncContext();
		input.begin(event.touchPointID, hit(event));
	}

	function onTouchMove(event:TouchEvent):Void
	{
		syncContext();
		input.move(event.touchPointID, hit(event));
	}

	function onTouchEnd(event:TouchEvent):Void
	{
		input.end(event.touchPointID);
	}

	function onBackDown(key:KeyCode, modifier:KeyModifier):Void
	{
		if (key != KeyCode.APP_CONTROL_BACK)
			return;
		Lib.application.window.onKeyDown.cancel();
		syncContext();
		input.begin(BACK_POINTER, gameplay ? PAUSE : BACK);
	}

	function onBackUp(key:KeyCode, modifier:KeyModifier):Void
	{
		if (key != KeyCode.APP_CONTROL_BACK)
			return;
		Lib.application.window.onKeyUp.cancel();
		input.end(BACK_POINTER);
	}

	function onDeactivate(event:Event):Void
	{
		// Android may cancel touches without delivering TOUCH_END on focus loss.
		// Discard their IDs so the next fresh TOUCH_BEGIN can reuse them.
		input.clear(false);
	}

	function clear():Void
	{
		input.clear();
	}

	/** mode: 0 = held, 1 = just pressed, 2 = just released. Reads never consume edges. */
	public static function check(button:Int, mode:Int):Bool
	{
		if (instance == null)
			return false;
		instance.syncContext();
		return switch (mode)
		{
			case 1: instance.input.pressed[button];
			case 2: instance.input.released[button];
			default: instance.input.held[button];
		};
	}
}
#end

/** Pure input accumulator: several fingers may hold the same button without false releases. */
class MobileInputState
{
	public var held(default, null):Array<Bool>;
	public var pressed(default, null):Array<Bool>;
	public var released(default, null):Array<Bool>;

	var counts:Array<Int>;
	var pendingPress:Array<Bool>;
	var pendingRelease:Array<Bool>;
	var pointers:Map<Int, Int> = new Map();

	public function new(buttonCount:Int)
	{
		counts = [for (_ in 0...buttonCount) 0];
		held = [for (_ in counts) false];
		pressed = held.copy();
		released = held.copy();
		pendingPress = held.copy();
		pendingRelease = held.copy();
	}

	public function begin(pointer:Int, button:Int):Void
	{
		// Repeated key-down and held fingers blocked by a transition cannot re-press.
		if (pointers.exists(pointer))
			return;
		pointers.set(pointer, -1);
		move(pointer, button);
	}

	public function move(pointer:Int, button:Int):Void
	{
		if (!pointers.exists(pointer))
			return;
		var previous:Int = pointers.get(pointer);
		if (previous == -2 || previous == button)
			return;
		if (previous >= 0 && --counts[previous] == 0)
			pendingRelease[previous] = true;
		pointers.set(pointer, button);
		if (button >= 0 && counts[button]++ == 0)
			pendingPress[button] = true;
	}

	public function end(pointer:Int):Void
	{
		move(pointer, -1);
		pointers.remove(pointer);
	}

	public function nextFrame():Void
	{
		for (i in 0...counts.length)
		{
			pressed[i] = pendingPress[i];
			released[i] = pendingRelease[i];
			// A complete down/up between updates must still reach the rhythm-game check.
			held[i] = counts[i] > 0 || pendingPress[i];
			pendingPress[i] = pendingRelease[i] = false;
		}
	}

	public function clear(blockHeld:Bool = true):Void
	{
		if (blockHeld)
		{
			for (pointer in pointers.keys())
				pointers.set(pointer, -2); // Ignore until lifted, including slides onto a new screen.
		}
		else
			pointers = new Map();
		for (i in 0...counts.length)
		{
			counts[i] = 0;
			held[i] = pressed[i] = released[i] = pendingPress[i] = pendingRelease[i] = false;
		}
	}
}
