"""Prepare ephemeral CI signing inputs without printing credential material."""
import base64
import os
import plistlib
from pathlib import Path

for name in ("APPLE_TEAM_ID", "ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_PRIVATE_KEY"):
    if not os.environ.get(name):
        raise SystemExit(f"Required GitHub secret is missing: {name}")
key = os.environ["ASC_PRIVATE_KEY"].strip().replace("\\n", "\n")
if "-----BEGIN PRIVATE KEY-----" not in key:
    key = base64.b64decode(key).decode().strip()
if not key.startswith("-----BEGIN PRIVATE KEY-----"):
    raise SystemExit("Apple private key has an unsupported format")
temporary = Path(os.environ["RUNNER_TEMP"])
path = temporary / f"AuthKey_{os.environ['ASC_KEY_ID']}.p8"
path.write_text(key + "\n")
path.chmod(0o600)
with (temporary / "ExportOptions.plist").open("wb") as file:
    plistlib.dump({"method": "app-store-connect", "destination": "upload",
                  "teamID": os.environ["APPLE_TEAM_ID"], "signingStyle": "automatic",
                  "uploadSymbols": True, "manageAppVersionAndBuildNumber": False}, file)
print("Temporary signing inputs prepared.")
