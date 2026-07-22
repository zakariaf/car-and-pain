import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart';

import 'permission_service.dart';

/// The PULSE rationale sheet shown *before* any OS permission prompt (F5-T6):
/// it explains why the app needs the permission. Fully localized, RTL-mirrored
/// via Directional geometry, and it returns whether the user chose to proceed.
class NotificationRationaleSheet extends StatelessWidget {
  const NotificationRationaleSheet({
    required this.title,
    required this.body,
    required this.actionLabel,
    super.key,
  });

  final String title;
  final String body;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.notifications_active_outlined,
                color: theme.colorScheme.primary, size: 32),
            const SizedBox(height: PulseTokens.s2),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: PulseTokens.s1),
            Text(body,
                style: theme.textTheme.bodyLarge?.copyWith(color: pc.text2)),
            const SizedBox(height: PulseTokens.s3),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: PulseButton(
                label: actionLabel,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Show the rationale sheet; returns true if the user chose to proceed.
Future<bool> showNotificationRationale(
  BuildContext context, {
  required String title,
  required String body,
  required String actionLabel,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    builder: (_) => NotificationRationaleSheet(
      title: title,
      body: body,
      actionLabel: actionLabel,
    ),
  );
  return result ?? false;
}

/// Request the notification permission behind a rationale (F5-T6). Re-entrant:
/// returns immediately if already granted; on permanent denial the sheet's
/// action deep-links to system settings. Denial degrades gracefully — the
/// caller simply gets a non-granted state, never an exception.
Future<PermissionState> ensureNotificationPermission(
  BuildContext context, {
  required PermissionService service,
  required AppLocalizations l10n,
}) async {
  final state = await service.notificationStatus();
  if (state == PermissionState.granted) return state;
  if (!context.mounted) return state;

  final permanentlyDenied = state == PermissionState.permanentlyDenied;
  final proceed = await showNotificationRationale(
    context,
    title: l10n.notifPermTitle,
    body: l10n.notifPermBody,
    actionLabel:
        permanentlyDenied ? l10n.notifPermOpenSettings : l10n.notifPermAllow,
  );
  if (!proceed) return state;

  if (permanentlyDenied) {
    await service.openSettings();
    return service.notificationStatus();
  }
  return service.requestNotification();
}
