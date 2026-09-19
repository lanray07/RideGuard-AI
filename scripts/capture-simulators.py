"""Capture actual built app screens from installed GitHub macOS simulators."""
import json
import os
from pathlib import Path
import subprocess
import time
from PIL import Image, ImageStat

def run(*args, **kw):
    return subprocess.run(args, check=True, text=True, **kw)

devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))["devices"]
available = [d for group in devices.values() for d in group if d.get("isAvailable")]
app = Path("build/DerivedData/Build/Products/Debug-iphonesimulator/RideGuard.app")
assert app.is_dir(), "Built iPhone app is required"
screens = ["explore", "compare", "explain", "reports", "ride", "voice", "privacy", "onboarding"]
selected = set(filter(None, os.environ.get('CAPTURE_FILTER', '').split(',')))
for family, predicate in [
    ("iPhone", lambda n: "iPhone" in n and "Pro Max" in n),
    ("iPad", lambda n: "iPad Pro" in n and "13-inch" in n),
]:
    if selected and not any(f'/{family}/' in item for item in selected):
        continue
    device = next((d for d in available if predicate(d["name"])), None)
    if device is None:
        raise RuntimeError(f"No supported {family} simulator installed")
    udid = device["udid"]
    print(f"Capturing {family}: {device['name']}", flush=True)
    if device["state"] != "Booted": run("xcrun", "simctl", "boot", udid)
    run("xcrun", "simctl", "bootstatus", udid, "-b")
    run("xcrun", "simctl", "status_bar", udid, "override", "--time", "9:41", "--batteryState", "charged", "--batteryLevel", "100")
    run("xcrun", "simctl", "install", udid, str(app))
    for language, locale, store_locale in [('en', 'en_GB', 'en-GB'), ('fr', 'fr_FR', 'fr-FR'), ('es', 'es_ES', 'es-ES'), ('de', 'de_DE', 'de-DE')]:
        output = Path("build/screenshots") / store_locale / family
        output.mkdir(parents=True, exist_ok=True)
        for index, screen in enumerate(screens, 1):
            if selected and f'{store_locale}/{family}/{screen}' not in selected:
                continue
            env = dict(os.environ, SIMCTL_CHILD_RIDEGUARD_SCREENSHOT_SCREEN=screen)
            run("xcrun", "simctl", "launch", "--terminate-running-process", udid, "com.RideGuardAI.app",
                '-AppleLanguages', f'({language})', '-AppleLocale', locale, env=env)
            path = output / f"{family}-{index:02}-{screen}.png"
            for attempt in range(12):
                time.sleep(8 if attempt == 0 else 5)
                run("xcrun", "simctl", "io", udid, "screenshot", str(path))
                with Image.open(path) as frame:
                    content = frame.convert('RGB').crop((0, 200, frame.width, frame.height - 150))
                    variation = sum(ImageStat.Stat(content).var) / 3
                if variation >= 100:
                    break
                print(f'Waiting for rendered content: {path} (attempt {attempt + 1})', flush=True)
            else:
                raise RuntimeError(f'Blank launch frame persisted: {path}')
    run("xcrun", "simctl", "shutdown", udid)
