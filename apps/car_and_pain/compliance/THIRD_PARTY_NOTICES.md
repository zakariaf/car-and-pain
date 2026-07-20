# Third-party notices

Car and Pain bundles the open-source runtime dependencies below. Each earns its
place by binding genuinely hard, platform-specific, or security-critical native
work (see `docs/planning/01-dependencies-and-decisions.md`). Dev/build-time
tooling (linters, codegen, test runners) is not listed — it never ships in the
binary.

## Kept runtime dependencies (F1)

| Package | License | Why it ships |
| --- | --- | --- |
| flutter_riverpod / riverpod_annotation | MIT | The one framework: DI + reactive state across ~25 modules. |
| go_router | BSD-3-Clause (Flutter) | First-party declarative routing / deep links. |
| path_provider | BSD-3-Clause (Flutter) | Resolves app-private directories for the DB/backups. |
| intl / flutter_localizations | BSD-3-Clause | gen-l10n i18n stack (six locales, RTL, numerals). |

## Arriving in later foundation epics

Listed here so the notices scaffold is complete from birth; add the exact
version + license text when each lands:

| Package | Epic | Expected license |
| --- | --- | --- |
| drift / drift_dev | F2 | MIT |
| sqlcipher_flutter_libs (SQLCipher) | F2 | BSD-style (SQLCipher) |
| flutter_secure_storage | F7 | BSD-3-Clause |
| local_auth | F7 | BSD-3-Clause (Flutter) |
| flutter_local_notifications | F5 | BSD-3-Clause |
| timezone / flutter_timezone | F5 | BSD-2-Clause / MIT |

## Bundled fonts (F4)

| Font | License |
| --- | --- |
| Vazirmatn | SIL Open Font License 1.1 |
| Noto Sans Arabic / Noto Nastaliq Urdu | SIL Open Font License 1.1 |

> Full license texts are reproduced in-app on the "Open-source licenses" screen
> (via `showLicensePage`) and must accompany any distribution.
