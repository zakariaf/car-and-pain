# 🛡️ Store Compliance, Privacy Declarations & Licensing

> Governs the launch-blocking compliance surface: the Google Play Data-Safety form and the Apple App Privacy nutrition label — both declaring **no data collection / no tracking** — the backing `PrivacyInfo.xcprivacy` and the omitted `INTERNET` permission, RTL store screenshots and six-language listings, the in-app OSS + font-license attributions screen, and the pre-submission checklist that ties every claim back to the no-telemetry posture.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** · **[Build, Tooling, Release & CI/CD](./12-build-ci-release.md)** · **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)**

## Decision

Store compliance is a set of **launch-blocking deliverables**, not a post-submission scramble. We complete the **Play Data-Safety form** and the **Apple App Privacy nutrition label** so that both declare *no data collected, no data shared, no tracking*, and we make those declarations **true by construction**: the prod flavor omits the Android `INTERNET` permission (the OS enforces the claim), ships `ios/Runner/PrivacyInfo.xcprivacy` with `NSPrivacyTracking=false` and an empty collected-data-types array, and a CI lockfile scan fails the build if any analytics/crash SDK appears. We prepare **RTL store screenshots** and **six-language listings** (fa/ar/ckb + en/de/fr) because the primary audience is Persian/Arabic/Kurdish. We ship an in-app **About → Open-Source Licenses** screen built on Flutter's `showLicensePage`/`LicenseRegistry`, extended with explicit **OFL attributions for Vazirmatn and the Noto fonts**. No new runtime packages are introduced — the mechanisms are the platform manifests plus the licenses API that already ships with Flutter.

## Why

`PrivacyInfo.xcprivacy` alone satisfies **neither** store. Apple's App Privacy label (entered in App Store Connect) and Google's Data-Safety form (entered in Play Console) are **separate, mandatory declarations**, each reviewed independently, and a mismatch between what you declare and what the binary does is a rejection/removal risk. For a no-telemetry app the winning move is to make the honest declaration also the *easy* one: if the binary literally cannot open a socket (no `INTERNET` permission) and contains no analytics SDK (CI-enforced), then "collects no data" is not a promise to audit — it is a property the OS and the toolchain guarantee.

Alternatives considered and rejected:

- **Relying on `PrivacyInfo.xcprivacy` alone** — leaves both the Apple label and the Play Data-Safety form unfilled; the app cannot be submitted.
- **LTR-only screenshots and an English-only listing** — misserves the target market and reads as a low-quality port to Persian/Arabic/Kurdish reviewers and users; RTL screenshots and localized listings matter *disproportionately* here.
- **Omitting OSS / font attributions** — the SIL Open Font License (Vazirmatn, Noto) and most package licenses (BSD/MIT/Apache-2.0) **legally require** attribution; a missing licenses screen is both a license violation and a review flag.
- **Deferring compliance to post-submission** — turns paperwork into a launch blocker under deadline pressure; treat it as day-one engineering work with CI backing.
- **Keeping `INTERNET` "just in case"** — every retained permission widens the surface you must justify on the Data-Safety form; drop it on prod so the claim is OS-enforced (relevant note from [Security, Privacy & At-Rest Encryption](./09-security-privacy.md)).

## How we do it

### 1. Android — omit `INTERNET`, declare nothing collected

The prod flavor's manifest carries **no `INTERNET` permission**, `allowBackup="false"`, and no cleartext traffic. Keep the dev flavor identical unless an explicit debugging need arises (it never should for an offline app).

```xml
<!-- android/app/src/prod/AndroidManifest.xml -->
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- NO <uses-permission android:name="android.permission.INTERNET"/> -->
    <!-- Notification / exact-alarm / boot permissions live here; see 07-notifications.md -->
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>

    <application
        android:allowBackup="false"
        android:fullBackupContent="false"
        android:usesCleartextTraffic="false"
        android:label="@string/app_name">
        <!-- ... -->
    </application>
</manifest>
```

Google Play **Data-Safety form** answers (the source-of-truth checklist we submit):

