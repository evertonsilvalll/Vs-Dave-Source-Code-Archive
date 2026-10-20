#!/usr/bin/env python3
"""Copy desktop assets and losslessly split oversized Sparrow atlases for Android.

Requires Pillow. Run from the project root; generated android-assets is disposable.
Frame order and every XML attribute except atlas coordinates are preserved.
"""

import argparse
import copy
import json
from pathlib import Path
import shutil
import xml.etree.ElementTree as ET

from PIL import Image


def repack_atlas(png, destination, max_size=4096):
    """Write bounded PNG/XML pages and a frame-order manifest; return page count."""
    root = ET.parse(png.with_suffix('.xml')).getroot()
    if root.tag != 'TextureAtlas':
        raise ValueError(f'Not a Sparrow atlas: {png}')
    frames = list(root)
    if not frames or any(frame.tag != 'SubTexture' for frame in frames):
        raise ValueError(f'Unsupported or empty atlas: {png}')
    names = [frame.attrib['name'] for frame in frames]
    if len(set(names)) != len(names):
        raise ValueError(f'Duplicate frame names: {png}')
    with Image.open(png) as source:
        # Normalize palette/RGB sources without changing rendered RGBA pixels.
        pixels = source.convert('RGBA')
    rectangles = {}
    for frame in frames:
        rect = tuple(int(frame.attrib[key]) for key in ('x', 'y', 'width', 'height'))
        x, y, width, height = rect
        if min(x, y) < 0 or min(width, height) <= 0 or x + width > pixels.width or y + height > pixels.height:
            raise ValueError(f'Frame outside image: {png}: {frame.attrib["name"]}')
        if max(width, height) + 2 > max_size:
            raise ValueError(f'Frame too large for {max_size}px page: {png}: {frame.attrib["name"]}')
        rectangles.setdefault(rect, []).append(frame)

    # Stable first-fit shelves, deduplicating aliases of the same source rectangle.
    pages = []
    placements = {}
    for rect in sorted(rectangles, key=lambda r: (-r[3], -r[2], r[1], r[0])):
        width, height = rect[2] + 2, rect[3] + 2
        placement = None
        for page_index, page in enumerate(pages):
            for shelf in page['shelves']:
                if height <= shelf['height'] and shelf['x'] + width <= max_size:
                    placement = (page_index, shelf['x'], shelf['y'])
                    shelf['x'] += width
                    break
            if placement is not None:
                break
            if page['height'] + height <= max_size:
                placement = (page_index, 0, page['height'])
                page['shelves'].append({'x': width, 'y': page['height'], 'height': height})
                page['height'] += height
                break
        if placement is None:
            placement = (len(pages), 0, 0)
            pages.append({'shelves': [{'x': width, 'y': 0, 'height': height}], 'height': height})
        placements[rect] = (placement[0], placement[1] + 1, placement[2] + 1)

    destination.parent.mkdir(parents=True, exist_ok=True)
    page_files = []
    for page_index, page in enumerate(pages):
        page_name = f'{destination.stem}.android-{page_index}'
        page_files.append(page_name)
        canvas = Image.new('RGBA', (max(s['x'] for s in page['shelves']), page['height']))
        page_root = ET.Element('TextureAtlas', dict(root.attrib, imagePath=f'{page_name}.png'))
        for rect, (index, x, y) in placements.items():
            if index != page_index:
                continue
            sx, sy, width, height = rect
            crop = pixels.crop((sx, sy, sx + width, sy + height))
            canvas.paste(crop, (x, y))
            # One pixel of extruded padding avoids sampling neighboring frames.
            canvas.paste(crop.crop((0, 0, width, 1)), (x, y - 1))
            canvas.paste(crop.crop((0, height - 1, width, height)), (x, y + height))
            canvas.paste(crop.crop((0, 0, 1, height)), (x - 1, y))
            canvas.paste(crop.crop((width - 1, 0, width, height)), (x + width, y))
            for dx, dy, cx, cy in ((-1, -1, 0, 0), (width, -1, width - 1, 0),
                                  (-1, height, 0, height - 1), (width, height, width - 1, height - 1)):
                canvas.putpixel((x + dx, y + dy), crop.getpixel((cx, cy)))
        # Keep each page's XML in original frame order too.
        for frame in frames:
            rect = tuple(int(frame.attrib[key]) for key in ('x', 'y', 'width', 'height'))
            index, x, y = placements[rect]
            if index == page_index:
                copied = copy.deepcopy(frame)
                copied.set('x', str(x))
                copied.set('y', str(y))
                page_root.append(copied)
        canvas.save(destination.parent / f'{page_name}.png')
        canvas.close()
        ET.ElementTree(page_root).write(destination.parent / f'{page_name}.xml', encoding='utf-8', xml_declaration=True)
    pixels.close()
    manifest = {'version': 1, 'pages': page_files, 'frames': names}
    destination.with_suffix('.android.json').write_text(json.dumps(manifest, separators=(',', ':')) + '\n')
    destination.unlink(missing_ok=True)
    destination.with_suffix('.xml').unlink(missing_ok=True)
    return len(pages)


def prepare(source, destination, max_size=4096):
    source, destination = source.resolve(), destination.resolve()
    if source == destination or source in destination.parents or destination in source.parents:
        raise ValueError('Source and output directories must be separate siblings')
    if max_size < 4 or max_size > 4096:
        raise ValueError('Android page limit must be between 4 and 4096 pixels')
    oversized = []
    for png in sorted(source.rglob('*.png')):
        with Image.open(png) as image:
            if max(image.size) > max_size:
                if not png.with_suffix('.xml').is_file():
                    raise ValueError(f'Oversized image has no Sparrow XML: {png}')
                oversized.append(png)
    # Only replace directories marked as generated by this tool.
    marker = destination / '.android-assets-generated'
    if destination.exists():
        if not marker.is_file():
            raise ValueError(f'Refusing to replace unmarked output directory: {destination}')
        shutil.rmtree(destination)
    shutil.copytree(source, destination)
    marker.write_text('Generated by tools/prepare_android_assets.py\n')
    for png in oversized:
        relative = png.relative_to(source)
        pages = repack_atlas(png, destination / relative, max_size)
        print(f'{relative}: {pages} pages, maximum {max_size}px')
    print(f'Prepared {len(oversized)} oversized atlases in {destination.name}')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, default=Path('assets'))
    parser.add_argument('--output', type=Path, default=Path('android-assets'))
    parser.add_argument('--max-size', type=int, default=4096)
    args = parser.parse_args()
    prepare(args.source, args.output, args.max_size)
