/// Engine running time, stored canonically as **whole minutes**. Decimal hours
/// are a display projection computed only at the edge — engine-time is never
/// stored as a `double`.
final class EngineHours implements Comparable<EngineHours> {
  /// Trusted construction from canonical whole minutes.
  const EngineHours.minutes(this.minutes);

  /// From decimal hours (display unit); rounded to the nearest minute.
  EngineHours.fromHours(double hours)
      : minutes = (hours * _minutesPerHour).round();

  /// Canonical storage form.
  final int minutes;

  static const int _minutesPerHour = 60;

  /// The engine time in decimal hours (edge conversion).
  double get hours => minutes / _minutesPerHour;

  /// Sum of two durations.
  EngineHours operator +(EngineHours other) =>
      EngineHours.minutes(minutes + other.minutes);

  /// Difference of two durations.
  EngineHours operator -(EngineHours other) =>
      EngineHours.minutes(minutes - other.minutes);

  @override
  int compareTo(EngineHours other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is EngineHours && other.minutes == minutes;

  @override
  int get hashCode => minutes.hashCode;

  @override
  String toString() => 'EngineHours(${minutes}min)';
}
