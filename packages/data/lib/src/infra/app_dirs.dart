/// The resolved app-private directories, computed once at bootstrap and injected
/// through `appDirsProvider`. Paths are flavor-scoped so a dev build never
/// touches prod data.
final class AppDirs {
  const AppDirs({
    required this.supportDir,
    required this.dbPath,
    required this.backupsDir,
    required this.attachmentsDir,
  });

  /// Application support directory (app-private, not user-visible).
  final String supportDir;

  /// Absolute path to the encrypted database file.
  final String dbPath;

  /// Directory holding verified single-file backups.
  final String backupsDir;

  /// Directory holding (optionally encrypted) attachment blobs.
  final String attachmentsDir;

  @override
  String toString() => 'AppDirs(support: $supportDir, db: $dbPath)';
}
