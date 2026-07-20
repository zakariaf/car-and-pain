import 'package:data/data.dart';

/// The resolved infrastructure bundle produced by startup and injected into the
/// root `ProviderScope`. Holds the four async-initialized dependencies the DI
/// doc names: the encrypted database, the secure key store, the app-private
/// directories, and the resolved timezone.
class AppInfra {
  const AppInfra({
    required this.dirs,
    required this.timeZone,
    required this.database,
    required this.keyStore,
  });

  final AppDirs dirs;
  final AppTimeZone timeZone;
  final AppDatabase database;
  final SecureKeyStore keyStore;
}
