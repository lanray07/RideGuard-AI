"""Write Xcode asset metadata without modifying generated artwork."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / "App/Assets.xcassets"

def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n", encoding="utf-8")

info = {"author": "xcode", "version": 1}
write(CATALOG / "Contents.json", {"info": info})
write(CATALOG / "CyclistHero.imageset/Contents.json", {
    "images": [{"filename": "cyclist-hero.png", "idiom": "universal"}], "info": info
})
write(CATALOG / "AppIcon.appiconset/Contents.json", {
    "images": [{"filename": "AppIcon.png", "idiom": "universal", "platform": "ios", "size": "1024x1024"}], "info": info
})
for name, light, dark in [
    ("Evergreen", "103F33", "A8D6BF"),
    ("Canvas", "F5F4EE", "111D19"),
    ("OnGreen", "FFFFFF", "102C23"),
]:
    entries = []
    for mode, hex_color in [(None, light), ("dark", dark)]:
        color = {"idiom": "universal", "color": {"color-space": "srgb", "components": {
            "red": str(int(hex_color[0:2], 16) / 255), "green": str(int(hex_color[2:4], 16) / 255),
            "blue": str(int(hex_color[4:6], 16) / 255), "alpha": "1.000"}}}
        if mode:
            color["appearances"] = [{"appearance": "luminosity", "value": mode}]
        entries.append(color)
    write(CATALOG / f"{name}.colorset/Contents.json", {"colors": entries, "info": info})
print("Asset catalog metadata created.")
