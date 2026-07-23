import 'package:core/core.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../../01-vehicles-garage/application/vehicle_profile_providers.dart';
import '../application/trip_providers.dart';
import 'report_export.dart';
import 'trip_ui.dart';

/// The jurisdiction-aware mileage report (M7-T10): per-(tax-year, rate) lines,
/// business-use %, total deduction, a redundantly-encoded compliance banner
/// flagging reconstructed trips, and CSV/JSON export. Priced under a bundled
/// IRS/HMRC scheme (offline, no setup); PDF rendering is deferred.
class MileageReportScreen extends ConsumerStatefulWidget {
  const MileageReportScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<MileageReportScreen> createState() => _State();
}

class _State extends ConsumerState<MileageReportScreen> {
  ReportJurisdiction _jurisdiction = ReportJurisdiction.irs;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId)).asData?.value;
    final unit = distanceUnitOf(vehicle?.distanceUnit);
    final report = ref.watch(
        mileageReportProvider((vehicleId: widget.vehicleId, j: _jurisdiction)));

    return PulseScaffold(
      title: l10n.mileageReportTitle,
      actions: [
        PopupMenuButton<String>(
          icon: const Icon(Icons.ios_share),
          tooltip: l10n.reportExport,
          onSelected: (v) => _export(context, l10n, report, csv: v == 'csv'),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'csv', child: Text(l10n.reportExportCsv)),
            PopupMenuItem(value: 'json', child: Text(l10n.reportExportJson)),
          ],
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          SegmentedButton<ReportJurisdiction>(
            segments: [
              ButtonSegment(
                  value: ReportJurisdiction.irs, label: Text(l10n.reportIrs)),
              ButtonSegment(
                  value: ReportJurisdiction.hmrc, label: Text(l10n.reportHmrc)),
            ],
            selected: {_jurisdiction},
            onSelectionChanged: (s) => setState(() => _jurisdiction = s.first),
          ),
          const SizedBox(height: PulseTokens.s3),
          _ComplianceBanner(report: report, l10n: l10n, fmt: fmt),
          const SizedBox(height: PulseTokens.s3),
          SectionHeader(title: l10n.reportLinesHeader),
          if (report.lines.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
              child: Text(l10n.reportNoDeductible),
            )
          else
            for (final line in report.lines)
              PulseCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.table_rows_outlined),
                  title: Text(l10n.reportLineRate(
                    line.taxYearLabel,
                    formatMoney(
                        fmt, line.rateThousandthsPerUnit, report.currencyCode),
                  )),
                  subtitle:
                      Text(formatDistance(fmt, line.distanceMetres, unit)),
                  trailing: Text(
                    formatMoney(fmt, line.deductionMinor, report.currencyCode),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ),
          const SizedBox(height: PulseTokens.s3),
          PulseCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calculate_outlined),
              title: Text(l10n.reportTotalDeduction),
              trailing: Text(
                formatMoney(fmt, report.deductionMinor, report.currencyCode),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(
    BuildContext context,
    AppLocalizations l10n,
    MileageReport report, {
    required bool csv,
  }) async {
    final text = csv ? mileageReportToCsv(report) : mileageReportToJson(report);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(l10n.reportCopied)));
  }
}

/// A compliance banner encoded redundantly (icon + text label), never colour
/// alone: compliant vs a reconstructed-trip count.
class _ComplianceBanner extends StatelessWidget {
  const _ComplianceBanner({
    required this.report,
    required this.l10n,
    required this.fmt,
  });

  final MileageReport report;
  final AppLocalizations l10n;
  final NumeralFormat fmt;

  @override
  Widget build(BuildContext context) {
    final compliant = report.isCompliant;
    final businessUse =
        formatBusinessUse(fmt, report.rollup.businessUseBasisPoints);
    return PulseCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(compliant
                  ? Icons.verified_outlined
                  : Icons.report_problem_outlined),
              const SizedBox(width: PulseTokens.s2),
              Expanded(
                child: Text(
                  compliant
                      ? l10n.reportCompliant
                      : l10n.reportNonContemporaneous(
                          fmt.formatInt(report.nonContemporaneousCount)),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (businessUse != null) ...[
            const SizedBox(height: PulseTokens.s1),
            Text(l10n.reportBusinessUse(businessUse)),
          ],
        ],
      ),
    );
  }
}
