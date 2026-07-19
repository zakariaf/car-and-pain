# 🛡️ Error Handling & Never-Lose-Data

> How Car and Pain represents, propagates, logs, and recovers from failure so that a user's irreplaceable, hand-entered vehicle history is never silently lost or corrupted.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** · **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** · **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)**

---

## Decision

Two tiers, no middle ground.

1. **Typed values at every boundary.** Repositories, use-cases, and services (DB, file/backup, notification scheduling, import/export, on-device parse/compute) return a Dart 3 `sealed Result<T, F>` carrying a **sealed `Failure`** hierarchy per boundary (`DbFailure`, `BackupFailure`, `ImportFailure`, `NotificationFailure`, `ValidationFailure`). Failures carry a **stable code + typed params, never user-facing strings**. The UI `switch`es exhaustively (no `default`) and localizes at the presentation layer. We hand-roll the zero-dependency sealed `Result` (Flutter's official pattern), with `result_dart` as the sanctioned drop-in if we want ready-made `flatMap`/`mapError`/`AsyncResult` operators.
2. **Exceptions are for bugs only.** Anything thrown is a programmer error or truly-unrecoverable state, caught by the global trio — `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `runZonedGuarded` — and routed to a **LOCAL rotating log** with a user-exportable diagnostics bundle. Never a crash SaaS.

Wrapped around both tiers, **never-lose-data is a first-class subsystem**, not plumbing: transactional multi-table writes over WAL, debounced autosave drafts, soft-delete + Trash + Undo with centralized filtering, and atomic verified backups with a mandatory pre-import snapshot. `fpdart` is adopted **selectively** — `Option` and applicative form-validation only, never `TaskEither`/`Reader` as a default return type.

## Why

Car and Pain has **no server and no telemetry**, so error handling is not a network-resilience story — it is about protecting records that exist nowhere else and degrading gracefully around device permissions and resources. That reframes every choice:

- **Result over bare `try/catch`.** `catch (_) {}` and bare `catch (e)` (as Flutter's own offline sample does) discard both the error type *and* the stack trace — catastrophic when the lost thing is a fuel entry that cannot be re-fetched. Dart 3 sealed exhaustiveness forces the UI to handle every failure branch at *compile time*.
- **Codes, not strings.** With six languages (en/de/fr LTR + fa/ar/ckb RTL), Eastern-Arabic/Persian numerals, and Gregorian/Jalali/Hijri calendars, any user text baked into a `Failure` breaks translation, bidi mirroring, and numeral rendering. Codes + typed params localize cleanly at the edge.
- **Local-only logging.** Routing errors to Crashlytics/Sentry/Firebase would violate the no-telemetry, account-free promise outright. The rotating file + "Export diagnostics" affordance keeps bug reports on-device and user-initiated.

**Alternatives considered and rejected:**

| Option | Verdict | Why |
| --- | --- | --- |
| Hand-rolled sealed `Result` (Flutter official) | **PRIMARY** | Zero deps, native exhaustiveness, trivial to unit-test as plain values. |
| `result_dart` `^2.2.0` | **PRIMARY alt** | Same spine, ready-made operators; pick if we want the sugar out of the box. |
| `fpdart` `^1.2.0` | **SELECTIVE** | `Option` + applicative validation earn their keep; its `TaskEither`/`Reader` stack obscures stack traces and is overkill for a mostly-synchronous local app. |
| `dartz` | **REJECT** | Superseded by fpdart, undocumented, awkward HKT emulation — a maintenance liability. |
| Bare exceptions everywhere | **REJECT as default** | Loses types/stacks, forces nothing, silently swallows. Kept only for bugs → global handlers. |
| `freezed` unions for Result/Failure | **REJECT for error path** | Codegen overhead where native `sealed` already gives exhaustive switches; use freezed for entities, not the error spine. |

## How we do it

### The Result spine (in `core/`)

`Result` and the `Failure` hierarchy live in the Flutter-free `core/` package so pure engines and repositories share one vocabulary.

```dart
// packages/core/lib/src/result.dart
sealed class Result<T, F extends Failure> {
  const Result();
}

final class Ok<T, F extends Failure> extends Result<T, F> {
  const Ok(this.value);
  final T value;
}

final class Err<T, F extends Failure> extends Result<T, F> {
  const Err(this.failure);
  final F failure;
}

// A few extensions instead of a package: map, flatMap, fold.
extension ResultX<T, F extends Failure> on Result<T, F> {
  R fold<R>(R Function(T) onOk, R Function(F) onErr) => switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };
}
```

### Typed failure taxonomy per boundary

Each boundary owns a sealed failure family. Codes are stable identifiers; params are typed; **no strings**.

```dart
// packages/core/lib/src/failures.dart
sealed class Failure {
  const Failure();
  String get code; // stable, localization-key-like, e.g. 'db.decrypt_failed'
}

