# Result / Failure spine, global net, logging & validation

The full detail behind the two-tier decision. Tier 1 is typed values at every boundary; tier 2 is exceptions-for-bugs-only routed to the global net. Everything here lives in the Flutter-free `packages/core` (spine + failures) or `apps/car_and_pain` (bootstrap + logging).

## The `Result` spine (`packages/core/lib/src/result.dart`)

Hand-rolled, zero-dependency, native Dart 3 `sealed`. Pure engines and repositories share this one vocabulary. Do not reach for a package unless the team adopts `result_dart` `^2.2.0` wholesale.

```dart
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

extension ResultX<T, F extends Failure> on Result<T, F> {
  R fold<R>(R Function(T) onOk, R Function(F) onErr) => switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  Result<R, F> map<R>(R Function(T) f) => switch (this) {
        Ok(:final value) => Ok(f(value)),
        Err(:final failure) => Err(failure),
      };

  Result<R, F> flatMap<R>(Result<R, F> Function(T) f) => switch (this) {
        Ok(:final value) => f(value),
        Err(:final failure) => Err(failure),
      };

  bool get isOk => this is Ok<T, F>;
}
```

Keep the operator set small. If the team wants ready-made `mapError`/`AsyncResult`, adopt `result_dart` across the codebase — do NOT hand-roll half of it and import the other half.

## Failure taxonomy per boundary (`packages/core/lib/src/failures.dart`)

Each boundary owns a `sealed` family. `code` is a stable, localization-key-like identifier; params are typed; **no user-facing strings anywhere**.

| Boundary family | Subtypes (code) | Typed params |
| --- | --- | --- |
| `DbFailure` | `ConstraintViolation` (`db.constraint_violation`) | `String table` |
| | `TransactionRolledBack` (`db.transaction_rolled_back`) | — |
| | `DecryptFailed` (`db.decrypt_failed`) | — |
| | `NotFound` (`db.not_found`) | `String entity, String id` |
| `ImportFailure` | `CorruptArchive` (`import.corrupt_archive`) | — |
| | `SchemaVersionMismatch` (`import.schema_version_mismatch`) | `int expected, int found` |
| | `ChecksumMismatch` (`import.checksum_mismatch`) | — |
| `BackupFailure` | `VerifyFailed` (`backup.verify_failed`) | — |
| | `WriteFailed` (`backup.write_failed`) | — |
| `NotificationFailure` | `PermissionDenied` (`notif.permission_denied`) | — |
| | `ExactAlarmDenied` (`notif.exact_alarm_denied`) | — |
| | `PendingCapExceeded` (`notif.pending_cap_exceeded`) | `int requested` |
| `ComputeFailure` | `ComputeFailed` (`compute.failed`) | `String stage` |
| `ValidationFailure` | `ValidationFailure` (`validation.field_errors`) | `List<FieldError> fieldErrors` |

```dart
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
  final int requested; // budgeted against iOS's silent 64-cap
  @override String get code => 'notif.pending_cap_exceeded';
}
```

**Localization contract.** The UI maps `code` → a gen-l10n key at the presentation edge. A `Failure` × `supportedLocales` exhaustiveness test guarantees every code has a message in all six languages — a missing translation is a test failure, not a runtime blank.

## Convert-at-the-boundary

Wrap each dangerous call **once**, at its boundary. Log the original exception + stack **before** returning the typed failure. `on Exception catch` (or `on Object` when the plugin can throw `Error`s), never bare/underscore catch.

```dart
Future<Result<Vehicle, DbFailure>> insertVehicle(VehicleDraft d) async {
  try {
    return Ok((await _dao.insert(d)).toDomain());
  } on SqliteException catch (e, st) {
    _log.error('db.insert_vehicle', e, st);   // local rotating log FIRST
    return Err(_mapDbException(e));            // then the typed, string-free failure
  }
}

DbFailure _mapDbException(SqliteException e) => switch (e.resultCode) {
      19 /* SQLITE_CONSTRAINT */ => ConstraintViolation(e.tableName ?? 'unknown'),
      26 /* SQLITE_NOTADB */ => const DecryptFailed(),
      _ => const TransactionRolledBack(),
    };
```

## Global safety net — exceptions-for-bugs-only (`apps/car_and_pain/lib/src/bootstrap.dart`)

Anything *thrown* is a programmer error or truly-unrecoverable state. The trio catches all three error classes; the red screen is replaced by an RTL-aware fallback in release.

