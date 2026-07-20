import 'failures.dart';
import 'result.dart';

/// A single field-level validation error.
///
/// Carries a [field] identifier and a stable [code] (e.g. `not_a_number`) —
/// **never** a user-facing string. The presentation layer localizes from the
/// pair. Optional typed [params] provide context for ICU messages.
final class FieldError {
  const FieldError(this.field, this.code, [this.params = const {}]);

  final String field;
  final String code;
  final Map<String, Object?> params;

  @override
  bool operator ==(Object other) =>
      other is FieldError &&
      other.field == field &&
      other.code == code &&
      _mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(field, code, Object.hashAll(params.values));

  @override
  String toString() => 'FieldError($field, $code)';
}

/// Accumulates field errors applicatively (all of them, not fail-fast) and
/// resolves to a typed [Result].
///
/// Validators call [add] for every problem they find, then [build] to collapse:
/// `Ok(value)` when clean, `Err(ValidationFailure(errors))` otherwise. This is
/// the boundary that turns "crash on valid-looking input" into a typed failure
/// — numerals and `٫`/`٬` separators are normalized to ASCII upstream in l10n.
final class Validation {
  Validation();

  final List<FieldError> _errors = [];

  /// Whether any error has been accumulated.
  bool get hasErrors => _errors.isNotEmpty;

  /// The accumulated errors, in insertion order.
  List<FieldError> get errors => List.unmodifiable(_errors);

  /// Record a field error and continue (never throws, never short-circuits).
  void add(String field, String code,
      [Map<String, Object?> params = const {}]) {
    _errors.add(FieldError(field, code, params));
  }

  /// Collapse into a [Result]: [value] on success, else a [ValidationFailure].
  Result<T, ValidationFailure> build<T>(T value) =>
      hasErrors ? Err(ValidationFailure(errors)) : Ok(value);
}

bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (final key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) return false;
  }
  return true;
}
