import '../db/app_database.dart';

/// A trivial repository proving the DI seam: it depends only on the injected
/// [AppDatabase] and returns a domain value (never a Drift row). Real per-feature
/// repositories replace its role as F2 fleshes out.
abstract interface class DiagnosticsRepository {
  /// A label derived from the injected database — shows infra is wired through
  /// Riverpod (used by the F1/F2 placeholder home).
  String databaseLabel();
}

/// The default implementation, constructed from the DI-provided database.
class AppDiagnosticsRepository implements DiagnosticsRepository {
  const AppDiagnosticsRepository(this._db);

  final AppDatabase _db;

  @override
  String databaseLabel() => 'car-and-pain schema v${_db.schemaVersion}';
}
