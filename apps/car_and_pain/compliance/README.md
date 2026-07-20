# Store compliance & privacy declarations

**Launch-blocking.** These artifacts back Car and Pain's offline-first,
account-free, no-telemetry promise at both stores. They must stay in sync with
the code — a declaration mismatch is a store-rejection/removal risk.

| Artifact | Purpose |
| --- | --- |
| `ios/Runner/PrivacyInfo.xcprivacy` | iOS privacy manifest: no tracking, no collected data, required-reason APIs only. |
| `data-safety.md` | Source of truth for the Play **Data safety** form (no collection, no sharing, no tracking). |
| `privacy-nutrition-label.md` | Source of truth for the App Store **privacy nutrition label** (Data Not Collected). |
| `THIRD_PARTY_NOTICES.md` | OSS attribution for every kept runtime dependency + bundled fonts. |

## Enforced, not promised

- The prod/release Android manifest **omits `INTERNET`** (the OS enforces the
  offline claim); `INTERNET` lives only in the debug/profile manifests for dev
  tooling.
- A CI **no-telemetry lockfile scan** fails the build if any analytics/crash SDK
  appears in `pubspec.lock`.
- A CI **permission check** fails the build if `INTERNET` is reintroduced into
  the main manifest.

See `docs/flutter/17-store-compliance-licensing.md` for the full checklist
(RTL screenshots, six-language listings, font-license attribution).
