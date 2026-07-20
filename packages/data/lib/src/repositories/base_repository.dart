import 'package:core/core.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';

const _uuid = Uuid();

/// A UUIDv7 text PK — time-ordered, collision-free across devices, stable across
/// export/re-import. Never an autoincrement integer.
String newId() => _uuid.v7();

/// Base for every repository. Owns the injected [AppDatabase] and [Clock],
/// stamps timestamps, and maps DB exceptions to typed [DbFailure]. Concrete
/// repositories map Drift rows → domain models and return `Result<T, Failure>`
/// — never throwing across the boundary. Every read filters `is_deleted = 0`.
abstract class BaseRepository {
  BaseRepository(this.db, {Clock clock = const SystemClock()}) : _clock = clock;

  final AppDatabase db;
  final Clock _clock;

  /// Current instant in UTC epoch millis (via the injected clock).
  int nowMillis() => _clock.nowUtc().millisecondsSinceEpoch;

  /// Map a caught DB error to a typed [DbFailure] (constraint vs generic).
  DbFailure mapDbError(Object error, {String table = 'unknown'}) {
    final message = error.toString().toLowerCase();
    if (message.contains('unique') ||
        message.contains('constraint') ||
        message.contains('foreign key')) {
      return ConstraintViolation(table);
    }
    return const TransactionRolledBack();
  }
}
