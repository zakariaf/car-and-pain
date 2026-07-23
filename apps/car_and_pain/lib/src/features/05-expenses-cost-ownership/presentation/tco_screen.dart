import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../application/expense_providers.dart';

/// The Total-Cost-of-Ownership breakdown (M6-T6): a CustomPainter category-bucket
/// bar chart (no chart library) plus cost/distance + cost/day headlines, with an
/// explicit "insufficient data" state where the engine reports it.
class TcoScreen extends ConsumerWidget {
  const TcoScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(tcoReportProvider(vehicleId));
    final fmt = ref.watch(activeNumeralFormatProvider);

    return PulseScaffold(
      title: l10n.tcoTitle,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Center(child: Text(l10n.tcoError)),
        data: (report) {
          // Base currency assumed EUR for the display code (amounts are already
          // base-normalised by the engine); a real app reads the base setting.
          const ccy = 'EUR';
          final buckets = report.byBucket.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          return ListView(
            padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
            children: [
              PulseCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.tcoTotal,
                        style: Theme.of(context).textTheme.labelLarge),
                    Text(
                      formatMoney(fmt, report.totalMinor, ccy),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: PulseTokens.s2),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: report.hasEnoughData &&
                                    report.costPerKmMinor != null
                                ? formatMoney(fmt, report.costPerKmMinor!, ccy)
                                : l10n.tcoInsufficientData,
                            label: l10n.tcoPerKm,
                          ),
                        ),
                        Expanded(
                          child: StatTile(
                            value: report.hasEnoughData &&
                                    report.costPerDayMinor != null
                                ? formatMoney(fmt, report.costPerDayMinor!, ccy)
                                : l10n.tcoInsufficientData,
                            label: l10n.tcoPerDay,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: PulseTokens.s3),
              SectionHeader(title: l10n.tcoBreakdown),
              if (buckets.isEmpty)
                Center(child: Text(l10n.tcoNoCosts))
              else
                _TcoBucketChart(
                  buckets: [
                    for (final e in buckets) (bucketName(l10n, e.key), e.value),
                  ],
                  semanticsSummary:
                      '${l10n.tcoBreakdown}: ${buckets.map((e) => '${bucketName(l10n, e.key)} ${formatMoney(fmt, e.value, ccy)}').join(', ')}',
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A built-in-first horizontal bar chart of TCO buckets (CustomPainter, no chart
/// library), mirrored under RTL and wrapped in [Semantics].
class _TcoBucketChart extends StatelessWidget {
  const _TcoBucketChart(
      {required this.buckets, required this.semanticsSummary});

  final List<(String label, int amountMinor)> buckets;
  final String semanticsSummary;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: semanticsSummary,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final b in buckets)
              Padding(
                padding:
                    const EdgeInsetsDirectional.only(bottom: PulseTokens.sHalf),
                child: Row(
                  children: [
                    SizedBox(width: 96, child: Text(b.$1)),
                    Expanded(
                      child: SizedBox(
                        height: 16,
                        child: CustomPaint(
                          painter: _BarPainter(
                            fraction: buckets.first.$2 == 0
                                ? 0
                                : b.$2 / buckets.first.$2,
                            color: color,
                            rtl: rtl,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  _BarPainter({required this.fraction, required this.color, required this.rtl});

  final double fraction;
  final Color color;
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * math.max(0.0, math.min(1.0, fraction));
    final rect = rtl
        ? Rect.fromLTWH(size.width - w, 0, w, size.height)
        : Rect.fromLTWH(0, 0, w, size.height);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(4)),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.fraction != fraction || old.rtl != rtl || old.color != color;
}
