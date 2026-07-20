import 'package:flutter/widgets.dart';

/// App-level "reduce motion" preference, provided above the widget tree (owned
/// by Settings; F3 only reads it). Defaults to `false` when absent.
class ReducedMotionScope extends InheritedWidget {
  const ReducedMotionScope({
    required this.reduce,
    required super.child,
    super.key,
  });

  final bool reduce;

  static bool prefOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReducedMotionScope>()
          ?.reduce ??
      false;

  @override
  bool updateShouldNotify(ReducedMotionScope oldWidget) =>
      oldWidget.reduce != reduce;
}

/// The pure OR-combination: OS `disableAnimations` OR the app preference. Kept
/// separate so the truth table is unit-testable without a `BuildContext`.
bool resolveReducedMotion({
  required bool osDisableAnimations,
  required bool appPreference,
}) =>
    osDisableAnimations || appPreference;

/// The single motion gate the whole library consults (F3-T11). Combines the OS
/// `MediaQuery.disableAnimations` signal with the app-level preference; every
/// animated surface (vital, exhale, room transitions, charts) uses THIS — no
/// ad-hoc checks.
bool reduceMotion(BuildContext context) => resolveReducedMotion(
      osDisableAnimations:
          MediaQuery.maybeDisableAnimationsOf(context) ?? false,
      appPreference: ReducedMotionScope.prefOf(context),
    );
