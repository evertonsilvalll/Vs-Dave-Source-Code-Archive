package;

import flixel.FlxG;
import flixel.graphics.frames.FlxAtlasFrames;
#if android
import flixel.graphics.FlxGraphic;
import haxe.Json;
#end
import openfl.utils.AssetType;
import openfl.utils.Assets as OpenFlAssets;

class Paths
{
	inline public static var SOUND_EXT = #if web "mp3" #else "ogg" #end;

	static var currentLevel:String;

	#if android
	static var androidAtlases:Map<String, AndroidAtlasFrames> = new Map();
	#end

	static public function setCurrentLevel(name:String)
	{
		currentLevel = name.toLowerCase();
	}

	static function getPath(file:String, type:AssetType, library:Null<String>)
	{
		if (library != null)
			return getLibraryPath(file, library);

		if (currentLevel != null)
		{
			var levelPath = getLibraryPathForce(file, currentLevel);
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;

			levelPath = getLibraryPathForce(file, "shared");
			if (OpenFlAssets.exists(levelPath, type))
				return levelPath;
		}

		return getPreloadPath(file);
	}

	static public function getLibraryPath(file:String, library = "preload")
	{
		return if (library == "preload" || library == "default") getPreloadPath(file); else getLibraryPathForce(file, library);
	}

	inline static function getLibraryPathForce(file:String, library:String)
	{
		return '$library:assets/$library/$file';
	}

	inline static function getPreloadPath(file:String)
	{
		return 'assets/$file';
	}

	inline static public function file(file:String, type:AssetType = TEXT, ?library:String)
	{
		return getPath(file, type, library);
	}

	inline static public function txt(key:String, ?library:String)
	{
		return getPath('data/$key.txt', TEXT, library);
	}

	inline static public function xml(key:String, ?library:String)
	{
		return getPath('data/$key.xml', TEXT, library);
	}

	inline static public function json(key:String, ?library:String)
	{
		return getPath('data/$key.json', TEXT, library);
	}

	static public function sound(key:String, ?library:String)
	{
		return getPath('sounds/$key.$SOUND_EXT', SOUND, library);
	}

	inline static public function soundRandom(key:String, min:Int, max:Int, ?library:String)
	{
		return sound(key + FlxG.random.int(min, max), library);
	}

	inline static public function music(key:String, ?library:String)
	{
		return getPath('music/$key.$SOUND_EXT', MUSIC, library);
	}

	inline static public function voices(song:String)
	{
		return 'songs:assets/songs/${song.toLowerCase()}/Voices.$SOUND_EXT';
	}

	inline static public function inst(song:String)
	{
		return 'songs:assets/songs/${song.toLowerCase()}/Inst.$SOUND_EXT';
	}

	inline static public function externmusic(song:String)
	{
		return 'songs:assets/songs/extern/${song.toLowerCase()}.$SOUND_EXT';
	}

	inline static public function image(key:String, ?library:String)
	{
		return getPath('images/$key.png', IMAGE, library);
	}

	inline static public function font(key:String)
	{
		return 'assets/fonts/$key';
	}

	static public function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames
	{
		#if android
		var manifestPath = file('images/$key.android.json', TEXT, library);
		if (OpenFlAssets.exists(manifestPath, TEXT))
		{
			var cached = androidAtlases.get(manifestPath);
			if (cached != null && cached.frames != null && cached.parent != null && cached.parent.bitmap != null)
				return cached;

			var manifest:AndroidAtlasManifest = Json.parse(OpenFlAssets.getText(manifestPath));
			if (manifest.version != 1 || manifest.pages.length == 0)
				throw 'Invalid Android atlas: $manifestPath';
			var directory = manifestPath.substr(0, manifestPath.lastIndexOf('/') + 1);
			var pages:Array<FlxAtlasFrames> = [];
			for (page in manifest.pages)
				pages.push(FlxAtlasFrames.fromSparrow(directory + page + '.png', directory + page + '.xml'));

			var combined = new AndroidAtlasFrames(pages);
			for (name in manifest.frames)
			{
				var found = false;
				for (page in pages)
				{
					var frame = page.getByName(name);
					if (frame != null)
					{
						// Clones retain the page graphic and do not share destruction ownership.
						combined.pushFrame(frame.copyTo());
						found = true;
						break;
					}
				}
				if (!found)
					throw 'Missing Android atlas frame: $name';
			}
			androidAtlases.set(manifestPath, combined);
			return combined;
		}
		#end
		return FlxAtlasFrames.fromSparrow(image(key, library), file('images/$key.xml', TEXT, library));
	}

	inline static public function getPackerAtlas(key:String, ?library:String)
	{
		return FlxAtlasFrames.fromSpriteSheetPacker(image(key, library), file('images/$key.txt', library));
	}
}

#if android
private typedef AndroidAtlasManifest =
{
	var version:Int;
	var pages:Array<String>;
	var frames:Array<String>;
}

// Flixel 4.9 has no addAtlas(). Each copied frame keeps its own texture parent;
// retain secondary textures for exactly as long as the primary atlas is alive.
private class AndroidAtlasFrames extends FlxAtlasFrames
{
	var pageGraphics:Array<FlxGraphic> = [];

	public function new(pages:Array<FlxAtlasFrames>)
	{
		super(pages[0].parent);
		for (index in 1...pages.length)
		{
			var graphic = pages[index].parent;
			graphic.useCount++;
			pageGraphics.push(graphic);
		}
	}

	override public function destroy():Void
	{
		super.destroy();
		for (graphic in pageGraphics)
			if (graphic.bitmap != null)
				graphic.useCount--;
		pageGraphics = [];
	}
}
#end
