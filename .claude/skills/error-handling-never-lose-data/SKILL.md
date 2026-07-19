---
name: error-handling-never-lose-data
description: Authors and reviews Car and Pain's reliability spine — the hand-rolled sealed Result and Failure hierarchy in packages/core that every repository, use-case, service, and canonical units-money engine returns instead of throwing, plus the never-lose-data subsystem — multi-table Drift plus SQLCipher transactions over WAL, debounced autosave drafts, optimistic soft-delete with SnackBar Undo, Trash and auto-purge behind one shared is_deleted view, the global FlutterError plus PlatformDispatcher plus runZonedGuarded net, and selective fpdart Option. Honors the real decisions — no telemetry, codes not strings, exhaustive switch with no default, en de fr fa ar ckb localization, Persian numeral normalization. Use when editing result.dart, failures.dart, bootstrap.dart, DAO transactions, DbFailure, ImportFailure, NotificationFailure, ValidationFailure, soft-delete, Trash or Undo, or diagnosing swallowed catch blocks, missing failure branches, deleted rows polluting analytics, TCO or charts, or FormatException crashes.
license: Proprietary
metadata:
  project: Car and Pain
  domain: error-handling, reliability, never-lose-data, data-integrity
  source-docs: docs/flutter/08-error-handling.md, docs/flutter/13-backup-export-recovery.md
---

# Error Handling & Never-Lose-Data

Author, review, and extend Car and Pain's reliability spine. Car and Pain has **no server, no account, and no telemetry** — a dropped fuel or service entry exists nowhere else and is gone forever. Error handling here is not a network-resilience story; it is about protecting hand-entered records that cannot be re-fetched and degrading gracefully around device permissions and resources. Two tiers, no middle ground: **typed values at every boundary** (`Result` + sealed `Failure`), and **exceptions for bugs only** (caught by the global trio, logged locally). Wrapped around both, never-lose-data is a first-class subsystem — transactions, autosave, soft-delete/Undo — not plumbing.

## Non-negotiable rules

- Return `Result<T, F extends Failure>` from **every** repository, use-case, and service that can fail expectedly (DB, file/backup, notification scheduling, import/export, on-device parse/compute). The canonical units-money engines (`Distance`, `Volume`, `Money`) return this same `Result` — this skill OWNS that spine. Throwing is for bugs only.
- Hand-roll the zero-dependency sealed `Result` and `Failure` in the Flutter-free `packages/core` so pure engines and repositories share ONE vocabulary. `result_dart` `^2.2.0` is the sanctioned drop-in alt if ready-made `flatMap`/`mapError`/`AsyncResult` operators are wanted — do not mix both.
- Give **each boundary** its own `sealed Failure` family (`DbFailure`, `BackupFailure`, `ImportFailure`, `NotificationFailure`, `ValidationFailure`, `ComputeFailure`). Every failure carries a **stable `code`** (localization-key-like, e.g. `'db.decrypt_failed'`) + **typed params** — **NEVER a user-facing or localized string**. Six languages (en/de/fr LTR + fa/ar/ckb RTL), Eastern-Arabic/Persian numerals, and Gregorian/Jalali/Hijri calendars mean any baked-in text breaks translation, bidi mirroring, and numeral rendering.
- `switch` failures **exhaustively with NO `default:`**. Sealed exhaustiveness makes adding a new failure subtype a *compile error* until every UI switch covers it — a `default:` silently defeats that. Localize from the `code` at the presentation layer via gen-l10n, never inside the failure.
- Convert-at-the-boundary: wrap each dangerous call **once**, `on Exception catch (e, st)` (or `on Object`), **log the original error + stack to the local rotating log BEFORE returning** the typed failure. **NEVER `catch (_) {}` or bare `catch (e)`** that discards type/stack — fatal when the lost thing can't be re-fetched. CI greps `catch\s*\(\s*_\s*\)` and fails the build.
- Wrap multi-table mutations (record + attachments + reminder recompute + rollup invalidation) in **one** `_db.transaction(...)` over WAL; any throw rolls back the whole unit. **Keep the transaction body synchronous `txn.*` DB calls ONLY** — never `await` an unrelated future or re-enter the same DB inside it (deadlock / broken atomicity).
- Persist in-progress form state to a `drafts` table on a **500ms-1s debounce** — never write the encrypted DB per keystroke (battery + SQLCipher overhead). On reopen, offer to restore. Debounce timing uses an injected `Clock` (`package:clock`).
- Soft-delete via `is_deleted`/`deleted_at` columns. A **single shared query layer or DB view filters deleted rows out of EVERY read** — records lists, analytics, TCO, AND CustomPainter charts. Deleting is optimistic + shows a SnackBar with Undo; a Trash screen restores/purges; auto-purge after N days. Forgetting one analytics/chart query pollutes reports.
- Log **locally only** — a size-capped rotating file in the app-support dir + a user-initiated "Export diagnostics" affordance. **NEVER Crashlytics/Sentry/Firebase/any crash SaaS** (violates no-telemetry; enforced by CI lockfile scan).
- Adopt `fpdart` `^1.2.0` **selectively**: `Option` + applicative form-validation only. **Never** `TaskEither`/`Reader` as a default return type (muddies stack traces, overkill for a mostly-synchronous local app). **Never `dartz`.** Never `freezed` unions for the error spine — native `sealed` already gives exhaustive switches (freezed is for entities).
- Normalize Eastern-Arabic/Persian digits **and** the Persian decimal (`٫`) + grouping (`٬`) separators to ASCII, and resolve Jalali/Hijri dates to a canonical UTC instant, **BEFORE** any parse/validate — so a `FormatException` never escapes as a crash on valid-looking input. Validators **accumulate all** errors (applicative), not fail-fast.
- Re-wrap `Isolate.run`/`compute` errors as `Result` at the boundary — isolate errors do **not** hit `FlutterError.onError`, so catch them at the call site or they propagate opaquely.