```text
Does your app collect or share any of the required user data types?      → No
Is all of the user data collected by your app encrypted in transit?      → N/A (no data leaves the device)
Do you provide a way for users to request that their data be deleted?    → Yes, in-app (secure wipe / delete-all); no server copy exists
Data types collected: (none)      Data types shared: (none)
Uses advertising ID:               No
```

> Because there is genuinely no network tier, most "in transit" questions are N/A — but you must still answer the form; it cannot be skipped. Data deletion is answered "Yes, in-app" and backed by the secure-wipe path (destroy the key + delete DB/attachments) documented in [Security, Privacy & At-Rest Encryption](./09-security-privacy.md).

### 2. iOS — `PrivacyInfo.xcprivacy` + the App Privacy label

`PrivacyInfo.xcprivacy` is **required at submission** even for a zero-tracking app. Declare no tracking, no collected data types, and any **required-reason APIs** the app (or its plugins) actually call — commonly file-timestamp and `UserDefaults` reasons pulled in transitively.

```xml
<!-- ios/Runner/PrivacyInfo.xcprivacy -->
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>NSPrivacyTracking</key>            <false/>
    <key>NSPrivacyTrackingDomains</key>     <array/>
    <key>NSPrivacyCollectedDataTypes</key>  <array/>
    <key>NSPrivacyAccessedAPITypes</key>
    <array>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryFileTimestamp</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>C617.1</string></array> <!-- files created by the app -->
        </dict>
        <dict>
            <key>NSPrivacyAccessedAPIType</key>
            <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
            <key>NSPrivacyAccessedAPITypeReasons</key>
            <array><string>CA92.1</string></array> <!-- app's own settings -->
        </dict>
    </array>
</dict>
</plist>
```

The **App Store Connect App Privacy** section is filled to match: *Data Not Collected*. Every locale in [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md) must appear in `CFBundleLocalizations` so the six languages are advertised, and any permission usage strings (`NSFaceIDUsageDescription`, notification prompts) are localized.

> Audit **transitive** plugins for their own `PrivacyInfo.xcprivacy` and required-reason declarations — `flutter_local_notifications`, `flutter_secure_storage`, `path_provider`, `local_auth`, `permission_handler` each ship one. Apple aggregates them; a missing declaration in a dependency still rejects your build.

### 3. In-app licenses screen (OSS + fonts)

Flutter already collects package licenses via `LicenseRegistry`; `showLicensePage` renders them. We add the **font OFL licenses** explicitly, because bundled font assets are not Dart packages and are otherwise invisible to the registry.

```dart
// packages/l10n/lib/src/licenses.dart  — registered once in bootstrap()
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const <String>['Vazirmatn'],
      await rootBundle.loadString('assets/fonts/Vazirmatn-OFL.txt'),
    );
    yield LicenseEntryWithLineBreaks(
      const <String>['Noto Naskh Arabic', 'Noto Sans'],
      await rootBundle.loadString('assets/fonts/Noto-OFL.txt'),
    );
  });
}
```

```dart
// In the About feature — RTL-aware, localized, no network:
AboutListTile(
  icon: const Icon(Icons.description_outlined),
  applicationName: l10n.appName,
  applicationVersion: appVersion, // x.y.z+build injected at build time
  applicationLegalese: l10n.legalese,
  child: Text(l10n.viewOpenSourceLicenses),
);
// tapping opens showLicensePage(...) which now includes Vazirmatn/Noto OFL.
```

Ship the raw OFL text (`Vazirmatn-OFL.txt`, `Noto-OFL.txt`) and any non-OFL license files as **bundled assets** so the screen renders fully offline. Do not fetch fonts at runtime — `google_fonts` is disqualified for exactly this reason (see [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)).

### 4. Store listing assets — RTL screenshots + six languages

```text
store/
  metadata/
    en/  title.txt  short_description.txt  full_description.txt
    de/  ...
    fr/  ...
    fa/  title.txt  ...   # RTL copy, native numerals in marketing text
    ar/  ...
    ckb/ ...
  screenshots/
    en/ phone_5.5/  phone_6.5/  tablet_10/    # LTR framing
    fa/ phone_5.5/  phone_6.5/  tablet_10/    # RTL framing (mirrored UI)
    ...
```