```dart
Future<void> bootstrap(Widget app) async {
  final log = await AppLog.open(); // rotating file in app-support dir

  FlutterError.onError = (details) {
    FlutterError.presentError(details);         // keep console/red-screen in debug
    log.error('flutter', details.exception, details.stack);
  };

  // Async / plugin (MethodChannel) errors — NOT caught by FlutterError.onError.
  PlatformDispatcher.instance.onError = (error, stack) {
    log.error('platform', error, stack);
    return true;                                 // handled
  };

  // RTL-aware fallback instead of the red screen in release.
  ErrorWidget.builder = (details) => const RtlAwareErrorFallback();

  runZonedGuarded(() => runApp(app), (error, stack) {
    log.error('zone', error, stack);
  });
}
```

Why all three: `FlutterError.onError` catches build/layout/paint sync errors; `PlatformDispatcher.instance.onError` catches async + platform-channel errors (notifications, exact-alarm, secure storage) that never reach `FlutterError.onError`; `runZonedGuarded` is the outermost catch-all for anything else in the zone.

## Isolate error re-wrapping

Heavy import/export and TCO/analytics run via `Isolate.run`/`compute`. **Isolate errors do not hit `FlutterError.onError`** — re-wrap them as `Result` across the boundary rather than letting them propagate opaquely.

```dart
Future<Result<Tco, ComputeFailure>> computeTco(TcoInput input) async {
  try {
    return Ok(await Isolate.run(() => TcoCalculator().run(input)));
  } on Object catch (e, st) {
    _log.error('compute.tco', e, st);
    return const Err(ComputeFailed('tco'));
  }
}
```

## Local structured logging

Severity + module + stable code + **redacted** context to a size-capped rotating file in the app-support dir (via `logger` with a custom `FileOutput`, or `dart:developer` `log` for a lighter footprint). Verbose logs gate behind `kDebugMode` / a hidden diagnostics toggle. Settings exposes **"Export diagnostics"** so users attach logs to an email bug report themselves — telemetry-free, account-free.

- **Redact** odometer values, GPS, VIN, plate, and any free-text notes before writing.
- **Never** route to Crashlytics/Sentry/Firebase — CI lockfile scan fails the build on any such SDK.
- Rotate at a fixed byte cap (e.g. 1 MiB × 3 files); oldest is dropped.

## Accumulative validation with normalization (`packages/core/lib/src/validation.dart`)

Field validators accumulate **all** errors (applicative style), not fail-fast. **Normalize before parse**: Eastern-Arabic/Persian digits → ASCII, the Persian decimal (`٫`) and grouping (`٬`) separators → ASCII, and Jalali/Hijri dates → a canonical UTC instant — so a `FormatException` never escapes as a crash on valid-looking input. This is the one sanctioned use of `fpdart` `Option`.

```dart
Result<FuelEntry, ValidationFailure> validateFill(RawFillForm raw) {
  final errors = <FieldError>[];

  final liters = normalizeDecimal(raw.liters, errors);      // Arabic digits + ٫/٬ → ASCII
  final odo = parseOdometer(raw.odometer, errors);
  final date = resolveToInstant(raw.date, raw.calendar, errors); // Jalali/Hijri → UTC

  if (errors.isNotEmpty) return Err(ValidationFailure(errors));
  return Ok(FuelEntry(liters: liters!, odometer: odo!, at: date!));
}
```

`FieldError` carries a field name + a stable reason code (`'not_a_number'`, `'out_of_range'`) — again no localized string; the form maps the reason to a gen-l10n message.

## fpdart scope (selective)

| fpdart construct | Verdict |
| --- | --- |
| `Option<T>` | ALLOWED — nullable-with-intent in validation/parse |
| Applicative validation (`Validated`-style accumulation) | ALLOWED — the accumulative form validators above |
| `TaskEither` / `Either` as a default return type | FORBIDDEN — use the hand-rolled `Result` |
| `Reader` / `ReaderTaskEither` | FORBIDDEN — Riverpod is the DI mechanism |
| `dartz` (any) | FORBIDDEN — superseded, undocumented |

## Pitfalls

- **User strings in `Failure`/`Exception`** — breaks six-language translation, RTL mirroring, numeral localization. Codes + params only.
- **Silent swallow** (`catch (_) {}` / bare `catch (e)`) — discards type *and* stack; fatal when data can't be re-fetched.
- **`default:` on a sealed switch** — a new failure subtype slips through unhandled at compile time.
- **Treating notification/exact-alarm errors as sync** — they are async plugin/MethodChannel errors NOT caught by `FlutterError.onError`; catch at the call site AND rely on `PlatformDispatcher.onError`.
- **Letting numeral/calendar `FormatException`s bubble** — users type Persian/Arabic digits and Jalali/Hijri dates; normalize before parse.
- **Spreading `fpdart` `TaskEither`/`Reader`** — heavy onboarding, muddied stack traces.
