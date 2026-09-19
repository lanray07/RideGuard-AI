# Verification record

Local environment: Windows, Swift 6.3.1. Apple validation was subsequently run on GitHub's macOS 26 runner with Xcode 26.6.

## GitHub Apple platform results

### Localization update — 19 September 2026

- English, French, Spanish and German use bundled localization resources. The
  translation validator passes for 426 keys in each translated language.
- Main screenshot headings use natural cycling-route, hazard-report and voice
  shortcut terms. The four App Store descriptions describe the available local
  features and their limitations; metadata fields pass length checks.
- [Signed build 103](https://github.com/lanray07/RideGuard-AI/actions/runs/35453029397)
  archived and uploaded successfully from source commit `452f1a2`.
- [Localized native run](https://github.com/lanray07/RideGuard-AI/actions/runs/35453003291)
  passed 15 core tests and built the iPhone, Watch and Live Activity targets.
  Bundle checks confirmed French, Spanish and German resources in all three.
  The capture run produced 68 images; visual inspection identified five blank
  iPhone launch frames, which were excluded and replaced by successful
  [targeted recaptures](https://github.com/lanray07/RideGuard-AI/actions/runs/35454505913).
  All five replacements were visually inspected. The final archive contains
  eight iPhone, eight iPad and one Watch image for each of the four locales.
- [Store upload and verification](https://github.com/lanray07/RideGuard-AI/actions/runs/35455047074)
  succeeded. App Store Connect returned selected build `103`, matching review
  contact details, descriptions and keywords for all four locales, and all 68
  screenshot uploads complete. No final review submission was performed.
- App Store Connect's **Add for Review** validation succeeded on 19 September.
  The draft shows **Item Ready to Submit**, version **1.0 (103)**. The final
  **Submit for Review** button was left untouched.
- [Watch capture](https://github.com/lanray07/RideGuard-AI/actions/runs/35451365771)
  produced a genuine 422 × 514 companion screenshot. It was uploaded to the
  English App Store listing, which displayed one Watch screenshot.
- Runtime speech, physical-device background tracking and iPhone/Watch pairing
  still require the hardware checks listed below.

### Initial build

- [Apple platform run 34449589018](https://github.com/lanray07/RideGuard-AI/actions/runs/34449589018): passed core tests, iPhone simulator build, Watch simulator build and actual iPhone/iPad screen capture.
- [Signed upload 34449589975](https://github.com/lanray07/RideGuard-AI/actions/runs/34449589975): archive succeeded and App Store Connect upload succeeded for version 1.0 build 1. The archive is unsigned, then Xcode uses automatic cloud signing during App Store export. No development device registration is required.
- Sixteen original simulator screenshots are stored in `fastlane/screenshots/en-GB`: iPhone 1320 × 2868 and iPad 2064 × 2752. The capture entry point is compiled only for the simulator and opens existing app views with labelled demo data.
- Native App Intents metadata extraction compiled; one deprecated confirmation API warning remains. Runtime Siri interactions and hardware pairing still need validation.

## Executed

1. `swift test --scratch-path C:\Users\User\.codex\rideguard-build`: **15 tests, zero failures**. Covers unknown vs zero risk; minimum evidence; stale, future, invalid and source-less factors; duplicate evidence; demo isolation; weighted coverage; coordinate validation; overdue/okay; terminal completion; arrival; ambiguous/negated voice text; cooldown/deduplication; hazards behind/off route; relevance decay; single voter; Codable round trip.
2. `npm test` inside `backend`: **15 checks passed** using pinned PGlite 0.5.8. Executes the SQL against isolated PostgreSQL with mock Supabase roles/`auth.uid()`. Verifies owner CRUD, other-user and anonymous denial, composite foreign keys, server-only entitlements/publication/sharing, consent constraint, private token denial and RLS on all application tables.
3. `swiftc -frontend -parse` on iPhone source: passed. This does **not** import/type-check SwiftUI, MapKit, App Intents or other Apple frameworks.
4. Asset catalog JSON validation and source image inspection: passed. The generated icon master is normalized to 1024×1024 by the Mac build script and Xcode prebuild step.

## Still required on Apple platforms

- Inspect physical-device behaviour of the signed iPhone, embedded Watch and activity extension targets.
- iPhone small/large, iPad portrait/landscape, Watch sizes; light/dark, accessibility text sizes, VoiceOver, reduced motion, minimum touch size.
- Onboarding completion and six page flow; sample labels on every fixture; no fabricated community counts.
- Real search with location denied, restricted, approximate, expired, unavailable and network offline; cycling coverage absent; cancelling and quickly replacing searches.
- Ride start, background tracking/lock screen, force quit, restore and explicit resume, end while notification permission request is in progress; ensure no later reminder is requeued after end.
- Store persistence failures/full disk and model migrations; export cancel/auth failure/passcode fallback; delete all, individual rides/reports/photos, exported copies caveat.
- Siri parameter prompts, repeat invocations, device locked/cold process, confirmation cancellation and loss of current location. Current phone actions require an already initialized active ride; cold process restoration is not claimed.
- Audio with headphones/music/navigation interruption, voice disabled, Bluetooth changes, no overlapping Siri/synthesiser replies, priorities, cooldown and battery impact.
- Watch unreachable phone, acknowledgement lost, stale status, duplicate delivery and rapid taps. No offline queue may announce success.
- Live Activity start/update/restore/end and stale updates. No emergency status or contact delivery can be inferred.
- Sandbox subscriptions: verified/unverified, pending, cancelled, revoked, upgraded, expiry and restore; purchases remain unavailable in the preview UI.

## Hosted service verification not performed

Local schema checks do not establish deployed Supabase defaults, gateway configuration, JWT/session revocation, storage policy, encryption key management, moderation, share endpoint behaviour, notification receipt authenticity, retention jobs or account deletion. No schema was applied to a remote database.
