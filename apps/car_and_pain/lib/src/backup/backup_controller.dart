import 'dart:io';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../security/security_providers.dart';
import 'backup_providers.dart';

part 'backup_controller.g.dart';

/// The lifecycle phase of the backup surface.
enum BackupPhase { idle, running, success, failure }

/// The backup surface state (F6-T10). Failures are typed so the UI localizes
/// them from a stable code, never an English string.
class BackupState {
  const BackupState({
    required this.phase,
    this.lastBackupPath,
    this.lastBackupAtMillis,
    this.error,
  });

  final BackupPhase phase;
  final String? lastBackupPath;
  final int? lastBackupAtMillis;
  final Failure? error;

  bool get hasBackedUp => lastBackupAtMillis != null;

  BackupState copyWith({
    BackupPhase? phase,
    String? lastBackupPath,
    int? lastBackupAtMillis,
    Failure? error,
    bool clearError = false,
  }) =>
      BackupState(
        phase: phase ?? this.phase,
        lastBackupPath: lastBackupPath ?? this.lastBackupPath,
        lastBackupAtMillis: lastBackupAtMillis ?? this.lastBackupAtMillis,
        error: clearError ? null : (error ?? this.error),
      );
}

/// Drives "back up now" + restore + the last-successful-backup honesty state
/// (F6-T8/T10). Keeps the surface's status and persists the last-backup metadata
/// so a failure is shown as "last successful backup: …", never a crash.
@riverpod
class BackupController extends _$BackupController {
  static const _kLastAt = 'backup.last_at';
  static const _kLastPath = 'backup.last_path';
  static const _kKeepLast = 'backup.keep_last';

  @override
  Future<BackupState> build() async {
    final settings = ref.read(settingsRepositoryProvider);
    final at = await settings.get(_kLastAt);
    return BackupState(
      phase: BackupPhase.idle,
      lastBackupAtMillis: at == null ? null : int.tryParse(at),
      lastBackupPath: await settings.get(_kLastPath),
    );
  }

  BackupState get _cur =>
      state.asData?.value ?? const BackupState(phase: BackupPhase.idle);

  /// Create an encrypted backup on-device under [passphrase], persist its
  /// metadata, and prune old backups per the retention policy.
  Future<void> backupNow(String passphrase) async {
    state =
        AsyncData(_cur.copyWith(phase: BackupPhase.running, clearError: true));
    final now = ref.read(clockProvider).nowUtc().millisecondsSinceEpoch;
    final dir = ref.read(appDirsProvider).backupsDir;
    final path = '$dir/backup-$now.capb';

    final result = await ref
        .read(backupEngineProvider)
        .writeArchiveToFile(passphrase, path);
    switch (result) {
      case Ok(:final value):
        final settings = ref.read(settingsRepositoryProvider);
        await settings.set(_kLastAt, '$now');
        await settings.set(_kLastPath, value);
        await _prune(dir);
        state = AsyncData(_cur.copyWith(
          phase: BackupPhase.success,
          lastBackupAtMillis: now,
          lastBackupPath: value,
          clearError: true,
        ));
      case Err(:final failure):
        state = AsyncData(
            _cur.copyWith(phase: BackupPhase.failure, error: failure));
    }
  }

  /// Restore an archive (bytes already read from a picked file) under
  /// [passphrase]. Returns a typed failure for the UI; on success the data
  /// providers are invalidated so the app reflects the restored state.
  Future<Result<void, Failure>> restoreFromBytes(
    List<int> bytes,
    String passphrase,
  ) async {
    final engine = ref.read(backupEngineProvider);
    final read = await engine.readArchive(bytes, passphrase);
    if (read case Err(:final failure)) return Err(failure);
    final restored =
        await engine.restore((read as Ok<BackupContents, ImportFailure>).value);
    if (restored case Err(:final failure)) return Err(failure);
    // Force the shell to re-read the restored DB.
    ref.invalidate(vehiclesRepositoryProvider);
    return const Ok(null);
  }

  Future<void> _prune(String dir) async {
    final keepRaw = await ref.read(settingsRepositoryProvider).get(_kKeepLast);
    final keepLast = int.tryParse(keepRaw ?? '') ?? 5;
    final directory = Directory(dir);
    if (!directory.existsSync()) return;
    final names = directory
        .listSync()
        .whereType<File>()
        .map((f) => f.uri.pathSegments.last)
        .where((n) => n.startsWith('backup-') && n.endsWith('.capb'))
        .toList();
    for (final name in backupsToPrune(names, keepLast)) {
      final f = File('$dir/$name');
      if (f.existsSync()) f.deleteSync();
    }
  }
}
