#!/usr/bin/env python3
"""Compare every pixel of the fixture imported by the real native Photos picker."""
import hashlib
import json
import pathlib
import sys

root, output = map(pathlib.Path, sys.argv[1:3])
pages = list(root.glob('*/page.json'))
assert len(pages) == 1, 'Expected the actual Photos-imported test document'
page = json.loads(pages[0].read_text())
assert (page['width'], page['height']) == (800, 15000)
directory = pages[0].parent
raw = directory / page['raw']
assert raw.stat().st_size == 48_000_000
digest = hashlib.sha256()
with raw.open('rb') as stream:
    for row in range(15000):
        pixels = stream.read(800 * 4)
        shade = 240 - row % 40
        expected = bytes((shade, shade, shade, 255)) * 800
        assert pixels == expected, f'Photos import changed source pixels on row {row}'
        digest.update(pixels)
    assert not stream.read(1)
report = {'width': 800, 'height': 15000, 'rgba_bytes_compared': 48_000_000,
          'all_source_pixels_unchanged': True, 'rgba_sha256': digest.hexdigest(),
          'source_extension': pathlib.Path(page['source']).suffix,
          'method': 'Real PHPicker UI selection; compare application disk RGBA to seeded Photos fixture'}
output.write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report))
