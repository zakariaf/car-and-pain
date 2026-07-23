import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../security/app_lock_controller.dart';
import '../settings/locale_controller.dart';
import '../shell/shell_state.dart';
import '../startup/startup_controller.dart';

/// Bridges the four gate signals into a `Listenable` so the router re-runs its
/// redirect when any change: startup readiness, app-lock, onboarding-complete,
/// and vehicle count (M1-T1).
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    _subs = [
      ref.listen(startupControllerProvider, (_, __) => notifyListeners()),
      ref.listen(appLockControllerProvider, (_, __) => notifyListeners()),
      ref.listen(settingsMapProvider, (_, __) => notifyListeners()),
      ref.listen(vehiclesStreamProvider, (_, __) => notifyListeners()),
    ];
  }

  late final List<ProviderSubscription<Object?>> _subs;

  @override
  void dispose() {
    for (final s in _subs) {
      s.close();
    }
    super.dispose();
  }
}
