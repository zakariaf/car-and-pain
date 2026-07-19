// The scoped-temperature ache card: concentrated warmth (its own true u, up to
// u4) that never bleeds into the whole field. Status is spoken (Semantics), shown
// as icon+label (StatusPill), and shaped (UrgencyStripe) + positioned — never
// colour-only. RTL is handled by Directional geometry.
import 'package:flutter/material.dart';
// import 'pulse_theme.dart';
// import 'urgency_value_object.dart';

class VitalCard extends StatelessWidget {
  const VitalCard({
    super.key,
    required this.u,
    required this.icon,
    required this.title,
    required this.detail,
    this.actions = const [],
  });

  final Urgency u;
  final IconData icon;
  final String title;
  final String detail;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final pc = PulseTokens.of(context);
    final dir = Directionality.of(context);
    // final l = AppLocalizations.of(context);

    return Semantics(
      container: true,
      label: '$title, ${u.label(/*l*/ null)}. $detail', // status SPOKEN, not by colour
      child: AnimatedContainer(
        duration: PulseTokens.cool,               // 520ms one-notch cool on the exhale
        curve: PulseTokens.exhaleEase,            // Cubic(.2,.7,.2,1)
        decoration: BoxDecoration(
          color: pc.surface,
          borderRadius: BorderRadius.circular(PulseTokens.rCard),
          border: Border.all(color: _borderTint(pc)),
          boxShadow: _cardShadow(context),        // day drop-shadow / night hairline
        ),
        child: Stack(children: [
          // Redundant channel 3 — the stripe SHAPE encodes urgency (start edge).
          PositionedDirectional(
            start: 0, top: 14, bottom: 14,
            child: UrgencyStripe(u: u, width: 4), // solid → dashed → tighter
          ),
          // Ambient corner wash — DECORATION, under content, ignores pointer.
          Positioned.fill(child: IgnorePointer(child: _CornerTint(u: u))),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(18, 16, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(icon, color: pc.text2),                 // part glyph
                  const SizedBox(width: 8),
                  Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
                  StatusPill(u: u),                            // icon + WORD (redundant)
                ]),
                const SizedBox(height: 4),
                Text(detail, style: Theme.of(context).textTheme.labelLarge),
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Row(children: actions), // Mark done (→ exhale) · Snooze · Skip
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Color _borderTint(PulseColors pc) =>
      u.u >= 2 ? PulseTokens.temp[u.u].withValues(alpha: .55) : pc.hairline;

  List<BoxShadow> _cardShadow(BuildContext c) =>
      Theme.of(c).brightness == Brightness.dark
          ? const [] // night = hairline border only (set above); no drop shadow
          : const [BoxShadow(color: Color(0x12141E28), blurRadius: 24, offset: Offset(0, 6))];
}

// --- Placeholder atoms (real versions live in packages/design_system) ---
class UrgencyStripe extends StatelessWidget {
  const UrgencyStripe({super.key, required this.u, required this.width});
  final Urgency u; final double width;
  @override
  Widget build(BuildContext context) => SizedBox(width: width); // CustomPaint in real impl
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.u});
  final Urgency u;
  @override
  Widget build(BuildContext context) {
    final pc = PulseTokens.of(context);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 4, 10, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(PulseTokens.rPill),
        border: Border.all(color: u.textTone(pc).withValues(alpha: .45)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(u.icon, size: 12, color: u.textTone(pc)),          // SHAPE = redundant
        const SizedBox(width: 6),
        Text(u.label(/*l*/ null), style: TextStyle(color: u.textTone(pc), fontSize: 11.5, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _CornerTint extends StatelessWidget {
  const _CornerTint({required this.u});
  final Urgency u;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: AlignmentDirectional.topEnd.resolve(Directionality.of(context)),
            radius: 1.2,
            colors: [PulseTokens.temp[u.u].withValues(alpha: .14), Colors.transparent],
          ),
        ),
      );
}
