/// The time port. Every time-reading engine takes a [Clock] so that
/// `DateTime.now()` never appears inside business logic — the single sanctioned
/// place it is called is [SystemClock]. Tests inject [FixedClock] for
/// deterministic, `fake_async`-free instants.
///
/// [nowUtc] always returns a UTC instant; wall-clock/local rendering happens at
/// the presentation edge in `l10n`, never here.
abstract interface class Clock {
  /// The current instant, in UTC.
  DateTime nowUtc();
}

/// The real clock. The one sanctioned caller of `DateTime.now()` in the app.
final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

/// A frozen clock for tests and deterministic reproduction.
final class FixedClock implements Clock {
  FixedClock(DateTime instant) : _instant = instant.toUtc();

  final DateTime _instant;

  @override
  DateTime nowUtc() => _instant;
}
