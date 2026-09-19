"""Start the screenshot iPhone while the native targets compile."""
import json
import subprocess

devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '--json']))['devices']
phone = next(d for group in devices.values() for d in group if d.get('isAvailable') and 'iPhone' in d['name'] and 'Pro Max' in d['name'])
if phone['state'] != 'Booted':
    subprocess.run(['xcrun', 'simctl', 'boot', phone['udid']], check=True, timeout=120)
print('Warming ' + phone['name'])
