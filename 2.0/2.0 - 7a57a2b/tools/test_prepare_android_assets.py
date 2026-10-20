"""Run with: python3 -m unittest discover -s tools -p 'test_*.py'."""

import hashlib
import json
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from PIL import Image

from prepare_android_assets import prepare, repack_atlas


class AndroidAtlasTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.base = Path(self.temporary.name)
        self.source = self.base / 'source'
        self.source.mkdir()
        self.png = self.source / 'atlas.png'
        image = Image.new('RGBA', (30, 10))
        for y in range(image.height):
            for x in range(image.width):
                image.putpixel((x, y), (x * 7, y * 13, (x + y) * 3, (x * y) % 256))
        image.save(self.png)
        self.original = image
        self.addCleanup(image.close)
        self.root = ET.Element('TextureAtlas', {'imagePath': 'atlas.png'})
        for index, x in enumerate((20, 0, 10, 0)):
            attributes = {'name': f'frame{index}', 'x': str(x), 'y': '0', 'width': '8', 'height': '8'}
            if index in (0, 2):
                attributes.update(frameX='-2', frameY='-3', frameWidth='12', frameHeight='14', rotated='true', flipX='true')
            ET.SubElement(self.root, 'SubTexture', attributes)
        ET.ElementTree(self.root).write(self.png.with_suffix('.xml'))
        self.output = self.base / 'output'

    def test_lossless_metadata_order_and_page_bounds(self):
        prepare(self.source, self.output, 12)
        manifest = json.loads((self.output / 'atlas.android.json').read_text())
        self.assertEqual(manifest['frames'], [frame.get('name') for frame in self.root])
        self.assertEqual(len(manifest['pages']), 3)  # repeated rectangles share pixels
        found = {}
        for page in manifest['pages']:
            with Image.open(self.output / f'{page}.png') as image:
                self.assertLessEqual(max(image.size), 12)
                for frame in ET.parse(self.output / f'{page}.xml').getroot():
                    attributes = dict(frame.attrib)
                    x, y = int(attributes.pop('x')), int(attributes.pop('y'))
                    width, height = int(attributes['width']), int(attributes['height'])
                    found[frame.get('name')] = (attributes, image.crop((x, y, x + width, y + height)).tobytes())
                    self.assertEqual(image.getpixel((x - 1, y)), image.getpixel((x, y)))
        for frame in self.root:
            attributes = dict(frame.attrib)
            x, y = int(attributes.pop('x')), int(attributes.pop('y'))
            expected = self.original.crop((x, y, x + int(attributes['width']), y + int(attributes['height']))).tobytes()
            self.assertEqual(found[frame.get('name')], (attributes, expected))
        self.assertFalse((self.output / 'atlas.png').exists())
        self.assertFalse((self.output / 'atlas.xml').exists())
        self.assertTrue(self.png.exists())

    def test_repeat_generation_is_deterministic_and_removes_stale_files(self):
        prepare(self.source, self.output, 12)
        def hashes():
            return {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in self.output.iterdir()}
        first = hashes()
        (self.output / 'stale.png').write_bytes(b'stale')
        prepare(self.source, self.output, 12)
        self.assertEqual(first, hashes())

    def test_rejects_oversized_frame_instead_of_rescaling(self):
        with self.assertRaisesRegex(ValueError, 'Frame too large'):
            repack_atlas(self.png, self.output / 'atlas.png', 8)

    def test_rejects_non_atlas_oversized_image(self):
        self.png.with_suffix('.xml').unlink()
        with self.assertRaisesRegex(ValueError, 'no Sparrow XML'):
            prepare(self.source, self.output, 12)
        self.assertFalse(self.output.exists())

    def test_does_not_remove_unmarked_output_or_source(self):
        self.output.mkdir()
        with self.assertRaisesRegex(ValueError, 'unmarked'):
            prepare(self.source, self.output, 12)
        with self.assertRaisesRegex(ValueError, 'separate siblings'):
            prepare(self.source, self.source, 12)

    def test_small_images_and_other_files_are_copied_unchanged(self):
        (self.source / 'song.ogg').write_bytes(b'audio')
        prepare(self.source, self.output, 32)
        for source in self.source.iterdir():
            self.assertEqual((self.output / source.name).read_bytes(), source.read_bytes())


if __name__ == '__main__':
    unittest.main()
