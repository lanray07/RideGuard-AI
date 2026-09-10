# Verification record

Environment: Windows, Swift 6.3.1; no Xcode, Apple SDK, iOS simulator or paired Apple Watch available.

## Executed

1. `swift test --scratch-path C:\Users\User\.codex\rideguard-build`: **15 tests, zero failures**. Covers unknown vs zero risk; minimum evidence; stale, future, invalid and source-less factors; duplicate evidence; demo isolation; weighted coverage; coordinate validation; overdue/okay; terminal completion; arrival; ambiguous/negated voice text; cooldown/deduplication; hazards behind/off route; relevance decay; single voter; Codable round trip.
2. `npm test` inside `backend`: **15 checks passed** using pinned PGlite 0.5.8. Executes the SQL against isolated PostgreSQL with mock Supabase roles/`auth.uid()`. Verifies owner CRUD, other-user and anonymous denial, composite foreign keys, server-only entitlements/publication/sharing, consent constraint, private token denial and RLS on all application tables.
3. `swiftc -frontend -parse` on iPhone source: passed. This does **not** import/type-check SwiftUI, MapKit, App Intents or other Apple frameworks.
4. Asset catalog JSON validation and source image inspection: passed. The generated icon master is normalized to 1024×1024 by the Mac build script and Xcode prebuild step.

## Still required on Apple platforms

- Execute `scripts/build-macos.sh`; resolve SDK type-check or metadata extraction issues. Inspect generated target embedding and signing for Watch and activity extension.
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