- Generate screenshots from the **real app in each locale × direction** — a mirrored garage/dashboard in Persian is the single most persuasive asset for the target market. Do not fake RTL by flipping an English screenshot.
- Localize the full listing (title, short + full description, keywords) for all six languages; keep the privacy/no-ads/buy-once claims consistent across them.
- Drive uploads with `fastlane supply` (Play) and `deliver` (App Store) so metadata + screenshots are versioned in the repo — see [Build, Tooling, Release & CI/CD](./12-build-ci-release.md).

## Rules

- **Do** answer the Play Data-Safety form and the Apple App Privacy label as *no collection / no tracking*, and keep both in sync with the binary — a declaration that outruns the code is a removal risk.
- **Do** ship `ios/Runner/PrivacyInfo.xcprivacy` with `NSPrivacyTracking=false`, an empty `NSPrivacyCollectedDataTypes`, and honest required-reason API entries; **do** audit every transitive plugin's own privacy manifest.
- **Do** omit `INTERNET` from the prod (and dev) Android manifest so the no-network claim is OS-enforced, and set `allowBackup="false"` + `usesCleartextTraffic="false"`.
- **Do** register the Vazirmatn and Noto OFL texts via `LicenseRegistry.addLicense` and expose `showLicensePage` from an About screen that works fully offline.
- **Do** produce RTL screenshots and all six localized listings; **don't** ship an English-only listing or LTR-only screenshots.
- **Don't** add any analytics, crash-reporting, ad, or attribution SDK. A **CI lockfile scan** (`firebase_analytics`, `sentry`, `crashlytics`, `facebook_*`, `appsflyer`, `firebase_messaging`, etc.) **fails the build** if one appears.
- **Don't** hand-bump license lists — regenerate the licenses screen from `LicenseRegistry` on every build; only the font OFLs are added by hand.
- **Do** version store metadata/screenshots in `store/` and upload via fastlane, never by hand-editing the consoles ad hoc (drift between locales).
- **Don't** request a permission "just in case" — every retained permission is something you must declare and justify.

## For Car and Pain specifically

Compliance is the **outward-facing proof** of the app's core promise: your years of hand-entered history live only on your device, and nothing phones home.

- **No-telemetry, made enforceable.** The three declarations (Play form, Apple label, `PrivacyInfo.xcprivacy`) are the store-facing face of the same posture the code enforces internally: omitted `INTERNET` permission + CI lockfile scan (see [Security, Privacy & At-Rest Encryption](./09-security-privacy.md)). The store forms don't *describe* a hope; they describe an OS-and-CI-guaranteed fact.
- **Offline-first.** With no server there is no privacy policy about "our servers" to write — the policy states plainly that all data stays on-device and is user-exportable/deletable. Data-deletion answers point at the **in-app secure wipe** and the local backup/export subsystem ([Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)), not a support email.
- **RTL / i18n.** The six-language listing + RTL screenshots are a *product* requirement, not marketing polish — the primary audience reads Persian/Arabic/Kurdish, and `CFBundleLocalizations` must advertise all six so the App Store shows the app as localized.
- **Licensing serves the fonts.** RTL rendering depends on **bundled** Vazirmatn + Noto (runtime font fetch is banned as a telemetry/offline violation), and bundling those fonts is precisely what makes the OFL attribution legally load-bearing.
- **Buy-once.** Purchase validation is local (StoreKit/Play Billing receipts, no license phone-home), which keeps the no-network claim intact end to end.

## Testing

Compliance is verified by **CI gates and manifest assertions**, not runtime tests, plus a manual pre-submission pass.

- **No-telemetry lockfile scan (blocking):** a CI step greps `pubspec.lock` for a denylist of analytics/crash/ad/messaging SDKs and fails on any hit.

  ```bash
  # ci/check_no_telemetry.sh
  FORBIDDEN='firebase_analytics|firebase_crashlytics|firebase_messaging|sentry|appsflyer|facebook_|amplitude|mixpanel|datadog'
  if grep -Eiq "$FORBIDDEN" pubspec.lock; then
    echo "::error::Forbidden telemetry SDK found in lockfile"; exit 1
  fi
  ```

