"""Check the built bundles contain the requested languages and reviewed copy."""
import json
from pathlib import Path
import plistlib
import subprocess

root = Path(__file__).resolve().parents[1]
products = root / 'build/DerivedData/Build/Products'
overrides = json.loads((root / 'Localization/overrides.json').read_text(encoding='utf-8'))
for relative in ['Debug-iphonesimulator/RideGuard.app',
                 'Debug-watchsimulator/RideGuardWatch.app',
                 'Debug-iphonesimulator/RideGuardActivity.appex']:
    bundle = products / relative
    with (bundle / 'Info.plist').open('rb') as stream:
        info = plistlib.load(stream)
    assert info['CFBundleDevelopmentRegion'] == 'en', relative
    for language in ['fr', 'es', 'de']:
        path = bundle / (language + '.lproj') / 'Localizable.strings'
        strings = json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))
        for key in ['Plan your cycling route.', 'DEMO · SAMPLE DATA', 'Waiting for iPhone']:
            assert strings[key] == overrides[key][language], (relative, language, key)
    print('Verified language bundles: ' + relative)
