import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';
import 'app_lock_screen.dart';

/// Wraps the app shell with the app-lock gate (F7-T4): the [child] is covered by
/// the unlock screen whenever the lock is engaged, and re-locks when the app has
/// been in the background past the auto-lock timeout.
///
/// While the lock state is still resolving, protected content is deliberately
/// NOT shown — a blank surface stands in so nothing leaks before the gate
/// decides. Backgrounding is recorded on `paused`/`hidden` (not the transient
/// `inactive`, which also fires during the biometric prompt).
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    final ctrl = ref.read(appLockControllerProvider.notifier);
    switch (lifecycle) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        ctrl.markBackgrounded();
      case AppLifecycleState.resumed:
        ctrl.maybeLockOnResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(
      appLockControllerProvider.select((s) => s.asData?.value.locked),
    );
    return switch (locked) {
      // Still resolving — show nothing rather than flashing protected content.
      null => const ColoredBox(color: Colors.black),
      true => const AppLockScreen(),
      false => widget.child,
    };
  }
}