- **Zero-outbound-connection test:** an `integration_test` on the prod flavor asserting no socket is opened during a representative session (belt-and-suspenders on top of the omitted permission). Cross-referenced in [Testing Strategy](./11-testing.md).
- **Manifest assertions in CI:** assert the prod `AndroidManifest.xml` has **no** `INTERNET` permission, `allowBackup="false"`, `usesCleartextTraffic="false"`; assert `ios/Runner/PrivacyInfo.xcprivacy` exists, parses, and declares `NSPrivacyTracking=false`.
- **Licenses screen widget/golden test:** open `showLicensePage` and assert the Vazirmatn and Noto entries render — RTL and LTR goldens, since this screen is user-visible in all six locales (golden dimensions per [Accessibility & Dynamic Type](./15-accessibility-dynamic-type.md) and [Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)).
- **Listing completeness check:** a script asserting every `store/metadata/<locale>/` and `store/screenshots/<locale>/` directory exists for all six locales before a release tag is allowed.

## Pitfalls

- **`PrivacyInfo.xcprivacy` treated as sufficient.** It satisfies neither store's separate declaration; the Apple App Privacy label and the Play Data-Safety form are *additional* and mandatory. A no-telemetry stance must not cause a *missing* manifest either — even a zero-tracking app is rejected without it.
- **Transitive plugin privacy manifests forgotten.** Apple aggregates the privacy manifests and required-reason APIs of your dependencies; a plugin that touches `UserDefaults`/file timestamps without a declared reason rejects the whole build. Audit `flutter_local_notifications`, `flutter_secure_storage`, `path_provider`, `local_auth`, `permission_handler`.
- **Declaration/binary mismatch.** Declaring "no data collected" while a stray dependency opens a socket is a removal risk. Omitting `INTERNET` on prod converts this from a trust exercise into an OS guarantee.
- **`allowBackup="true"` leaks data.** The Android default can exfiltrate secure storage via `adb backup` and cause `InvalidKeyException` on restore — set `allowBackup="false"` and exclude the DB/secure-storage from any backup rules.
- **Missing / stale OSS attribution.** Forgetting the font OFL texts (they aren't Dart packages, so `LicenseRegistry` misses them) is a license violation and a review flag. Add them explicitly.
- **LTR-only or English-only store assets.** Reads as a low-quality port to the exact audience the app targets; RTL screenshots and six localized listings are load-bearing, not optional.
- **Data-deletion answered "No".** Even offline, the form asks whether users can delete their data — answer "Yes, in-app" and back it with the secure-wipe path, or the review flags it.

## Decisions to confirm

- **Household P2P sync scope.** If peer-to-peer sync (feature parked for post-MVP) ever ships, it introduces a network/transfer surface that would change *every* answer on both privacy forms and require re-declaring data types and "in transit" encryption. Confirm P2P sync is **out of MVP** before the first submission so the "no data leaves the device" declaration is true — see the open question in [Security, Privacy & At-Rest Encryption](./09-security-privacy.md) and [Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md).
- **Bundled datasets & font subsetting.** The offline map layer, bundled datasets, and subsetted Vazirmatn/Noto fonts have significant binary-size implications that affect store download limits and the licenses that must be attributed. Confirm the asset-bundling/size-budget strategy (and which font subsets ship) before finalizing listings and the licenses screen.

## Related

- **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** — the no-telemetry enforcement (omitted `INTERNET`, CI lockfile scan) that the store declarations mirror.
- **[Build, Tooling, Release & CI/CD](./12-build-ci-release.md)** — fastlane `supply`/`deliver` for uploading metadata + screenshots, and the CI gates that block on compliance.
- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — the six locales, `CFBundleLocalizations`, and why fonts are bundled (not fetched), which drives the OFL attribution.
- **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)** — the in-app export/wipe that backs the "users can delete their data" form answer.
- **[Testing Strategy](./11-testing.md)** — the no-telemetry negative test and manifest assertions that keep declarations honest.
- **[Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md)** — which permissions the app *does* request, and therefore must justify on the Data-Safety form.