sealed class DbFailure extends Failure {
  const DbFailure();
}
final class ConstraintViolation extends DbFailure {
  const ConstraintViolation(this.table);
  final String table;
  @override String get code => 'db.constraint_violation';
}
final class TransactionRolledBack extends DbFailure {
  const TransactionRolledBack();
  @override String get code => 'db.transaction_rolled_back';
}
final class DecryptFailed extends DbFailure {
  const DecryptFailed();
  @override String get code => 'db.decrypt_failed';
}

sealed class ImportFailure extends Failure { const ImportFailure(); }
final class CorruptArchive extends ImportFailure {
  const CorruptArchive();
  @override String get code => 'import.corrupt_archive';
}
final class SchemaVersionMismatch extends ImportFailure {
  const SchemaVersionMismatch({required this.expected, required this.found});
  final int expected;
  final int found;
  @override String get code => 'import.schema_version_mismatch';
}

sealed class NotificationFailure extends Failure { const NotificationFailure(); }
final class PermissionDenied extends NotificationFailure {
  const PermissionDenied();
  @override String get code => 'notif.permission_denied';
}
final class ExactAlarmDenied extends NotificationFailure {
  const ExactAlarmDenied();
  @override String get code => 'notif.exact_alarm_denied';
}
final class PendingCapExceeded extends NotificationFailure {
  const PendingCapExceeded(this.requested);
  final int requested; // budgeted against iOS's silent 64 cap
  @override String get code => 'notif.pending_cap_exceeded';
}

