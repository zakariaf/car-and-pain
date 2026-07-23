import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../application/expense_providers.dart';

/// The loan/lease detail view (M6-T6): the amortization schedule, the monthly
/// payment + total interest headline, an early-payoff figure, and the equity /
/// NEGATIVE-EQUITY position — surfaced explicitly with an icon + label, never
/// colour alone.
class FinancingDetailScreen extends ConsumerWidget {
  const FinancingDetailScreen({
    required this.vehicleId,
    required this.financingId,
    super.key,
  });

  final String vehicleId;
  final String financingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final financings =
        ref.watch(financingListProvider(vehicleId)).asData?.value ?? const [];
    final f = financings.where((x) => x.id == financingId).firstOrNull;

    if (f == null) {
      return PulseScaffold(
        title: l10n.financingTitle,
        body: Center(child: Text(l10n.financingNotFound)),
      );
    }

    final ccy = f.currencyCode;
    final schedule = const AmortizationEngine().schedule(f.toLoanTerms());
    final elapsed = _elapsedMonths(f.startDate).clamp(0, schedule.rows.length);
    final payoff =
        const AmortizationEngine().payoffAfter(f.toLoanTerms(), elapsed);
    // Depreciation proxy off the financed amount → equity vs the current balance.
    final value = DepreciationCurve(
      initialValueMinor: f.principalMinor,
      usefulLifeMonths: 96,
    ).valueAt(elapsed);
    final equity = EquityPosition(
      valueMinor: value,
      loanBalanceMinor: payoff.payoffMinor,
    );

    return PulseScaffold(
      title: l10n.financingTitle,
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          PulseCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StatTile(
                        value:
                            formatMoney(fmt, schedule.monthlyPaymentMinor, ccy),
                        label: l10n.financingMonthly,
                      ),
                    ),
                    Expanded(
                      child: StatTile(
                        value:
                            formatMoney(fmt, schedule.totalInterestMinor, ccy),
                        label: l10n.financingTotalInterest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: PulseTokens.s2),
                StatTile(
                  value: formatMoney(fmt, payoff.payoffMinor, ccy),
                  label: l10n.financingPayoffNow,
                ),
              ],
            ),
          ),
          const SizedBox(height: PulseTokens.s3),
          // Equity / negative-equity, redundantly encoded (icon + label).
          _EquityCard(l10n: l10n, fmt: fmt, ccy: ccy, equity: equity),
          const SizedBox(height: PulseTokens.s3),
          SectionHeader(title: l10n.financingSchedule),
          _scheduleTable(context, l10n, fmt, ccy, schedule),
        ],
      ),
    );
  }

  Widget _scheduleTable(
    BuildContext context,
    AppLocalizations l10n,
    NumeralFormat fmt,
    String ccy,
    AmortizationSchedule schedule,
  ) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.financingColPeriod)),
          DataColumn(label: Text(l10n.financingColPayment)),
          DataColumn(label: Text(l10n.financingColInterest)),
          DataColumn(label: Text(l10n.financingColPrincipal)),
          DataColumn(label: Text(l10n.financingColBalance)),
        ],
        rows: [
          for (final r in schedule.rows)
            DataRow(cells: [
              DataCell(Text(fmt.formatUngrouped(r.period))),
              DataCell(Text(formatMoney(fmt, r.paymentMinor, ccy))),
              DataCell(Text(formatMoney(fmt, r.interestMinor, ccy))),
              DataCell(Text(formatMoney(fmt, r.principalMinor, ccy))),
              DataCell(Text(formatMoney(fmt, r.balanceMinor, ccy))),
            ]),
        ],
      ),
    );
  }

  int _elapsedMonths(Instant start) {
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (now <= start.epochMillis) return 0;
    return ((now - start.epochMillis) / (30.44 * 86400000)).floor();
  }
}

class _EquityCard extends StatelessWidget {
  const _EquityCard({
    required this.l10n,
    required this.fmt,
    required this.ccy,
    required this.equity,
  });

  final AppLocalizations l10n;
  final NumeralFormat fmt;
  final String ccy;
  final EquityPosition equity;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = equity.isNegative
        ? (Icons.warning_amber_rounded, l10n.financingNegativeEquity)
        : (Icons.savings_outlined, l10n.financingEquity);
    return PulseCard(
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: PulseTokens.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                Text(
                  formatMoney(fmt, equity.equityMinor, ccy),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
