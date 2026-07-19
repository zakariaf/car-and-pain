// Accumulative (applicative) validation with normalize-BEFORE-parse.
// Eastern-Arabic/Persian digits + the Persian decimal (٫) and grouping (٬)
// separators are normalized to ASCII, and Jalali/Hijri dates are resolved to a
// canonical UTC instant, BEFORE any parse — so a FormatException never escapes
// as a crash on valid-looking input. Errors ACCUMULATE, not fail-fast.

import 'package:core/core.dart'; // Result, Ok, Err, ValidationFailure, FieldError

// FieldError carries a field name + a STABLE reason code — never a localized string.
// The form maps the reason code to a gen-l10n message at the presentation edge.

Result<FuelEntry, ValidationFailure> validateFill(RawFillForm raw) {
  final errors = <FieldError>[];

  final liters = _decimal(raw.liters, 'liters', errors); // ٱrabic digits + ٫/٬ -> ASCII
  final odometer = _odometer(raw.odometer, 'odometer', errors);
  final at = _instant(raw.date, raw.calendar, 'date', errors); // Jalali/Hijri -> UTC

  // Applicative: collect ALL field errors, then decide once.
  if (errors.isNotEmpty) return Err(ValidationFailure(errors));
  return Ok(FuelEntry(liters: liters!, odometer: odometer!, at: at!));
}

double? _decimal(String rawInput, String field, List<FieldError> errors) {
  final ascii = normalizeNumerals(rawInput) // ۰-۹ / ٠-٩ -> 0-9, ٫ -> '.', ٬ -> ''
      .trim();
  final v = double.tryParse(ascii); // tryParse: never throws FormatException
  if (v == null || v <= 0) {
    errors.add(FieldError(field, 'not_a_positive_number'));
    return null;
  }
  return v;
}

int? _odometer(String rawInput, String field, List<FieldError> errors) {
  final v = int.tryParse(normalizeNumerals(rawInput).trim());
  if (v == null || v < 0) {
    errors.add(FieldError(field, 'not_a_number'));
    return null;
  }
  return v;
}

DateTime? _instant(
    String rawDate, CalendarSystem cal, String field, List<FieldError> errors) {
  // resolveToInstant normalizes numerals then converts Gregorian/Jalali/Hijri -> UTC.
  // It RETURNS null on malformed input rather than throwing.
  final at = resolveToInstant(rawDate, cal);
  if (at == null) {
    errors.add(FieldError(field, 'invalid_date'));
    return null;
  }
  return at;
}
