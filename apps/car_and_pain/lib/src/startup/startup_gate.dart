import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock_gate.dart';
import '../shell/home_screen.dart';
import 'splash_screen.dart';
import 'startup_controller.dart';
import 'startup_error_screen.dart';

/// The startup state machine: splash while init runs, the app shell on success,
/// a retry-capable error screen on failure. This lives in the widget tree so
/// both paths are testable end-to-end.
class StartupGate extends ConsumerWidget {
  const StartupGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startup = ref.watch(startupControllerProvider);
    return startup.when(
      loading: () => const SplashScreen(),
      // An unexpected (untyped) error still degrades to a retry screen.
      error: (_, __) => StartupErrorScreen(
        failure: const UnknownFailure(),
        onRetry: () => ref.invalidate(startupControllerProvider),
      ),
      data: (result) => switch (result) {
        // The shell is covered by the app-lock gate (F7): it decides whether to
        // show the unlock screen before any protected content mounts.
        Ok() => const AppLockGate(child: HomeScreen()),
        Err(:final failure) => StartupErrorScreen(
            failure: failure,
            onRetry: () => ref.invalidate(startupControllerProvider),
          ),
      },
    );
  }
}
