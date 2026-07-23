import 'dart:async';

import 'package:data/data.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_providers.dart';

/// A change signal that re-emits on every new odometer reading (M5-T2), so the
/// reconciler can re-project distance/engine-hour reminders reactively — a phone
/// can't watch the odometer roll, so the engine re-projects on each new reading.
final ledgerRevisionProvider = StreamProvider<int>(
  (ref) => ref.watch(ledgerRepositoryProvider).watchReadingCount(),
);

/// Keeps the OS notification queue reconciled with the DB (F5-T4). Runs a full
/// `ReminderScheduler.reconcileAll` on first mount, on every foreground resume,
/// and — reactively (M5-T2) — whenever a new ledger reading lands (debounced), so
/// a distance/engine-hour rule's projected date self-corrects as the vehicle is
/// used. Covers DB edits, time/timezone changes, restore-from-backup, and the iOS
/// soonest-window refresh. Android reboots are additionally re-armed by the
/// plugin's boot receiver (see AndroidManifest). Mounted in bootstrap only, so
/// widget tests (which use the fake gateway) aren't driven by it.
class NotificationReconciler extends ConsumerStatefulWidget {
  const NotificationReconciler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationReconciler> createState() => _State();
}

class _State extends ConsumerState<NotificationReconciler>
    with WidgetsBindingObserver {
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reconcile());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_reconcile());
  }

  Future<void> _reconcile() async {
    try {
      final scheduler = await ref.read(reminderSchedulerProvider.future);
      await scheduler.reconcileAll();
    } on Object {
      // Notifications are best-effort: a failure here never breaks the app.
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-project reactively when a new reading lands, debounced so a bulk import
    // doesn't storm the OS. Skip the initial load (initState already reconciles).
    ref.listen<AsyncValue<int>>(ledgerRevisionProvider, (prev, next) {
      final before = prev?.asData?.value;
      final after = next.asData?.value;
      if (before == null || after == null || before == after) return;
      _debounce?.cancel();
      _debounce = Timer(
        const Duration(milliseconds: 400),
        () => unawaited(_reconcile()),
      );
    });
    return widget.child;
  }
}
