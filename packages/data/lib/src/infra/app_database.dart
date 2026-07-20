/// The opened, key-unwrapped encrypted database handle.
///
/// TODO(F2): replace this port with the generated Drift `AppDatabase` backed by
/// SQLCipher (whole-DB AES-256 at rest). It is a port for now so the DI graph,
/// bootstrap sequence, and repository seam can be locked in before the schema
/// exists.
abstract interface class AppDatabase {
  /// A human-readable label — proves the DI seam is wired end-to-end in F1.
  String get label;

  /// Release the underlying connection.
  Future<void> close();
}

/// A no-op database that lets the F1 app shell boot before the real encrypted
/// Drift database (F2) exists. Carries the resolved [dbPath] it *would* open.
final class PlaceholderAppDatabase implements AppDatabase {
  const PlaceholderAppDatabase(this.dbPath);

  final String dbPath;

  @override
  String get label => 'placeholder-db@$dbPath';

  @override
  Future<void> close() async {}
}
