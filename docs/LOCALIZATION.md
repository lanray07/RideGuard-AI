# Localization and store assets

RideGuard targets English, French, Spanish and German. Apple selects the bundled
language using the device's preferred languages (or its per-app language setting).
Unsupported languages fall back to English. No runtime translation service receives
locations, contacts, reports or other user content.

`Localization/Localizable.xcstrings` is shared by the iPhone/iPad, Watch and Live
Activity targets. Xcode emits SwiftUI localization data with
`SWIFT_EMIT_LOC_STRINGS`. `L10n.text` handles app-owned dynamic keys; `L10n.format`
handles parameterized messages. User-supplied names, addresses and report text
must remain verbatim. Permission descriptions have separate InfoPlist resources.

## Updating copy

1. Run `python scripts/localize.py --extract` after adding app-owned text.
2. Use explicit `L10n.format` keys for new parameterized messages. If adding native
   SwiftUI interpolation, export localizations in Xcode to obtain its canonical
   format key and add that key to the catalog; the static extractor deliberately
   does not guess interpolation types.
3. Install `argostranslate==1.11.0` in an isolated Python environment and run
   `python scripts/localize.py --translate --check`, or run the manual
   **Refresh offline translations** GitHub workflow. The workflow returns an
   artifact and does not silently commit or publish machine translations.
4. Review changed translations, especially safety wording, and put corrections in
   `Localization/overrides.json` or the four-column `Localization/reviewed-copy.tsv`.
   Existing translations are retained between runs. Changed format tokens stop
   generation and require an explicit reviewed replacement.
5. Build again and inspect real simulator screenshots in each language for missing
   translations, clipping and misleading wording before uploading or submitting.

Argos downloads English-to-French, Spanish and German models, then translates
locally. Format placeholders are preserved and checked. Machine translation is a
drafting aid; automated completeness checks do not certify linguistic quality.

## App Store listing

`fastlane/listing.json` contains reviewed descriptions, subtitles, promotional copy
and keyword fields for en-GB, fr-FR, es-ES and de-DE. Natural cycling terms also
appear in the actual screen headings. No ranking claim is made about screenshot
text. Listing copy must describe the selected binary's available features.

The native build captures eight iPhone and eight iPad screens plus a genuine
idle Watch companion screen per language. Screens show labelled demonstration
data where applicable. Uploads replace the screenshots from the local archive;
they never submit the version for App Review automatically.
