import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_lock_controller.dart';

/// A persistent, no-UI lifecycle observer (M1-T1) that drives the app-lock over
/// backgrounding. The lock SCREEN is now a route (`/lock`) reached via the
/// router redirect when the controller reports `locked`, so this observer only
/// records background time and re-locks on resume past the timeout — flipping
/// the controller, which the router's refreshListenable turns into a redirect.
///
/// Mounted once around the app (bootstrap), so its observer lives for the whole
/// session regardless of which route is showing.
class AppLockLifecycleObserver extends ConsumerStatefulWidget {
  const AppLockLifecycleObserver({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<AppLockLifecycleObserver> createState() =>
      _AppLockLifecycleObserverState();
}

class _AppLockLifecycleObserverState
    extends ConsumerState<AppLockLifecycleObserver>
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
  Widget build(BuildContext context) => widget.child;
}
