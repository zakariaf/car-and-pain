import 'package:core/core.dart';

/// A car cost as the repository emits it (Drift-free, M6-T1). Money is integer
/// minor units keyed to the currency exponent; [amountMinor] is signed (refunds
/// net negative). A dated-FX triple, when present, carries the base-currency
/// amount so a historical entry never re-converts at today's rate. A polymorphic
/// source link marks a row projected from another module (fuel/service/tire) so
/// it is never double-counted against that module's own total.
class Expense {
  const Expense({
    required this.id,
    required this.vehicleId,
    required this.spentAt,
    required this.amountMinor,
    required this.currencyCode,
    this.categoryId,
    this.odometerMetres,
    this.notes,
    this.driverId,
    this.fxRateThousandths,
    this.fxAsOf,
    this.baseAmountMinor,
    this.sourceEntityType,
    this.sourceEntityId,
    this.receiptAttachmentId,
    this.tags = const [],
    this.entryCalendar,
  });

  final String id;
  final String vehicleId;
  final Instant spentAt;
  final int amountMinor;
  final String currencyCode;
  final String? categoryId;
  final int? odometerMetres;
  final String? notes;
  final String? driverId;
  final int? fxRateThousandths;
  final int? fxAsOf;
  final int? baseAmountMinor;
  final String? sourceEntityType;
  final String? sourceEntityId;
  final String? receiptAttachmentId;
  final List<String> tags;
  final String? entryCalendar;

  /// True when this row was projected from another module (and so must not be
  /// re-counted against that module's own total).
  bool get isProjected => sourceEntityType != null;

  /// The amount expressed in the base currency: the dated-FX base amount when the
  /// entry was in a foreign currency, else the amount itself (already base).
  int get baseAmountOrSelf => baseAmountMinor ?? amountMinor;
}
