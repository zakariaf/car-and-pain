import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../attachments/storage_settings_screen.dart';
import '../backup/backup_recovery_screen.dart';
import '../backup/recovery_redeem_screen.dart';
import '../features/18-data-offline-backup/presentation/trash_screen.dart';
import '../gallery/pulse_gallery.dart';
import '../security/security_settings_screen.dart';
import '../settings/settings_screen.dart';
import '../startup/startup_gate.dart';

/// The **single** GoRouter for the whole app (invariant: go_router only, one
/// router). For F1/F2 it routes to the startup gate + the Trash screen; M1
/// expands this into a `StatefulShellRoute.indexedStack` Rooms shell with
/// full-screen flows above it via `rootNavigatorKey`.
final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const StartupGate(),
      ),
      GoRoute(
        path: '/trash',
        builder: (context, state) => const TrashScreen(),
      ),
      GoRoute(
        path: '/gallery',
        builder: (context, state) => const PulseGallery(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/settings/security',
        builder: (context, state) => const SecuritySettingsScreen(),
      ),
      GoRoute(
        path: '/settings/storage',
        builder: (context, state) => const StorageSettingsScreen(),
      ),
      GoRoute(
        path: '/settings/backup',
        builder: (context, state) => const BackupRecoveryScreen(),
      ),
      GoRoute(
        path: '/settings/recovery',
        builder: (context, state) => const RecoveryRedeemScreen(),
      ),
    ],
  );
});
