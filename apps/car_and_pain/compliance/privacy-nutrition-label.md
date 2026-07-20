# App Store — Privacy nutrition label

> Source of truth for App Store Connect **App Privacy**. Keep in sync with
> `ios/Runner/PrivacyInfo.xcprivacy` and re-confirm before every release.

## Summary

- **Data used to track you:** **None.**
- **Data linked to you:** **None.**
- **Data not linked to you:** **None.**

Overall: **Data Not Collected.**

## Rationale

Car and Pain is offline-first and account-free. All data is stored **only** on
the device in an encrypted database; nothing is transmitted, and there is no
account, server, or telemetry/analytics/crash SDK. The app declares **no**
tracking and **no** collected data types in `PrivacyInfo.xcprivacy`.

## Required-reason APIs

Declared in `PrivacyInfo.xcprivacy` with approved reason codes, used purely
on-device:

| API category | Reason | Why |
| --- | --- | --- |
| UserDefaults | `CA92.1` | App-local settings (accessed only by this app). |
| File timestamp | `C617.1` | Managing the app's own files/backups. |
| Disk space | `E174.1` | Guarding local backup writes against low storage. |
