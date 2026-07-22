import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_providers.dart';

/// Keeps the OS notification queue reconciled with the DB (F5-T4). Runs a full
/// `ReminderScheduler.reconcileAll` on first mount and on every foreground
/// resume — covering DB edits, time/timezone changes, restore-from-backup, and
/// the iOS soonest-window refresh. Android reboots are additionally re-armed by
/// the plugin's boot receiver (see AndroidManifest). Mounted in bootstrap only,
/// so widget tests (which use the fake gateway) aren't driven by it.
class NotificationReconciler extends ConsumerStatefulWidget {
  const NotificationReconciler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<NotificationReconciler> createState() => _State();
}

class _State extends ConsumerState<NotificationReconciler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_reconcile());
  }

  @override
  void dispose() {
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
  Widget build(BuildContext context) => widget.child;
}
