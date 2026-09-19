"""Capture the real Watch companion at an App Store supported size."""
import json
from pathlib import Path
import subprocess
import time

def run(*args):
    return subprocess.run(args, check=True, timeout=240)

devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
available = [d for group in devices.values() for d in group if d.get('isAvailable')]
device = next((d for d in available if 'Apple Watch' in d['name'] and 'Ultra' in d['name']), None)
if not device:
    raise SystemExit('No Apple Watch Ultra simulator installed')
apps = list(Path('build/DerivedData/Build/Products').glob('Debug-watchsimulator/RideGuardWatch.app'))
if not apps:
    raise SystemExit('Built Watch app not found')
udid = device['udid']
print('Capturing ' + device['name'], flush=True)
run('xcrun', 'simctl', 'boot', udid)
run('xcrun', 'simctl', 'bootstatus', udid, '-b')
run('xcrun', 'simctl', 'install', udid, str(apps[0]))
for language, locale, store_locale in [('en', 'en_GB', 'en-GB'), ('fr', 'fr_FR', 'fr-FR'), ('es', 'es_ES', 'es-ES'), ('de', 'de_DE', 'de-DE')]:
    run('xcrun', 'simctl', 'launch', '--terminate-running-process', udid, 'com.RideGuardAI.app.watchkitapp',
        '-AppleLanguages', f'({language})', '-AppleLocale', locale)
    time.sleep(12)
    output = Path('build/screenshots') / store_locale / 'Watch'
    output.mkdir(parents=True, exist_ok=True)
    run('xcrun', 'simctl', 'io', udid, 'screenshot', str(output / 'Watch-01-companion.png'))
run('xcrun', 'simctl', 'shutdown', udid)
