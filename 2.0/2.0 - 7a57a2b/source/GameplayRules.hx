package;

/** Shared rules for receptor/note positioning and empty-press penalties. */
class GameplayRules
{
	public static function laneX(lane:Int, player:Bool, screenWidth:Float, laneWidth:Float, middle:Bool):Float
	{
		if (!middle)
			return 50 + laneWidth * lane + (player ? screenWidth / 2 : 0);
		if (player)
			return (screenWidth - 4 * laneWidth) / 2 + laneWidth * lane;
		// Leave the center to the player and split opponent lanes along the edges.
		return lane < 2 ? 50 + laneWidth * lane : screenWidth - 50 - (4 - lane) * laneWidth;
	}

	public static function noteOffset(lane:Int, player:Bool, screenWidth:Float, laneWidth:Float, middle:Bool, cheating:Bool):Float
	{
		var visualLane = cheating ? [3, 1, 0, 2][lane] : lane;
		return laneX(visualLane, player, screenWidth, laneWidth, middle) - (50 + visualLane * laneWidth);
	}

	/** Keep every note at the earliest time: some shipped charts stack notes. */
	public static function keepEarliest<T:{strumTime:Float}>(candidates:Array<T>, note:T):Void
	{
		if (candidates.length == 0 || note.strumTime < candidates[0].strumTime)
		{
			candidates.resize(0);
			candidates.push(note);
		}
		else if (note.strumTime == candidates[0].strumTime)
			candidates.push(note);
	}

	public static inline function penalizeEmptyPress(pressed:Bool, hasNote:Bool, ghost:Bool):Bool
	{
		return pressed && !hasNote && !ghost;
	}
}
