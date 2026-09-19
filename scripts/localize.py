"""Maintain bundled, offline translations. Run --extract, --translate, then --check.

Static app-owned strings are seeded here; Xcode's compiler additionally extracts
SwiftUI interpolation keys during a native build. Existing translations survive
updates. Overrides are reviewed copy and always take precedence over machine text.
"""
import argparse
from collections import Counter
import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Localization/Localizable.xcstrings'
LANGUAGES = ('fr', 'es', 'de')
FORMAT = re.compile(r'%(?:\d+\$)?(?:[-+0 #]*)(?:\d+)?(?:\.\d+)?(?:ll|l|h)?[@diufFeEgGosxX]')

def read(path, fallback):
    return json.loads(path.read_text(encoding='utf-8')) if path.exists() else fallback

def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

def static_strings(source):
    # Swift interpolation is deliberately left to the compiler, not guessed here.
    for match in re.finditer(r'"((?:[^"\\\n]|\\.)*)"', source):
        raw = match.group(1)
        if '\\(' in raw or not re.search(r'[A-Za-z]', raw):
            continue
        if re.fullmatch(r'[a-zA-Z0-9_.:/#%+\-]+', raw) and not raw[0].isupper():
            continue
        if raw.startswith(('http', 'com.', 'NS', 'SIMCTL_', 'RIDEGUARD_')):
            continue
        try:
            yield json.loads('"' + raw + '"')
        except json.JSONDecodeError:
            continue

def extract(catalog):
    for directory in ('App', 'Watch', 'Widgets', 'Sources/RideGuardCore'):
        for path in (ROOT / directory).rglob('*.swift'):
            for key in static_strings(path.read_text(encoding='utf-8')):
                catalog['strings'].setdefault(key, {'extractionState': 'manual'})

def placeholders(value):
    return Counter(FORMAT.findall(value))

def translate(catalog):
    import argostranslate.package
    import argostranslate.translate
    overrides = read(ROOT / 'Localization/overrides.json', {})
    argostranslate.package.update_package_index()
    packages = argostranslate.package.get_available_packages()
    installed = argostranslate.package.get_installed_packages()
    for lang in LANGUAGES:
        if not any(p.from_code == 'en' and p.to_code == lang for p in installed):
            package = next(p for p in packages if p.from_code == 'en' and p.to_code == lang)
            argostranslate.package.install_from_path(package.download())
        for number, (key, entry) in enumerate(catalog['strings'].items(), 1):
            if not key:
                continue
            localizations = entry.setdefault('localizations', {})
            override = overrides.get(key, {}).get(lang)
            if override is not None:
                value = override
            elif lang in localizations:
                continue
            else:
                # Translate segments separately, so format specifiers cannot be
                # changed, duplicated or omitted by the translation model.
                pieces = re.split('(' + FORMAT.pattern + ')', key)
                def segment(piece):
                    if FORMAT.fullmatch(piece) or not piece.strip():
                        return piece
                    leading = piece[:len(piece) - len(piece.lstrip())]
                    trailing = piece[len(piece.rstrip()):]
                    return leading + argostranslate.translate.translate(piece.strip(), 'en', lang) + trailing
                value = ''.join(segment(piece) for piece in pieces)
            if placeholders(key) != placeholders(value):
                raise ValueError(f'Placeholder mismatch: {lang}: {key}')
            localizations[lang] = {'stringUnit': {'state': 'translated', 'value': value}}
            if number % 50 == 0:
                write(CATALOG, catalog)
                print(f'{lang}: {number}/{len(catalog["strings"])}', flush=True)
        write(CATALOG, catalog)

def check(catalog):
    errors = []
    for key, entry in catalog['strings'].items():
        if not key or entry.get('shouldTranslate') is False:
            continue
        for lang in LANGUAGES:
            unit = entry.get('localizations', {}).get(lang, {}).get('stringUnit', {})
            if not unit.get('value') or placeholders(key) != placeholders(unit['value']):
                errors.append(f'{lang}: {key}')
    if errors:
        raise SystemExit('Missing translations or invalid placeholders:\n' + '\n'.join(errors))
    print(f'Validated {len(catalog["strings"])} keys in {", ".join(LANGUAGES)}.')

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for action in ('extract', 'translate', 'check'):
        parser.add_argument('--' + action, action='store_true')
    args = parser.parse_args()
    catalog = read(CATALOG, {'sourceLanguage': 'en', 'strings': {}, 'version': '1.0'})
    if args.extract:
        extract(catalog)
        write(CATALOG, catalog)
    if args.translate:
        translate(catalog)
    if args.check:
        check(catalog)
