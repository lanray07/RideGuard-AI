"""Capture actual built app screens from installed GitHub macOS simulators."""
import json
import os
from pathlib import Path
import subprocess
import time

def run(*args, **kw):
    return subprocess.run(args, check=True, text=True, **kw)

devices = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "--json"]))["devices"]
available = [d for group in devices.values() for d in group if d.get("isAvailable")]
app = Path("build/DerivedData/Build/Products/Debug-iphonesimulator/RideGuard.app")
assert app.is_dir(), "Built iPhone app is required"
screens = ["explore", "compare", "explain", "reports", "ride", "voice", "privacy", "onboarding"]
for family, predicate in [
    ("iPhone", lambda n: "iPhone" in n and "Pro Max" in n),
    ("iPad", lambda n: "iPad Pro" in n and "13-inch" in n),
]:
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
            env = dict(os.environ, SIMCTL_CHILD_RIDEGUARD_SCREENSHOT_SCREEN=screen)
            run("xcrun", "simctl", "launch", "--terminate-running-process", udid, "com.RideGuardAI.app",
                '-AppleLanguages', f'({language})', '-AppleLocale', locale, env=env)
            time.sleep(8 if index == 1 else 3)
            run("xcrun", "simctl", "io", udid, "screenshot", str(output / f"{family}-{index:02}-{screen}.png"))
    run("xcrun", "simctl", "shutdown", udid)
