import GameplayRules;

class GameplayRulesTest
{
	static var count = 0;

	static function check(value:Bool, message:String)
	{
		if (!value)
			throw message;
		count++;
	}

	static function main()
	{
		var width = 1280.;
		var laneWidth = 112.;
		for (middle in [false, true])
			for (player in [false, true])
				for (cheating in [false, true])
					for (lane in 0...4)
					{
						var visual = cheating ? [3, 1, 0, 2][lane] : lane;
						var receptor = GameplayRules.laneX(visual, player, width, laneWidth, middle);
						var originalNote = 50 + visual * laneWidth;
						var offset = GameplayRules.noteOffset(lane, player, width, laneWidth, middle, cheating);
						check(originalNote + offset == receptor, 'note follows its receptor');
						check(originalNote + 17 + offset == receptor + 17, 'sustain centering retained');
						check(receptor >= 0 && receptor + laneWidth <= width, 'lane stays onscreen');
					}
		var first = GameplayRules.laneX(0, true, width, laneWidth, true);
		var last = GameplayRules.laneX(3, true, width, laneWidth, true) + laneWidth;
		check((first + last) / 2 == width / 2, 'player lanes are centered');
		check(GameplayRules.laneX(1, false, width, laneWidth, true) + laneWidth < first, 'left opponent lanes outside center');
		check(GameplayRules.laneX(2, false, width, laneWidth, true) > last, 'right opponent lanes outside center');
		check(GameplayRules.laneX(0, true, width, laneWidth, false) == 690, 'normal layout preserved');
		check(!GameplayRules.penalizeEmptyPress(true, false, true), 'ghost ON ignores empty tap');
		check(GameplayRules.penalizeEmptyPress(true, false, false), 'ghost OFF penalizes empty tap');
		for (ghost in [false, true])
		{
			check(!GameplayRules.penalizeEmptyPress(false, false, ghost), 'no input is not an empty press');
			check(!GameplayRules.penalizeEmptyPress(true, true, ghost), 'hittable tap or sustain never produces empty penalty');
		}
		// Unsorted notes and the duplicate timestamps present in Screwed/Eggnog.
		var selected:Array<{strumTime:Float, id:Int}> = [];
		for (note in [
			          {strumTime: 25000., id: 0}, {strumTime: 24583.3333333333, id: 1},
			{strumTime: 24583.3333333333, id: 2},           {strumTime: 24600., id: 3}
		])
			GameplayRules.keepEarliest(selected, note);
		check(selected.length == 2 && selected[0].id == 1 && selected[1].id == 2, 'one press preserves all earliest stacked notes');
		GameplayRules.keepEarliest(selected, {strumTime: 24000., id: 4});
		check(selected.length == 1 && selected[0].id == 4, 'earlier candidate replaces later stack');
		Sys.println('PASS: ' + count + ' gameplay rules assertions');
	}
}
