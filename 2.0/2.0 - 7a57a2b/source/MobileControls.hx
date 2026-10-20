package;

#if android
import flixel.FlxG;
import flixel.FlxState;
import lime.ui.KeyCode;
import lime.ui.KeyModifier;
import lime.ui.Touch;
import openfl.Assets;
import openfl.Lib;
import openfl.display.Bitmap;
import openfl.display.BitmapData;
import openfl.display.Sprite;
import openfl.events.Event;
import openfl.geom.ColorTransform;
import openfl.geom.Point;
import openfl.geom.Rectangle;

/** Camera-independent Psych mobile pad and optional four-lane hitbox. */
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
	var layout:MobileControlLayout = new MobileControlLayout();
	var buttons:Array<Sprite> = [];
	var normalFrames:Array<Bitmap> = [];
	var pressedFrames:Array<Bitmap> = [];
	var lanes:Array<Sprite> = [];
	var colors:Array<Int> = [0xFF00FF, 0x00FFFF, 0x00FF00, 0xFF0000, 0xFF0000, 0xFFCB00, 0xFFFFFF];
	var context:FlxState;
	var gameplay:Bool = false;
	var hitbox:Bool = false;

	public function new()
	{
		super();
		instance = this;
		mouseEnabled = mouseChildren = false;
		for (i in 0...4)
		{
			var lane = new Sprite();
			lane.graphics.lineStyle(2, colors[i], 0.8);
			lane.graphics.beginFill(colors[i], 0.18);
			lane.graphics.drawRect(i * 320 + 1, 1, 318, 718);
			lane.graphics.endFill();
			addChild(lane);
			lanes.push(lane);
		}
		var names = ["left", "down", "up", "right", "a", "b", "pauseButton"];
		for (i in 0...names.length)
			addButton(names[i], i);

		// Native events avoid display-list propagation/focus swallowing a release.
		// Cancellation must release the lane just like lifting a finger.
		Touch.onStart.add(onTouchBegin);
		Touch.onMove.add(onTouchMove);
		Touch.onEnd.add(onTouchEnd);
		Touch.onCancel.add(onTouchEnd);
		var stage = Lib.current.stage;
		stage.addEventListener(Event.DEACTIVATE, onDeactivate);
		stage.addEventListener(Event.RESIZE, onResize);
		Lib.application.window.onKeyDown.add(onBackDown, false, 1000);
		Lib.application.window.onKeyUp.add(onBackUp, false, 1000);
		FlxG.signals.preUpdate.add(updateInput);
		FlxG.signals.preStateSwitch.add(clear);
		onResize(null);
	}

	function frame(source:BitmapData, rect:Rectangle, color:Int):Bitmap
	{
		var data = new BitmapData(Std.int(rect.width), Std.int(rect.height), true, 0);
		data.copyPixels(source, rect, new Point());
		var bitmap = new Bitmap(data);
		bitmap.smoothing = true;
		bitmap.transform.colorTransform = new ColorTransform(((color >> 16) & 255) / 255, ((color >> 8) & 255) / 255, (color & 255) / 255);
		return bitmap;
	}

	function addButton(name:String, id:Int):Void
	{
		var source = Assets.getBitmapData('assets/mobile/' + name + '.png');
		var width = Std.int(source.width / 3);
		var normal = frame(source, id == PAUSE ? new Rectangle(0, 0, 101, 93) : new Rectangle(0, 0, width, source.height), colors[id]);
		var pressed = frame(source, id == PAUSE ? new Rectangle(106, 0, 87, 81) : new Rectangle(width * 2, 0, width, source.height), colors[id]);
		var button = new Sprite();
		button.addChild(normal);
		button.addChild(pressed);
		addChild(button);
		buttons.push(button);
		normalFrames.push(normal);
		pressedFrames.push(pressed);
	}

	function onResize(event:Event):Void
	{
		var stage = Lib.current.stage;
		scaleX = scaleY = Math.min(stage.stageWidth / 1280, stage.stageHeight / 720);
		x = (stage.stageWidth - 1280 * scaleX) / 2;
		y = (stage.stageHeight - 720 * scaleY) / 2;
		clear();
	}

	function syncContext():Void
	{
		var current:FlxState = FlxG.state;
		while (current != null && current.subState != null)
			current = current.subState;
		var playing = Std.isOfType(FlxG.state, PlayState) && FlxG.state.subState == null;
		// Dialogue still needs A/B, including when hitbox is selected for songs.
		if (playing && cast(FlxG.state, PlayState).inCutscene)
			playing = false;
		var useHitbox = playing && FlxG.save.data.mobileHitbox == true;
		if (current != context || playing != gameplay || useHitbox != hitbox)
		{
			context = current;
			gameplay = playing;
			hitbox = useHitbox;
			layout.configure(gameplay, hitbox);
			clear();
		}
	}

	function updateInput():Void
	{
		syncContext();
		input.nextFrame();
		for (i in 0...buttons.length)
		{
			var area = layout.areas[i];
			buttons[i].visible = layout.active[i] && !(hitbox && i < 4);
			buttons[i].x = area.x;
			buttons[i].y = area.y;
			for (bitmap in [normalFrames[i], pressedFrames[i]])
			{
				bitmap.width = area.width;
				bitmap.height = area.height;
			}
			normalFrames[i].visible = !input.held[i];
			pressedFrames[i].visible = input.held[i];
			buttons[i].alpha = input.held[i] ? 0.9 : 0.55;
		}
		for (i in 0...4)
		{
			// Drawing is independent of hit testing: invisible lanes still work.
			lanes[i].visible = hitbox && FlxG.save.data.visibleHitbox != false;
			lanes[i].alpha = input.held[i] ? 0.8 : 0.18;
		}
	}

	function hit(touch:Touch):Int
	{
		var stage = Lib.current.stage;
		var point = globalToLocal(new Point(touch.x * stage.stageWidth, touch.y * stage.stageHeight));
		return layout.hit(point.x, point.y);
	}

	function onTouchBegin(touch:Touch):Void
	{
		syncContext();
		input.beginTouch(touch.id, hit(touch));
	}

	function onTouchMove(touch:Touch):Void
	{
		syncContext();
		input.move(touch.id, hit(touch));
	}

	function onTouchEnd(touch:Touch):Void
	{
		input.end(touch.id);
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
		input.clear(false);
	}

	function clear():Void
	{
		input.clear();
	}

	/** Reads never consume edges; several game systems may query one frame. */
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

