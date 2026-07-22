import 'package:core/core.dart';
import 'package:l10n/l10n.dart';

/// Render a [ByteSize] with the user's numerals + a localized unit (F8-T8).
/// The number is scaled + formatted by the numeral engine; the unit label and
/// placement come from the `byteSize` ARB template (RTL-safe, no widget-side
/// concatenation).
String formatByteSize(AppLocalizations l, NumeralFormat fmt, ByteSize size) {
  final f = size.format();
  return l.byteSize(
      f.unit.name, fmt.formatScaled(f.mantissa, f.fractionDigits));
}
