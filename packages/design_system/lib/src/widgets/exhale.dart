import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import '../theme/pulse_motion.dart';
import '../theme/urgency.dart';
import '../util/reduced_motion.dart';

/// Cool exactly one urgency notch, clamped at calm (u0).
Urgency coolOneNotch(Urgency u) => Urgency.values[math.max(0, u.index - 1)];

/// The exhale (F3-T5): the single reusable payoff on every relieving action
/// (mark done, log the overdue fill, clear an alert). The **weighted haptic**
/// and **one-notch cooling** are preserved under reduced-motion — only the
/// [ExhaleSettle] animation is skipped. Modules never reimplement this.
abstract final class Exhale {
  /// Fire the haptic, cool one notch, and announce relief. Returns the cooled
  /// urgency (the caller updates its state, flipping the status icon+label in
  /// the same frame). [announce] is the caller-localized relief sentence.
  static Future<Urgency> play(
    BuildContext context, {
    required Urgency from,
    required String announce,
  }) async {
    unawaited(HapticFeedback.mediumImpact()); // accessible confirmation channel
    // ignore: deprecated_member_use — announce is the stable a11y path on 3.44.
    unawaited(SemanticsService.announce(announce, Directionality.of(context)));
    return coolOneNotch(from);
  }
}

/// Plays the soft settle (scale 1.0 → 0.985 → 1.0 over 420ms) when [trigger]
/// changes. Under reduced-motion it is a no-op — the cooling + haptic in
/// [Exhale.play] still convey completion.
class ExhaleSettle extends StatefulWidget {
  const ExhaleSettle({required this.trigger, required this.child, super.key});

  /// Bump this (e.g. a counter) to play the settle once.
  final int trigger;
  final Widget child;

  @override
  State<ExhaleSettle> createState() => _ExhaleSettleState();
}

class _ExhaleSettleState extends State<ExhaleSettle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: PulseMotion.exhale);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1, end: 0.985), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.985, end: 1), weight: 1),
  ]).animate(
      CurvedAnimation(parent: _controller, curve: PulseMotion.exhaleEase));

  @override
  void didUpdateWidget(ExhaleSettle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trigger != widget.trigger && !reduceMotion(context)) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
