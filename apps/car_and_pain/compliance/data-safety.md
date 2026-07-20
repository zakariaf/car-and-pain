# Google Play — Data safety declaration

> Source of truth for the Play Console **Data safety** form. Keep in sync with
> the code; re-confirm before every release.

## Summary

- **Does your app collect or share any of the required user data types?** **No.**
- **Is all of the user data encrypted in transit?** Not applicable — the app
  makes **no network requests** (the prod build omits the `INTERNET` permission).
- **Do you provide a way for users to request that their data is deleted?**
  Not applicable — no data leaves the device; the user owns and can delete the
  local database and all backups at any time.

## Data collection

| Data type | Collected | Shared | Purpose |
| --- | --- | --- | --- |
| _(none)_ | No | No | — |

All vehicle, fuel, service, expense, trip, and document data is stored **only**
on the device in an encrypted (SQLCipher, AES-256) database. There is no
account, no server of record, and no telemetry/analytics/crash SDK.

## Tracking

The app does **not** track users and contains **no** advertising or analytics
identifiers.