/** Logical geometry is shared by rendering and input, independent of visibility. */
class MobileControlLayout
{
	public var areas(default, null):Array<{
		x:Float,
		y:Float,
		width:Float,
		height:Float
	}>;
	public var active(default, null):Array<Bool>;

	public function new()
	{
		configure(false, false);
	}

	public function configure(gameplay:Bool, hitbox:Bool):Void
	{
		areas = [
			{
				x: 0.,
				y: 456.,
				width: 132.,
				height: 132.
			},
			{
				x: 132.,
				y: 588.,
				width: 132.,
				height: 132.
			},
			{
				x: 132.,
				y: 324.,
				width: 132.,
				height: 132.
			},
			{
				x: 264.,
				y: 456.,
				width: 132.,
				height: 132.
			},
			{
				x: 1148.,
				y: 585.,
				width: 132.,
				height: 132.
			},
			{
				x: 1016.,
				y: 585.,
				width: 132.,
				height: 132.
			},
			{
				x: 1158.,
				y: 24.,
				width: 98.,
				height: 90.
			}
		];
		active = [true, true, true, true, !gameplay, !gameplay, gameplay];
		if (gameplay && hitbox)
			for (i in 0...4)
				areas[i] = {
					x: i * 320.,
					y: 0.,
					width: 320.,
					height: 720.
				};
	}

	public function hit(x:Float, y:Float):Int
	{
		// Pause wins over the right-hand hitbox; a pause touch never plays a note.
		for (i in [6, 4, 5, 0, 1, 2, 3])
		{
			var a = areas[i];
			if (active[i] && x >= a.x && x < a.x + a.width && y >= a.y && y < a.y + a.height)
				return i;
		}
		return -1;
	}
}

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

	/** A native start is a new contact, even when Android reuses an interrupted ID. */
	public function beginTouch(pointer:Int, button:Int):Void
	{
		end(pointer);
		begin(pointer, button);
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
