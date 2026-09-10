# RideGuard AI

**Choose safer. Ride connected.**

Native SwiftUI iPhone/iPad development preview with a watchOS companion, a Live Activity extension, an independently tested Swift domain package, and a tested local Supabase schema draft. Built from both supplied product briefs.

This is **not a production-ready or App Store-ready release**. It starts in a visibly labelled demo mode. No cloud service has been deployed; live sharing, automatic contact delivery, production risk feeds and subscriptions are not enabled for sale.

## Run on a Mac

Use Xcode 26 or newer with iOS and watchOS simulator runtimes. The UI targets iOS 17+, the Watch app watchOS 10+; this build enables real cycling requests on iOS 26+.

```sh
brew install xcodegen
bash scripts/build-macos.sh
open RideGuard.xcodeproj
```

The script prepares assets, generates the Xcode project, runs the core tests and builds the iPhone and Watch targets without signing. In Xcode select the **RideGuard** scheme and an iPhone simulator. For hardware, select your signing team for all three targets and use your own bundle identifiers consistently.

First launch shows six-page onboarding. Explore the labelled London demo; compare a route, inspect its factors, prepare a ride, try a report, mark yourself okay, end the ride and review its summary. To request a real cycling route, end any demo ride, turn off **You → Explore with demo data**, then use **Explore → Use my location** and enter a destination. MapKit coverage errors are shown. Real routes do not receive invented risk scores.

## What is implemented

- Native tabs for Explore, Reports, Ride, Insights and You, with adaptive content widths, dark colours, native accessibility controls and Dynamic Type.
- MapKit destination search, alternative cycling route requests, route selection, map geometry, comparison and explainable factor sheets.
- Risk engine with provenance, freshness, coverage, missing factors, demo isolation and explicit insufficient-data states. It is an experimental heuristic, not a calibrated accident predictor.
- Twelve hazard categories, severity, timestamp, current coordinate and available course; optional photo picker, bounded photo storage without EXIF metadata; local confirmations and report ageing.
- SwiftData local persistence, guest use, saved destinations, trusted contacts, export with device authentication, and deletion.
- Ride lifecycle, recorded distance from accepted location updates, background location during explicitly started rides, arrival prompt, configurable local overdue reminder, short audio alerts and post-ride comfort feedback.
- Five iPhone App Intents: report hazard, what’s ahead, ETA, I’m okay and confirmed end ride. No always-listening microphone, recorded transcripts or remote LLM.
- WatchConnectivity status, stale-update indicators, acknowledged Watch quick reports/okay/end actions, and two Watch shortcuts.
- ActivityKit / Dynamic Island source, stale state, end cleanup; StoreKit 2 product loading, verified entitlements, transaction listening and restore logic. Purchase service exists but the preview deliberately offers no sale of unfinished cloud features.
- Fifteen-table Supabase schema draft with RLS, grants, private token storage, cross-owner foreign-key constraints and server-controlled delivery/entitlement records.
- Eight labelled humanised campaign concepts, generated onboarding artwork and app icon. See [Marketing](Marketing/README.md).

## Verification performed on Windows

```powershell
swift test --scratch-path C:\Users\User\.codex\rideguard-build
cd backend
npm ci --ignore-scripts
npm test
```

**15 Swift tests passed. 15 PostgreSQL schema checks passed.** iPhone Swift files passed syntax parsing. The Windows SwiftPM default path failed on an I/O error; the scratch path above worked. Swift emitted a nonfatal debug-symlink warning.

Apple SDK type checking, XcodeGen execution, simulator rendering, hardware background behaviour, Siri metadata extraction, StoreKit sandbox purchases and actual Watch pairing have **not** been verified here. A macOS CI workflow and local build script are included, but have not run on a Mac in this session. See [verification](docs/VERIFICATION.md).

## Architecture

| Directory | Responsibility |
| --- | --- |
| `Sources/RideGuardCore` | Codable domain models, deterministic scoring, ride state, report relevance, voice classification, route geometry and alert cooldown |
| `App` | SwiftUI screens, shared observable store, SwiftData repository, native adapters and intents |
| `Watch` | Lightweight companion and acknowledged iPhone commands |
| `Shared`, `Widgets` | Activity attributes and Live Activity presentation |
| `backend` | Reviewable schema draft and isolated PGlite access-control tests; no hosted deployment |
| `Marketing` | Generated campaign concepts and production capture plan |
| `docs` | Feature status, security/data contracts, sources and verification |

The `CyclingSafetyAIService` name follows the brief; this implementation is deliberately a structured template explainer. It does not call an AI model or invent evidence. `HazardVoiceClassifier` is a conservative tested keyword classifier, not a claimed probabilistic language model; App Intents use explicit categories.

## Required before production

Connect verified/licensed cycling datasets and validate the scoring model for the launch region. Implement authenticated backend endpoints, Sign in with Apple, moderated community publication, consented expiring live links, revocation, push delivery receipts and overdue escalation. Configure production StoreKit products and legal/support URLs. Complete iPhone/iPad/Watch device, accessibility, battery, offline, location and privacy tests. Capture actual UI screenshots at Apple’s required dimensions. The detailed status matrix is in [FEATURE_STATUS.md](docs/FEATURE_STATUS.md).