## Package layout

```text
packages/core/lib/src/                 # Flutter-FREE — shared by engines + repos
  result.dart          # sealed Result<T,F> = Ok | Err; fold/map/flatMap extensions
  failures.dart        # sealed Failure + per-boundary families (codes + typed params)
  validation.dart      # FieldError, accumulative validate helpers (fpdart Option)
apps/car_and_pain/lib/src/
  bootstrap.dart       # global trio: FlutterError.onError + PlatformDispatcher + runZonedGuarded
  logging/app_log.dart # rotating FileOutput in app-support dir; Export diagnostics
packages/data/lib/src/
  <feature>/<x>_repository.dart   # convert-at-boundary; returns Result<T, DbFailure>
  drafts/draft_store.dart          # debounced autosave table
  soft_delete/deleted_filter.dart  # THE single is_deleted view/builder every read uses
  trash/trash_service.dart         # restore / purge / auto-purge-after-N-days
```

## Canonical inline snippet — convert-at-the-boundary + exhaustive switch

Every dangerous call is wrapped once. The original exception + stack go to the local log **before** returning a typed, string-free failure. The UI switches exhaustively and localizes from the code.

```dart
// packages/data — repository boundary. Log first, then return typed failure.
Future<Result<Vehicle, DbFailure>> insertVehicle(VehicleDraft d) async {
  try {
    return Ok((await _dao.insert(d)).toDomain());
  } on SqliteException catch (e, st) {
    _log.error('db.insert_vehicle', e, st);   // local rotating log — NEVER swallow
    return Err(_mapDbException(e));            // typed, stable code, no strings
  }
}

// apps — presentation. Sealed => no `default:`; l10n happens here, from the code.
Widget buildError(BuildContext context, NotificationFailure f) {
  final l10n = context.l10n;
  return switch (f) {
    PermissionDenied() =>
      RecoveryBanner(message: l10n.notifPermissionDenied, action: openSettings),
    ExactAlarmDenied() =>
      RecoveryBanner(message: l10n.notifExactAlarmDenied, action: grantExactAlarm),
    PendingCapExceeded(:final requested) =>
      RecoveryBanner(message: l10n.notifTooMany(requested), action: reviewReminders),
  }; // adding a 4th NotificationFailure here is a COMPILE error until handled
}
```

Full `Result`/`Failure` source, the taxonomy per boundary, and the global `bootstrap.dart` trio live in **[references/result-failure.md](references/result-failure.md)**.

## References

- **[references/result-failure.md](references/result-failure.md)** — the `Result` spine source, the full sealed `Failure` taxonomy per boundary (with codes + params), the global `FlutterError`/`PlatformDispatcher`/`runZonedGuarded` net, isolate re-wrapping, local rotating logging, and accumulative validation with numeral/calendar normalization.
- **[references/transactional-writes.md](references/transactional-writes.md)** — multi-table Drift/SQLCipher transactions over WAL: the synchronous-`txn.*`-only rule, the deadlock/re-entrancy edge cases, `TransactionRolledBack` mapping, and the rollback test recipe.
- **[references/autosave-softdelete-undo.md](references/autosave-softdelete-undo.md)** — the debounced `drafts` table + restore-on-reopen, and optimistic soft-delete: `is_deleted`/`deleted_at`, the single shared `deleted_filter` view, SnackBar Undo, Trash restore/purge, auto-purge-after-N-days, and the analytics/TCO/chart parity guarantee.

