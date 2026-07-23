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
    this.warrantyUntilDate,
    this.warrantyUntilMileageMetres,
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

  /// Workmanship warranty (M4-T2), tracked by both date and mileage.
  final int? warrantyUntilDate;
  final int? warrantyUntilMileageMetres;
}

/// A part fitted during a line item, Drift-free (M4-T2). Part numbers stay LTR.
class PartUsed {
  const PartUsed({
    required this.id,
    required this.lineItemId,
    required this.name,
    this.brand,
    this.oemNumber,
    this.aftermarketNumber,
    this.quantity = 1,
    this.unitCostMinor = 0,
    this.supplier,
    this.warrantyUntilDate,
    this.warrantyUntilMileageMetres,
  });

  final String id;
  final String lineItemId;
  final String name;
  final String? brand;
  final String? oemNumber;
  final String? aftermarketNumber;
  final int quantity;
  final int unitCostMinor;
  final String? supplier;
  final int? warrantyUntilDate;
  final int? warrantyUntilMileageMetres;

  /// Total cost of this part line (unit × quantity), integer minor units.
  int get totalCostMinor => unitCostMinor * quantity;
}

/// A fluid/consumable used during a line item (M4-T2), Drift-free.
class FluidUsed {
  const FluidUsed({
    required this.id,
    required this.lineItemId,
    required this.fluidType,
    this.spec,
    this.quantityMl,
  });

  final String id;
  final String lineItemId;
  final String fluidType;
  final String? spec;
  final int? quantityMl;
}

/// One ordered DIY procedure step (M4-T2), Drift-free.
class ProcedureStep {
  const ProcedureStep({
    required this.id,
    required this.lineItemId,
    required this.stepOrder,
    required this.instruction,
    this.torqueSpec,
    this.notes,
  });

  final String id;
  final String lineItemId;
  final int stepOrder;
  final String instruction;
  final String? torqueSpec;
  final String? notes;
}

/// A part as supplied to `ServiceRepository.add` before it has an id.
class PartDraft {
  const PartDraft({
    required this.name,
    this.brand,
    this.oemNumber,
    this.aftermarketNumber,
    this.quantity = 1,
    this.unitCostMinor = 0,
    this.supplier,
    this.warrantyUntilDate,
    this.warrantyUntilMileageMetres,
  });

  final String name;
  final String? brand;
  final String? oemNumber;
  final String? aftermarketNumber;
  final int quantity;
  final int unitCostMinor;
  final String? supplier;
  final int? warrantyUntilDate;
  final int? warrantyUntilMileageMetres;
}

/// A fluid as supplied to `ServiceRepository.add`.
class FluidDraft {
  const FluidDraft({required this.fluidType, this.spec, this.quantityMl});

  final String fluidType;
  final String? spec;
  final int? quantityMl;
}

/// A procedure step as supplied to `ServiceRepository.add` (order = list index).
class ProcedureStepDraft {
  const ProcedureStepDraft({
    required this.instruction,
    this.torqueSpec,
    this.notes,
  });

  final String instruction;
  final String? torqueSpec;
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
    this.warrantyUntilDate,
    this.warrantyUntilMileageMetres,
    this.parts = const [],
    this.fluids = const [],
    this.procedureSteps = const [],
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
  final int? warrantyUntilDate;
  final int? warrantyUntilMileageMetres;
  final List<PartDraft> parts;
  final List<FluidDraft> fluids;
  final List<ProcedureStepDraft> procedureSteps;
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
