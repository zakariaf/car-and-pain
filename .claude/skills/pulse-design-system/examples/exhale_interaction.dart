// THE EXHALE — the payoff fired on every pain-relieving action (log, mark-done,
// clear, close). Cooling is NEVER the only success signal: the icon+label flip
// and the haptic + SR announcement always happen, even under reduced motion.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
// import 'pulse_theme.dart';
// import 'urgency_value_object.dart';

bool reduceMotion(BuildContext c) =>
    MediaQuery.maybeDisableAnimationsOf(c) ?? false;

/// Call on completion. Order matters: haptic + status flip first (accessible,
/// always), animation only when motion is allowed.
Future<void> exhale(
  BuildContext context, {
  required ValueNotifier<int> cardUrgency,   // the resolved card's u
  required ValueNotifier<int> haloUrgency,   // the aggregate halo u
  required VoidCallback markDoneInDb,        // DB write → Drift stream re-emits
  required String announce,                  // "Oil & filter marked done. Readiness now 97."
}) async {
  // 1. Weighted haptic — the accessible confirmation channel, identical LTR/RTL,
  //    preserved under reduced motion.
  await HapticFeedback.mediumImpact();

  // 2. Persist. The Drift + SQLCipher DB is the source of truth; the stream
  //    re-emits and the hero recomputes its score.
  markDoneInDb();

  // 3. Status flips NOW (same frame the cool begins): icon + label change from
  //    e.g. ⚠ Overdue → ✓ Done, so a colour-blind user still reads the change.
  cardUrgency.value = 0;                      // card cools to calm
  haloUrgency.value =
      (haloUrgency.value - 1).clamp(0, 2);    // halo eases AT MOST one stop, capped at u2

  // 4. Announce for screen readers (parallels the haptic).
  SemanticsService.announce(announce, Directionality.of(context));

  // 5. Motion: skip entirely under reduced motion (values are already set).
  if (reduceMotion(context)) return;
  // else: the VitalCard's AnimatedContainer cross-fades border/tint/stripe over
  // PulseTokens.cool, the ExhaleSettle wrapper runs a 420ms scale dip, and the
  // hero CountUpNumeral rolls UP to the new score over PulseTokens.countUp.
}

/// The soft "settle" — card scales 1.0 → 0.985 → 1.0 on the exhale curve.
class ExhaleSettle extends StatefulWidget {
  const ExhaleSettle({super.key, required this.child, required this.trigger});
  final Widget child;
  final Listenable trigger; // fire to replay the settle
  @override
  State<ExhaleSettle> createState() => _ExhaleSettleState();
}

class _ExhaleSettleState extends State<ExhaleSettle>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: PulseTokens.exhaleSettle);
  late final _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.985), weight: 1),
    TweenSequenceItem(tween: Tween(begin: 0.985, end: 1.0), weight: 1),
  ]).animate(CurvedAnimation(parent: _c, curve: PulseTokens.exhaleEase));

  @override
  void initState() {
    super.initState();
    widget.trigger.addListener(_run);
  }

  void _run() {
    if (reduceMotion(context)) return; // no scale under reduced motion
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    widget.trigger.removeListener(_run);
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScaleTransition(scale: _scale, child: widget.child);
}