## Scripts

Run from anywhere in the repo; each prints findings to stdout.

- `scripts/check-swallowed-catch.sh` — greps `packages/`/`apps/` for `catch (_)`, bare `catch (e)` without rethrow/log, and `default:` on failure switches. Fails on any hit (mirrors the CI gate).
- `scripts/check-softdelete-parity.sh` — greps analytics/TCO/chart query builders for direct table reads that bypass the shared `deleted_filter`/`is_deleted` view; lists offenders.
- `scripts/check-no-telemetry.sh` — scans `pubspec.yaml`/lockfiles for crash/analytics SDKs (crashlytics, sentry, firebase_*) and forbidden fpdart `TaskEither`/`Reader` + `dartz` usage.
- `scripts/analyze-and-gen.sh` — `dart run build_runner build --delete-conflicting-outputs` then `flutter analyze` (FVM-aware), the exhaustiveness/lint gate.

## Examples & assets

- `examples/typed_failures.dart` — a complete boundary: sealed `DbFailure` family, convert-at-boundary repo method, exhaustive UI switch.
- `examples/transactional_write.dart` — a multi-table `logFill` transaction returning `Result<void, DbFailure>`.
- `examples/soft_delete_undo.dart` — optimistic soft-delete Notifier + SnackBar Undo + the shared filtered read.
- `examples/accumulative_validation.dart` — normalize-then-validate with error accumulation, no `FormatException` escape.
- `assets/failure_family.dart.tmpl` — template for a new sealed `Failure` boundary family.
- `assets/repository_boundary.dart.tmpl` — template for a convert-at-the-boundary repository method.

## For Car and Pain specifically

- **No re-sync path.** Typed Results + transactions + autosave drafts + soft-delete/Undo are *the* reliability story, not an add-on. Optimize for never corrupting or silently dropping a canonical value.
- **RTL/i18n.** Failures carry codes + params so the UI localizes into en/de/fr and fa/ar/ckb with correct mirroring and numerals. Normalizing digits *and* `٫`/`٬` before parse turns "crash on valid input" into a typed `ValidationFailure`.
- **Degradation is permission/resource, not network.** `PermissionDenied`, `ExactAlarmDenied`, `PendingCapExceeded` (budgeted under iOS's silent 64 cap) are typed cases, each mapped 1:1 to a localized recovery action.
- **Canonical storage.** `Distance`/`Volume`/`Money` (ISO-4217 exponent, minor units) flow through Results; parse/normalization failures surface as typed `ValidationFailure`, never corrupting a stored canonical value.
- **No-telemetry is enforced, not promised.** All logging on-device; a CI lockfile scan fails the build if any analytics/crash SDK appears.

## Testing

Because a use-case returns a *value*, assert on the branch directly — no `try/catch` scaffolding. `expect(result, isA<Err>())` then match the subtype. Timer/clock logic uses injected `Clock` + `fake_async`; DB tests use in-memory Drift (`NativeDatabase.memory()`); stubs use `mocktail`.

- **Typed-failure branches** — unique-constraint insert → `Err(ConstraintViolation)`; decrypt-fail → `Err(DecryptFailed)`.
- **Failure × locale exhaustiveness** — iterate every `Failure` subtype × all six `supportedLocales`; assert a non-empty localized message (catches missing translations / un-mapped codes).
- **Transaction rollback** — multi-table write whose 2nd statement throws → assert DB byte-unchanged **and** `Err(TransactionRolledBack)`.
- **Autosave/crash sim** — write a draft, don't commit, reopen, assert restorable; `fake_async` verifies debounce (no write before the window, exactly one after).
- **Trash/Undo** — soft-delete → excluded from record lists **and** analytics/TCO/chart queries; Undo restores; `fake_async` verifies auto-purge after N days.
- **Validation table-tests** — parametrize Latin/Eastern-Arabic/Persian digits × Gregorian/Jalali/Hijri × `٫`/`٬`; normalization succeeds; malformed input yields `ValidationFailure.fieldErrors`, never an uncaught `FormatException`.
- **Global handlers** — throw inside the `runZonedGuarded` zone → lands in the log **file**; `PlatformDispatcher.instance.onError` returns `true`; `FlutterError.onError` still calls `presentError`.
- **Isolate propagation** — force a throw inside the import/TCO isolate → returns as `Err(...)`.

See **docs/flutter/11-testing.md** for the full pyramid and coverage gates.
