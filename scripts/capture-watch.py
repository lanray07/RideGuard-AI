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
run('xcrun', 'simctl', 'launch', udid, 'com.RideGuardAI.app.watchkitapp')
time.sleep(12)
output = Path('build/screenshots/Watch')
output.mkdir(parents=True, exist_ok=True)
run('xcrun', 'simctl', 'io', udid, 'screenshot', str(output / 'Watch-01-companion.png'))
run('xcrun', 'simctl', 'shutdown', udid)
