import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../application/vehicle_enums.dart';
import '../application/vehicle_profile_providers.dart';

/// The odometer ledger UI (M2-T4): the reading timeline (value + date + source)
/// over the shared ledger, plus a quick-log entry that runs the audited
/// anomaly check (regression / rollover / duplicate) and requires an explicit
/// override before persisting. Reads/writes go through [LedgerRepository]; the
/// pure math lives in the core [LedgerEngine].
class VehicleLedgerScreen extends ConsumerWidget {
  const VehicleLedgerScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final vehicle = ref.watch(vehicleProvider(vehicleId)).asData?.value;
    final readings =
        ref.watch(vehicleLedgerProvider(vehicleId)).asData?.value ??
            const <LedgerReading>[];
    final fmt = ref.watch(activeNumeralFormatProvider);
    final unit = distanceUnitFromCode(vehicle?.distanceUnit);

    return PulseScaffold(
      title: l10n.ledgerTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.ledgerAddReading,
          onPressed: () => _logReading(context, ref),
        ),
      ],
      body: readings.isEmpty
          ? Center(child: Text(l10n.ledgerEmpty))
          : ListView.separated(
              // Newest first.
              itemCount: readings.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = readings[readings.length - 1 - i];
                return ListTile(
                  leading: const Icon(Icons.speed_outlined),
                  title: Text(
                    fmt.formatInt(Distance.metres(r.lifetimeValue)
                        .toDisplay(unit)
                        .round()),
                  ),
                  subtitle: Text(ledgerSourceLabel(l10n, r.source)),
                );
              },
            ),
    );
  }

  Future<void> _logReading(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => _ReadingDialog(controller: controller),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;

    final repo = ref.read(ledgerRepositoryProvider);
    final now = Instant.fromDateTime(const SystemClock().nowUtc());
    // Value entered in display units → canonical metres.
    final vehicle = ref.read(vehicleProvider(vehicleId)).asData?.value;
    final unit = distanceUnitFromCode(vehicle?.distanceUnit);
    final metres = Distance.fromDisplay(unit, value.toDouble()).metres;

    final preview = await repo.previewManual(
      vehicleId: vehicleId,
      value: metres,
      takenAt: now,
    );
    // The check itself failed (DB error) — abort rather than persist unchecked.
    if (preview.isErr) return;
    final warnings = preview.valueOrNull ?? const <FieldError>[];

    var override = false;
    if (warnings.isNotEmpty) {
      // An anomaly REQUIRES explicit confirmation. If we can't show the dialog
      // (the route was popped mid-check), abort — never persist un-acknowledged.
      if (!context.mounted) return;
      override = await showDialog<bool>(
            context: context,
            builder: (context) => _AnomalyDialog(warnings: warnings),
          ) ??
          false;
      if (!override) return; // cancelled → nothing persists
    }
    await repo.appendManual(
      vehicleId: vehicleId,
      value: metres,
      takenAt: now,
      overrideRegression: override,
    );
  }
}

/// The quick-log keypad entry — a single numeric field returning the parsed
/// integer reading (in the vehicle's display unit).
class _ReadingDialog extends ConsumerWidget {
  const _ReadingDialog({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final parser = ref.watch(activeNumeralParserProvider);
    return AlertDialog(
      title: Text(l10n.ledgerAddReading),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.ledgerReadingValue),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ledgerCancel),
        ),
        TextButton(
          onPressed: () {
            final v = parser.parseScaled(controller.text, 0);
            Navigator.of(context).pop(v);
          },
          child: Text(l10n.vehicleSave),
        ),
      ],
    );
  }
}

/// The anomaly-override confirmation — names the reason (regression / rollover /
/// duplicate) and requires an explicit "Save anyway".
class _AnomalyDialog extends StatelessWidget {
  const _AnomalyDialog({required this.warnings});
  final List<FieldError> warnings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.ledgerAnomalyTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in warnings)
            Padding(
              padding:
                  const EdgeInsetsDirectional.only(bottom: PulseTokens.sHalf),
              child: Text(_message(l10n, w.code)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l10n.ledgerCancel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l10n.ledgerOverride),
        ),
      ],
    );
  }

  String _message(AppLocalizations l10n, String code) => switch (code) {
        'rollover' => l10n.ledgerAnomalyRollover,
        'duplicate' => l10n.ledgerAnomalyDuplicate,
        _ => l10n.ledgerAnomalyRegression,
      };
}
