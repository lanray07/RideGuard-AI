# Backend handoff contract

The SQL draft is tested locally but is neither a hosted service nor a migration. No migration identifier was invented. On a configured development instance use the installed Supabase CLI help, iterate locally, run advisors, generate the reviewed migration with the CLI, and verify migration history. Do not apply directly to a live project.

## Access model

Private rides, segments, raw reports, preferences and contacts belong to the authenticated subject. Composite foreign keys include `user_id`, preventing an attacker from attaching a location/check-in to another rider’s parent record. Every exposed application table enables RLS with explicit grants. Delivery state, entitlements, score provenance and live session lifecycle are server-controlled. Never use editable user metadata to authorize.

Community observations expose no author IDs or ride IDs. A private mapping ties moderated observations to raw reports for deletion. The server deletion flow MUST remove associated published observations before deleting raw reports/users, then revoke sessions/tokens and remove uploaded photos; merely relying on the raw FK cascade leaves anonymised publication rows behind. Automatic user/client deletion of published data is not yet implemented.

## Endpoints to implement

| Endpoint | Required behaviour |
| --- | --- |
| `POST /v1/auth/apple` | Verify Apple signature/audience/issuer/nonce; exchange for scoped session; store refresh token in Keychain, never in logs |
| `POST /v1/rides/{id}/share` | Authenticate current nonrevoked session, check ride ownership, explicit per-contact/location consent and active ride; issue random 256-bit token |
| `POST /v1/shares/resolve` | Receive token in request body, compare SHA-256 digest, verify expiry/revocation/ride status on every read; return only destination/status/ETA/last update and consented location |
| `DELETE /v1/rides/{id}/share` | Owner-only atomic revocation; subsequent reads return unavailable; end ride revokes all tokens |
| `POST /v1/rides/{id}/check-in` | Verify ride/contact composite ownership and consent; idempotency key; queue delivery; do not mark sent/delivered before provider evidence |
| `POST /v1/reports/publish` | Validate category/time/location/source, rate limit, photo redaction and moderation; store private mapping; publish approximate road observation only |
| `POST /v1/reports/{id}/confirmation` | One verdict per user; server timestamp; anti-abuse; counts derived from verified unique submissions |
| `POST /v1/storekit/notification` | Verify Apple signed transaction notification; idempotent entitlement update; ignore client assertions of Pro access |
| `DELETE /v1/account` | Revoke sessions and tokens first, delete observations/photos/private records, delete identity; documented backup retention |

Never ship a service-role key in either app. Scope server credentials, redact coordinates/tokens from access logs, apply `Cache-Control: no-store` and `Referrer-Policy: no-referrer` to live sharing, omit third-party scripts, use short expiries and hard rate limits. Keep an unguessable share token in a URL fragment only long enough for the first-party page to send it in a POST body; never permanent path/query URLs.

## Overdue worker

A server job evaluates the persisted expected arrival and consented grace window. First notify the rider, allow acknowledgement or more time, then notify only the configured contact after the additional delay. Use row locking and unique idempotency keys to handle repeated job deliveries. Cancel pending work on end/arrival/revocation. Offline devices do not prove an accident. Message wording: “This ride has not yet received a completed check-in.” Never claim crash detection.

Retention target for future sharing is the minimum necessary live location window, then deletion at ride end/expiry according to the published policy. User history retention is separately controlled. Encrypt contact payloads using managed envelope keys; configure encrypted managed database storage and backups. Validate all of this on the deployment before enabling app switches.

## Data providers

MapKit supplies current route geometry/time, not a complete safety dataset. Each new provider must declare region, licence, attribution, update cadence, observed time, expiry, spatial coverage and supported factor semantics. Document missing values, do not impute collision/lighting/weather claims, and separate subjective comfort from measured infrastructure. Route ranking must compare compatible evidence sets before describing one option as lower risk.
