import 'package:core/core.dart';

/// A booked service appointment (M4-T5), Drift-free. [scheduledAt] is a true
/// instant; the device calendar renders it in the user's locale via the `.ics`.
class ServiceAppointment {
  const ServiceAppointment({
    required this.id,
    required this.vehicleId,
    required this.scheduledAt,
    this.providerId,
    this.durationMinutes = 60,
    this.status = 'scheduled',
    this.title,
    this.notes,
  });

  final String id;
  final String vehicleId;
  final Instant scheduledAt;
  final String? providerId;
  final int durationMinutes;

  /// scheduled | completed | cancelled | noShow.
  final String status;
  final String? title;
  final String? notes;

  bool get isActive => status == 'scheduled';
}

/// A warranty limit surfaced for the shared warranty-expiry reminder surface
/// (M4-T5), lifted from a part or a line item's workmanship warranty. Tracked by
/// both date and mileage so either can drive an expiry reminder.
class WarrantyExpiry {
  const WarrantyExpiry({
    required this.source,
    required this.label,
    required this.visitId,
    this.untilDate,
    this.untilMileageMetres,
  });

  /// 'part' | 'workmanship'.
  final String source;

  /// The part name, or the line item's service-type id (resolved at the edge).
  final String label;
  final String visitId;
  final int? untilDate;
  final int? untilMileageMetres;
}
