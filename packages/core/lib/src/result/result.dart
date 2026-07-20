import 'failures.dart';

/// A Dart 3 sealed, zero-dependency `Result` type.
///
/// Every repository, use-case, service, and canonical engine returns a
/// [Result] instead of throwing across a boundary. Callers `switch` on it
/// exhaustively (no `default:`) so that adding a new failure branch is a
/// compile-time error until every consumer handles it.
///
/// Exceptions are reserved for *bugs*; expected failures are typed [Failure]
/// values carried by [Err].
sealed class Result<T, F extends Failure> {
  const Result();

  /// Wrap a success value.
  const factory Result.ok(T value) = Ok<T, F>;

  /// Wrap a typed failure.
  const factory Result.err(F failure) = Err<T, F>;
}

/// The success branch of a [Result].
final class Ok<T, F extends Failure> extends Result<T, F> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, F> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T, F>, value);

  @override
  String toString() => 'Ok($value)';
}

/// The failure branch of a [Result].
final class Err<T, F extends Failure> extends Result<T, F> {
  const Err(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      other is Err<T, F> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T, F>, failure);

  @override
  String toString() => 'Err($failure)';
}

/// Ergonomic combinators. Kept as extensions instead of pulling a package —
/// the sealed spine above is the whole contract; these are convenience.
extension ResultX<T, F extends Failure> on Result<T, F> {
  /// True when this is an [Ok].
  bool get isOk => this is Ok<T, F>;

  /// True when this is an [Err].
  bool get isErr => this is Err<T, F>;

  /// The success value, or `null` when this is an [Err].
  T? get valueOrNull => switch (this) {
        Ok(:final value) => value,
        Err() => null,
      };

  /// The failure, or `null` when this is an [Ok].
  F? get failureOrNull => switch (this) {
        Ok() => null,
        Err(:final failure) => failure,
      };

  /// Collapse both branches into a single [R].
  R fold<R>(R Function(T value) onOk, R Function(F failure) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  /// Transform the success value, preserving the failure branch untouched.
  Result<R, F> map<R>(R Function(T value) transform) => switch (this) {
        Ok(:final value) => Ok(transform(value)),
        Err(:final failure) => Err(failure),
      };

  /// Transform the failure, preserving the success branch untouched.
  Result<T, G> mapErr<G extends Failure>(G Function(F failure) transform) =>
      switch (this) {
        Ok(:final value) => Ok(value),
        Err(:final failure) => Err(transform(failure)),
      };

  /// Chain another fallible step onto a success (monadic bind).
  Result<R, F> flatMap<R>(Result<R, F> Function(T value) transform) =>
      switch (this) {
        Ok(:final value) => transform(value),
        Err(:final failure) => Err(failure),
      };

  /// Alias for [flatMap], reading naturally in pipelines.
  Result<R, F> then<R>(Result<R, F> Function(T value) transform) =>
      flatMap(transform);

  /// The success value, or [fallback] when this is an [Err].
  T getOrElse(T Function(F failure) fallback) => switch (this) {
        Ok(:final value) => value,
        Err(:final failure) => fallback(failure),
      };
}
