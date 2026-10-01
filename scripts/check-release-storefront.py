"""Reject release builds that expose an unconfigured purchase experience."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
swift_files = list((ROOT / "App").rglob("*.swift"))
forbidden = {
    "import StoreKit": "StoreKit framework import",
    "PaywallView": "purchase screen",
    "SubscriptionService": "subscription service",
    ".purchase(": "purchase call",
    "Product.products(": "StoreKit product lookup",
    "Restore purchases": "restore-purchases control",
}

violations = []
for path in swift_files:
    source = path.read_text(encoding="utf-8")
    for token, description in forbidden.items():
        if token in source:
            violations.append(f"{path.relative_to(ROOT)}: {description}")

if violations:
    raise SystemExit("Unconfigured purchase surface found:\n" + "\n".join(violations))

print("Release storefront check passed: no purchase UI or StoreKit path is exposed.")
