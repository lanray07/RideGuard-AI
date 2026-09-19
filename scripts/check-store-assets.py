"""Validate listing limits, locale coverage and real screenshot dimensions."""
import json
from pathlib import Path
import struct
from PIL import Image, ImageStat

ROOT = Path(__file__).resolve().parents[1]
listing = json.loads((ROOT / 'fastlane/listing.json').read_text(encoding='utf-8'))
assert set(listing) == {'en-GB', 'fr-FR', 'es-ES', 'de-DE'}
limits = {'subtitle': 30, 'promotional_text': 170, 'keywords': 100, 'description': 4000}
for locale, fields in listing.items():
    for name, limit in limits.items():
        assert 0 < len(fields[name]) <= limit, f'{locale}: {name} exceeds {limit}'
    assert len(fields['keywords'].encode('utf-8')) <= 100, f'{locale}: keywords exceed 100 UTF-8 bytes'
    folder = ROOT / 'fastlane/screenshots' / locale
    sizes = []
    for path in folder.glob('*.png'):
        data = path.read_bytes()
        assert data[:8] == b'\x89PNG\r\n\x1a\n', f'Invalid PNG: {path}'
        sizes.append(struct.unpack('>II', data[16:24]))
        with Image.open(path) as frame:
            if frame.width >= 1000:
                content = frame.convert('RGB').crop((0, 200, frame.width, frame.height - 150))
                assert sum(ImageStat.Stat(content).var) / 3 >= 100, f'Blank screenshot: {path}'
    assert len(sizes) == 17, f'{locale}: expected exactly 17 screenshots'
    assert sizes.count((1320, 2868)) == 8, f'{locale}: expected eight iPhone screenshots'
    assert sizes.count((2064, 2752)) == 8, f'{locale}: expected eight iPad screenshots'
    assert sum(s in [(410, 502), (422, 514)] for s in sizes) == 1, f'{locale}: expected one Watch Ultra screenshot'
print('Four locales validated: listing limits and 68 screenshots.')
