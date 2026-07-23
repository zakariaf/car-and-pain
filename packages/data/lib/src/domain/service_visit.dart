import 'package:core/core.dart';

/// One job within a service visit, Drift-free. The service type resolves through
/// the shared taxonomy (`serviceTypeId`); interval columns override the taxonomy
/// default (null = inherit). Cost is the labour-vs-parts split in minor units.
class ServiceLineItem {
  const ServiceLineItem({
    required this.id,
    required this.visitId,
    this.serviceTypeId,
    this.labourMinor = 0,
    this.partsMinor = 0,
    this.resetsInterval = true,
    this.isDiy,
    this.intervalDistanceMetres,
    this.intervalMonths,
    this.intervalLogic,
    this.sortOrder = 0,
    this.notes,
  });

  final String id;
  final String visitId;
  final String? serviceTypeId;
  final int labourMinor;
  final int partsMinor;
  final bool resetsInterval;

  /// Per-item DIY override; null = inherit the visit-level flag.
  final bool? isDiy;
  final int? intervalDistanceMetres;
  final int? intervalMonths;

  /// distance | time | whicheverFirst (null = inherit the taxonomy default).
  final String? intervalLogic;
  final int sortOrder;
  final String? notes;
}

/// A line item as supplied to `ServiceRepository.add` before it has an id.
class ServiceLineItemDraft {
  const ServiceLineItemDraft({
    this.serviceTypeId,
    this.labourMinor = 0,
    this.partsMinor = 0,
    this.resetsInterval = true,
    this.isDiy,
    this.intervalDistanceMetres,
    this.intervalMonths,
    this.intervalLogic,
    this.notes,
  });

  final String? serviceTypeId;
  final int labourMinor;
  final int partsMinor;
  final bool resetsInterval;
  final bool? isDiy;
  final int? intervalDistanceMetres;
  final int? intervalMonths;
  final String? intervalLogic;
  final String? notes;
}

/// A multi-line service visit as repositories emit it (Drift-free). All measures
/// canonical: money integer minor units + ISO code, distance metres, instants
/// UTC. `totalCostMinor` is the authoritative cached visit total.
class ServiceVisit {
  const ServiceVisit({
    required this.id,
    required this.vehicleId,
    required this.servicedAt,
    required this.totalCostMinor,
    required this.currencyCode,
    this.lineItems = const [],
    this.odometerMetres,
    this.providerId,
    this.isDiy = false,
    this.taxMinor = 0,
    this.discountMinor = 0,
    this.feesMinor = 0,
    this.labourMinutes,
    this.labourRateMinor,
    this.tags = const [],
    this.source = 'manual',
    this.scheduleProfile,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final Instant servicedAt;
  final int? odometerMetres;
  final int totalCostMinor;
  final String currencyCode;
  final String? providerId;
  final bool isDiy;
  final int taxMinor;
  final int discountMinor;
  final int feesMinor;
  final int? labourMinutes;
  final int? labourRateMinor;
  final List<String> tags;
  final String source;
  final String? scheduleProfile;
  final String? notes;
  final List<ServiceLineItem> lineItems;

  /// The pure-engine cost view (M4-T10) — labour/parts per line item plus the
  /// header tax/discount/fees.
  VisitCost toVisitCost() => VisitCost(
        lineItems: [
          for (final li in lineItems)
            ServiceLineItemCost(
              labourMinor: li.labourMinor,
              partsMinor: li.partsMinor,
            ),
        ],
        taxMinor: taxMinor,
        discountMinor: discountMinor,
        feesMinor: feesMinor,
      );
}
