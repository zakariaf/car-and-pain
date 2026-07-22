/// Display unit for a [ByteSize]. Canonical storage is always whole bytes.
enum ByteSizeUnit { b, kb, mb, gb, tb }

/// A file/storage size, stored canonically as **whole bytes**. The KB/MB/GB
/// projection is computed only at the presentation edge — never stored — and
/// deliberately yields a *scaled integer mantissa* + fraction-digit count so the
/// `l10n` numeral formatter can render it with locale-correct digits, grouping
/// and decimal mark (invariant #6: convert at the edge; no display strings here).
///
/// Base is **1024** (binary) with the conventional KB/MB labels; sizes below
/// 1 KiB show as whole bytes, larger sizes show one decimal.
final class ByteSize implements Comparable<ByteSize> {
  const ByteSize(this.bytes);

  /// Canonical storage form — whole bytes.
  final int bytes;

  static const int _step = 1024;
  static const List<ByteSizeUnit> _tiers = [
    ByteSizeUnit.b,
    ByteSizeUnit.kb,
    ByteSizeUnit.mb,
    ByteSizeUnit.gb,
    ByteSizeUnit.tb,
  ];

  /// Project to a display tier: the unit, an integer `mantissa` already scaled
  /// by `10^fractionDigits`, and `fractionDigits`. Feed `mantissa` +
  /// `fractionDigits` straight into `NumeralFormat.formatScaled`.
  ///
  /// e.g. `12_897_485 bytes → (mb, mantissa: 123, fractionDigits: 1)` → "12.3".
  ({ByteSizeUnit unit, int mantissa, int fractionDigits}) format() {
    final abs = bytes.abs();
    // Bytes: no unit division, no decimals.
    if (abs < _step) {
      return (unit: ByteSizeUnit.b, mantissa: bytes, fractionDigits: 0);
    }
    // Find the largest tier whose divisor still leaves a value >= 1.
    var tier = 1;
    var divisor = _step;
    while (tier < _tiers.length - 1 && abs >= divisor * _step) {
      divisor *= _step;
      tier++;
    }
    // One decimal place: mantissa = round(value * 10) = round(bytes*10 / divisor).
    final sign = bytes.isNegative ? -1 : 1;
    final mantissa = sign * ((abs * 10 + divisor ~/ 2) ~/ divisor);
    return (unit: _tiers[tier], mantissa: mantissa, fractionDigits: 1);
  }

  ByteSize operator +(ByteSize other) => ByteSize(bytes + other.bytes);

  @override
  int compareTo(ByteSize other) => bytes.compareTo(other.bytes);

  @override
  bool operator ==(Object other) => other is ByteSize && other.bytes == bytes;

  @override
  int get hashCode => bytes.hashCode;

  @override
  String toString() => 'ByteSize($bytes bytes)';
}
