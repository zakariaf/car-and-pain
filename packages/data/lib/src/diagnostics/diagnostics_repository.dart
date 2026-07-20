import '../infra/app_database.dart';

/// A trivial repository proving the DI seam in F1: it depends only on the
/// injected [AppDatabase], returns a domain value (never a Drift row), and is
/// exposed through `diagnosticsRepositoryProvider`. Replaced by real per-feature
/// repositories in F2.
abstract interface class DiagnosticsRepository {
  /// A label derived from the injected database — used by the F1 shell to show
  /// that infrastructure was wired through Riverpod.
  String databaseLabel();
}

/// The default implementation, constructed from the DI-provided database.
final class AppDiagnosticsRepository implements DiagnosticsRepository {
  const AppDiagnosticsRepository(this._db);

  final AppDatabase _db;

  @override
  String databaseLabel() => _db.label;
}