// ValidationFailure accumulates — see the validation section.
final class ValidationFailure extends Failure {
  const ValidationFailure(this.fieldErrors);
  final List<FieldError> fieldErrors;
  @override String get code => 'validation.field_errors';
}
```

### Convert-at-the-boundary

Every dangerous call is wrapped once, at its boundary. The original exception + stack trace go to the local log **before** returning a typed failure. Never `catch (_) {}`.

```dart
Future<Result<Vehicle, DbFailure>> insertVehicle(VehicleDraft d) async {
  try {
    final row = await _dao.insert(d);
    return Ok(row.toDomain());
  } on SqliteException catch (e, st) {
    _log.error('db.insert_vehicle', e, st);         // local rotating log
    return Err(_mapDbException(e));                   // typed, no strings
  }
}
```

### Exhaustive UI switch

Because `Failure` families are `sealed`, the UI must handle every case — adding a new failure is a *compile error* until the switch covers it. Localization happens here, from the code.

```dart
Widget buildError(BuildContext context, NotificationFailure f) {
  final l10n = context.l10n;
  return switch (f) {
    PermissionDenied() =>
      RecoveryBanner(message: l10n.notifPermissionDenied, action: openSettings),
    ExactAlarmDenied() =>
      RecoveryBanner(message: l10n.notifExactAlarmDenied, action: grantExactAlarm),
    PendingCapExceeded(:final requested) =>
      RecoveryBanner(message: l10n.notifTooMany(requested), action: reviewReminders),
  }; // no `default:` — that would defeat exhaustiveness
}
```

### Global safety net (in `bootstrap.dart`)

```dart
// apps/car_and_pain/lib/src/bootstrap.dart
Future<void> bootstrap(Widget app) async {
  final log = await AppLog.open(); // rotating file in app-support dir

  FlutterError.onError = (details) {
    FlutterError.presentError(details);            // keeps console/red-screen in debug
    log.error('flutter', details.exception, details.stack);
  };

  // Async / plugin (MethodChannel) errors — NOT caught by FlutterError.onError.
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('platform', error, stack);
    return true;
  };

  // RTL-aware fallback instead of the red screen in release.
  ErrorWidget.builder = (details) => const RtlAwareErrorFallback();

  runZonedGuarded(() => runApp(app), (error, stack) {
    log.error('zone', error, stack);
  });
}
```

### Never-lose-data subsystem

**Transactional writes.** Multi-table mutations (record + attachments + reminder recompute + rollup invalidation) run in one Drift/SQLCipher transaction over WAL; any throw rolls back the whole unit.

```dart
Future<Result<void, DbFailure>> logFill(FillDraft d) async {
  try {
    await _db.transaction(() async {          // journal_mode=WAL, foreign_keys=ON
      final id = await _fillDao.insert(d);
      await _ledgerDao.appendOdometer(d.odometer, sourceId: id);
      await _rollupDao.bumpRevision(d.vehicleId, d.period); // recompute key
    });
    return const Ok(null);
  } on Object catch (e, st) {
    _log.error('db.log_fill', e, st);
    return const Err(TransactionRolledBack());
  }
}
```

> Keep transaction bodies to synchronous `txn.*` DB calls only — awaiting unrelated futures or re-entering the same DB inside a transaction deadlocks or breaks atomicity.

**Debounced autosave drafts.** In-progress form state persists to a `drafts` table on a 500 ms–1 s debounce, so an OEM kill mid-entry loses nothing. On reopen, offer to restore. Debounce to avoid hammering the encrypted DB per keystroke.

**Soft-delete + Trash + Undo.** `is_deleted`/`deleted_at` columns; a **single shared query layer or DB view filters deleted rows out of EVERY read** — including analytics, TCO, and charts. Deleting shows a SnackBar with Undo (optimistic soft-delete, Undo reverts); a Trash screen restores/purges; auto-purge after N days.

**Atomic backup + safe import.** Backups are produced by `VACUUM INTO` after a WAL checkpoint (never a raw live-file copy), encrypted, written to `<name>.tmp`, then atomically renamed, and **verified by re-opening** before success is reported. Import **always** takes a pre-import auto-snapshot, validates checksum + schema version into staging, then swaps — never mutates the live DB in place; any failure returns a typed `ImportFailure` and restores the snapshot. See **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)**.

### Accumulative validation with normalization

Field validators accumulate **all** errors (applicative style), not fail-fast. Crucially, Eastern-Arabic/Persian digits **and** the Persian/Arabic decimal (`٫`) and grouping (`٬`) separators are normalized to ASCII, and Jalali/Hijri dates are resolved to a canonical instant, **before** validation — so a `FormatException` never escapes as a crash on valid-looking input.

```dart
Result<FuelEntry, ValidationFailure> validateFill(RawFillForm raw) {
  final errors = <FieldError>[];

  final liters = normalizeDecimal(raw.liters) // ٱrabic digits + ٫/٬ → ASCII
      .flatMapErr((_) => errors.add(FieldError('liters', 'not_a_number')));
  final odo = parseOdometer(raw.odometer, errors);
  final date = resolveToInstant(raw.date, raw.calendar, errors); // Jalali/Hijri → UTC

  if (errors.isNotEmpty) return Err(ValidationFailure(errors));
  return Ok(FuelEntry(liters: liters!, odometer: odo!, at: date!));
}
```

### Isolate error re-wrapping

Heavy import/export and TCO/analytics run via `Isolate.run`/`compute`. Isolate errors do **not** hit `FlutterError.onError`, so re-wrap them as `Result` across the boundary rather than letting them propagate opaquely.

```dart
Future<Result<Tco, ComputeFailure>> computeTco(TcoInput input) async {
  try {
    return Ok(await Isolate.run(() => TcoCalculator().run(input)));
  } on Object catch (e, st) {
    _log.error('compute.tco', e, st);
    return const Err(ComputeFailure());
  }
}
```

### Local structured logging

Severity + module + stable code + **redacted** context to a size-capped rotating file in the app-support dir (via `logger` with a custom `FileOutput`, or `dart:developer` `log` for a lighter footprint). Verbose logs gate behind `kDebugMode`/a hidden diagnostics toggle. Settings exposes **"Export diagnostics"** so users attach logs to an email bug report themselves — telemetry-free and account-free.

## Rules

**Do**
- Return `Result<T, F>` from every repository, use-case, and service that can fail expectedly.
- Give each boundary a `sealed Failure` family; carry a stable `code` + typed params.
- `switch` failures exhaustively with **no `default:`**.
- `on Exception catch (e, st)` (or `on Object`), log the original + stack, then return a typed failure.
- Wrap multi-table writes in one transaction; keep the body synchronous DB calls only.
- Normalize numerals **and** decimal/grouping separators + resolve calendars **before** parse/validate.
- Re-wrap isolate/`compute` errors as `Result` at the boundary.
- Log locally only; expose user-initiated "Export diagnostics".

**Don't**
- No `catch (_) {}` or bare `catch (e)` that swallows type/stack. (CI grep: `catch\s*\(\s*_\s*\)` in feature/package code fails the build.)
- No user-facing/localized strings inside `Failure`/`Exception` objects.
- No `default:` on a sealed `Failure` switch.
- No Crashlytics/Sentry/Firebase/any crash SaaS — enforced by the CI lockfile scan (see no-telemetry).
- No raw-file backup writes; no importing in place without a pre-import snapshot.
- No autosave to the encrypted DB on every keystroke — debounce.
- No `fpdart` `TaskEither`/`Reader` as a default return type; `Option` + validation only.
- No `dartz`.

## For Car and Pain specifically

- **Offline / never-lose-data.** There is no re-sync path, so typed Results + transactions + autosave drafts + soft-delete/Undo + atomic verified backups are *the* reliability story, not an add-on. A dropped fuel or service entry is gone forever otherwise.
- **RTL / i18n.** Failures carry codes + params so the UI localizes into en/de/fr and fa/ar/ckb with correct mirroring, Eastern-Arabic/Persian numerals, and Gregorian/Jalali/Hijri rendering. Normalization of digits *and* `٫`/`٬` separators before parse turns "crash on valid input" into a typed `ValidationFailure`.
- **Notifications / degradation.** "Offline degradation" here is permission/resource degradation, not network. `permissionDenied`, `exactAlarmDenied`, and `pendingCapExceeded` (budgeted under iOS's silent 64 cap) are typed cases, each mapped 1:1 to a concrete localized recovery action (grant exact alarms, review reminders, degrade to inexact). See **[Local Notifications & Background Reliability](./07-notifications.md)**.
- **Canonical storage.** Value objects (`Distance`, `Volume`, `Money` with ISO-4217 exponent) flow through Results; parse/normalization failures surface as typed validation, never corrupt a stored canonical value.
- **No-telemetry.** Enforced, not promised: all logging is on-device; a CI lockfile scan fails the build if any analytics/crash SDK appears. See **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)**.

## Testing

Because a use-case returns a *value*, assert on the branch directly — no `try/catch` scaffolding. All timer/clock logic uses injected `Clock` (`package:clock`) + `fake_async`; DB tests use in-memory Drift (`NativeDatabase.memory()` / `sqflite_common_ffi`); stubs use `mocktail` (fake over mock).

- **Typed-failure branches.** Unique-constraint insert → `Err(ConstraintViolation)`; decrypt-fail → `Err(DecryptFailed)`. `expect(result, isA<Err>())` then match the subtype.
- **Failure × locale exhaustiveness.** Iterate every `Failure` subtype × all six `supportedLocales` and assert a non-empty localized message — catches missing translations and un-mapped codes.
- **Transaction rollback.** Multi-table write whose 2nd statement throws (FK/constraint) → assert DB byte-unchanged **and** `Err(TransactionRolledBack)`.
- **Autosave/crash sim.** Write a draft, don't commit, reopen, assert restorable; `fake_async` verifies the debounce (no write before the window, exactly one after).
- **Trash/Undo.** Soft-delete → excluded from record lists **and** analytics/TCO/chart queries; Undo restores; `fake_async` clock verifies auto-purge after N days.
- **Backup round-trip (flagship, blocking CI).** export → wipe → import → deep-equal with **WAL active**, attachment SHA-256 + preserved fill flags. Corrupt archive bytes / bump schema version → assert `ImportFailure.corruptArchive` / `schemaVersionMismatch`, and the pre-import snapshot restores cleanly.
- **Global handlers.** Throw inside the `runZonedGuarded` zone → assert it lands in the log **file** (not console only); `PlatformDispatcher.instance.onError` returns `true`; `FlutterError.onError` still calls `presentError`.
- **Validation table-tests.** Parametrize over Latin/Eastern-Arabic/Persian digits and Gregorian/Jalali/Hijri dates + `٫`/`٬` separators → normalization succeeds; malformed input yields `ValidationFailure.fieldErrors`, never an uncaught `FormatException`.
- **Isolate propagation.** Force a throw inside the import/TCO isolate → assert it returns as `Err(...)`.
- **RTL/LTR goldens.** Error/empty/recovery UI states in at least one RTL and one LTR locale.

See **[Testing Strategy](./11-testing.md)** for the full pyramid and coverage gates.

## Pitfalls

- **User strings in `Failure`/`Exception`** — breaks six-language translation, RTL mirroring, and numeral localization. Codes + params only.
- **Silent swallow** (`catch (_) {}` / bare `catch (e)`) — discards type *and* stack; fatal when data can't be re-fetched.
- **`default:` on a sealed switch** — a new failure subtype then slips through unhandled at compile time.
- **Spreading `fpdart` `TaskEither`/`Reader`** — heavy onboarding, muddied stack traces, overkill for a mostly-synchronous local app.
- **`dartz` in 2025** — superseded, undocumented, awkward HKT emulation.
- **Awaiting unrelated futures / re-entering the DB inside a transaction** — deadlock or broken atomicity. Synchronous `txn.*` calls only.
- **Forgetting soft-delete filtering in analytics/TCO/chart queries** — deleted rows pollute reports. Centralize `is_deleted` in a view/shared builder.
- **Autosaving to the encrypted DB per keystroke** — battery drain + SQLCipher overhead. Debounce and/or use a cheaper draft store.
- **Routing errors to Crashlytics/Sentry** — violates no-telemetry. On-device only.
- **Treating notification/exact-alarm errors as sync** — they're async plugin/MethodChannel errors NOT caught by `FlutterError.onError`; catch at the call site **and** rely on `PlatformDispatcher.onError`.
- **Non-atomic backup writes** — a kill mid-write leaves a truncated/corrupt backup. Temp-file + rename + verify-by-reopen; never import in place without a snapshot.
- **Letting numeral/calendar `FormatException`s bubble** — users type Persian/Arabic digits and Jalali/Hijri dates; normalize before parse.

## Related

- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — the transactions, WAL, soft-delete columns, and snapshot-guarded migrations these patterns depend on.
- **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** — the `VACUUM INTO` + verify-by-reopen + pre-import snapshot subsystem behind the never-lose-data guarantee.
- **[Local Notifications & Background Reliability](./07-notifications.md)** — the `NotificationFailure` cases and their permission/degradation recovery actions.
- **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)** — numeral/separator normalization and calendar resolution that keep validation crash-free.
- **[Security, Privacy & At-Rest Encryption](./09-security-privacy.md)** — no-telemetry enforcement and the encryption whose decrypt failures surface as typed `DbFailure`.
- **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)** — the product-side promise these engineering patterns deliver.
