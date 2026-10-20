import MobileControls.MobileInputState;
import MobileControls.MobileControlLayout;

class MobileInputTest
{
	static var count = 0;

	static function check(value:Bool, label:String)
	{
		if (!value)
			throw label;
		count++;
	}

	static function main()
	{
		var m = new MobileInputState(7);
		m.begin(1, 0);
		m.end(1);
		m.nextFrame();
		check(m.pressed[0] && m.released[0] && m.held[0], 'tap between frames');
		check(m.pressed[0] && m.pressed[0], 'non-consuming repeated reads');
		m.nextFrame();
		check(!m.pressed[0] && !m.held[0] && !m.released[0], 'edges expire');
		m.begin(1, 0);
		m.begin(2, 0);
		m.nextFrame();
		check(m.pressed[0] && m.held[0], 'two fingers same button');
		m.end(1);
		m.nextFrame();
		check(m.held[0] && !m.released[0] && !m.pressed[0], 'one finger release');
		m.move(2, 1);
		m.nextFrame();
		check(m.released[0] && !m.held[0] && m.pressed[1] && m.held[1], 'slide');
		m.begin(3, 2);
		m.nextFrame();
		check(m.held[1] && m.held[2], 'chord');
		m.clear();
		check(!m.held[1] && !m.held[2] && !m.pressed[2], 'focus / transition clear');
		m.move(2, 3);
		m.begin(2, 3);
		m.nextFrame();
		check(!m.pressed[3] && !m.held[3], 'blocked held pointer cannot accept next screen');
		m.end(2);
		m.begin(2, 3);
		m.nextFrame();
		check(m.pressed[3] && m.held[3], 'fresh press after lift');
		m.begin(4, -1);
		m.move(4, 4);
		m.nextFrame();
		check(m.pressed[4], 'slide in from outside');
		m.move(4, -1);
		m.nextFrame();
		check(m.released[4] && !m.held[4], 'slide out');
		m.clear();
		m.end(3);
		m.end(2);
		m.end(4);
		m.begin(-1000, 5);
		m.nextFrame();
		check(m.pressed[5], 'hardware BACK');
		m.begin(-1000, 5);
		m.nextFrame();
		check(!m.pressed[5] && m.held[5], 'BACK autorepeat ignored');
		m.clear();
		m.begin(-1000, 5);
		m.nextFrame();
		check(!m.pressed[5], 'BACK held across transition ignored');
		m.end(-1000);
		m.begin(-1000, 6);
		m.nextFrame();
		check(m.pressed[6], 'BACK can pause after key-up');
		m.clear(false);
		m.move(-1000, 6);
		m.nextFrame();
		check(!m.held[6], 'focus loss ignores stale move');
		m.begin(-1000, 6);
		m.nextFrame();
		check(m.pressed[6], 'new begin can reuse canceled pointer ID after focus loss');
		m.clear();
		m.nextFrame();
		check(!m.pressed[6] && !m.released[6] && !m.held[6], 'clear also discards pending edges');
		// Android may reuse an ID after a canceled/lost release. A fresh native
		// start must retrigger; keyboard autorepeat above must still be ignored.
		m.clear(false);
		for (i in 0...100)
		{
			m.beginTouch(0, i % 4);
			m.nextFrame();
			check(m.pressed[i % 4] && m.held[i % 4], 'repeated native touch ' + i);
			if (i % 2 == 0)
				m.end(0); // alternate real releases and interrupted IDs
			m.nextFrame();
		}
		m.end(0); // Touch.onCancel uses the same path as onEnd.
		m.nextFrame();
		check(!m.held[3] && m.released[3], 'cancellation releases sustain');
		m.beginTouch(0, 0);
		m.clear();
		m.move(0, 1);
		m.nextFrame();
		check(!m.pressed[1], 'slide across pause transition stays blocked');
		m.beginTouch(0, 1);
		m.nextFrame();
		check(m.pressed[1], 'new contact recovers interrupted transition ID');

		var layout = new MobileControlLayout();
		check(layout.hit(1200, 640) == 4 && layout.hit(1080, 640) == 5, 'menu A and B');
		check(layout.hit(200, 400) == 2 && layout.hit(200, 650) == 1, 'menu up/down');
		layout.configure(true, false);
		check(layout.hit(1200, 640) == -1 && layout.hit(1200, 60) == 6, 'song hides A/B and enables pause');
		layout.configure(true, true);
		for (i in 0...4)
		{
			check(layout.hit(i * 320 + 160, 360) == i, 'full screen lane ' + i);
			check(layout.hit(i * 320, 719) == i, 'lane boundary ' + i);
		}
		check(layout.hit(1200, 60) == 6, 'pause takes priority over hitbox');
		check(layout.hit(-1, 300) == -1 && layout.hit(1280, 300) == -1, 'letterbox excluded');
		layout.configure(false, true);
		check(layout.hit(500, 300) == -1 && layout.hit(1200, 640) == 4, 'pause/menu restores pad even with hitbox selected');
		Sys.println('PASS: ' + count + ' mobile input assertions');
	}
}
