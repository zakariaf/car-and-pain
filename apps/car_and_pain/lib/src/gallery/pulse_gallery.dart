import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:l10n/l10n.dart';

/// The PULSE component gallery (F3-T9) — a dev/QA surface enumerating the vital,
/// urgency pills, cards, stat tiles, charts and buttons, with **live theme /
/// directionality / reduced-motion toggles**. Doubles as the manual QA surface.
/// (Dev tool: a few section labels are literal; user-facing component strings
/// resolve via `pulseLabel`.)
class PulseGallery extends StatefulWidget {
  const PulseGallery({super.key});

  @override
  State<PulseGallery> createState() => _PulseGalleryState();
}

class _PulseGalleryState extends State<PulseGallery> {
  Brightness _brightness = Brightness.light;
  TextDirection _direction = TextDirection.ltr;
  bool _reduce = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Theme(
      data: pulseTheme(_brightness),
      child: Builder(
        builder: (context) {
          final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
          return ReducedMotionScope(
            reduce: _reduce,
            child: Directionality(
              textDirection: _direction,
              child: Scaffold(
                backgroundColor: pc.base,
                appBar: AppBar(
                  title: Text(l10n.appTitle),
                  actions: [
                    IconButton(
                      tooltip: 'Theme',
                      icon: Icon(
                        _brightness == Brightness.light
                            ? Icons.dark_mode_outlined
                            : Icons.light_mode_outlined,
                      ),
                      onPressed: () => setState(() {
                        _brightness = _brightness == Brightness.light
                            ? Brightness.dark
                            : Brightness.light;
                      }),
                    ),
                    IconButton(
                      tooltip: 'Direction',
                      icon: const Icon(Icons.format_textdirection_r_to_l),
                      onPressed: () => setState(() {
                        _direction = _direction == TextDirection.ltr
                            ? TextDirection.rtl
                            : TextDirection.ltr;
                      }),
                    ),
                    IconButton(
                      tooltip: 'Reduce motion',
                      icon: Icon(
                        _reduce
                            ? Icons.motion_photos_off_outlined
                            : Icons.motion_photos_on_outlined,
                      ),
                      onPressed: () => setState(() => _reduce = !_reduce),
                    ),
                  ],
                ),
                body: ListView(
                  padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
                  children: [
                    VitalHero(
                      semanticsLabel: '${l10n.urgencyCalm} 92 / 100',
                      aggregate: Urgency.soon,
                    ),
                    const SizedBox(height: PulseTokens.s4),
                    Wrap(
                      spacing: PulseTokens.s2,
                      runSpacing: PulseTokens.s2,
                      children: [
                        for (final u in Urgency.values)
                          StatusPill(
                              urgency: u, label: pulseLabel(l10n, u.labelKey)),
                      ],
                    ),
                    const SizedBox(height: PulseTokens.s4),
                    PulseCard(
                      urgency: Urgency.overdue,
                      child: Text(l10n.urgencyOverdue,
                          style: Theme.of(context).textTheme.titleLarge),
                    ),
                    const SizedBox(height: PulseTokens.s2),
                    const PulseCard(child: Text('Calm card')),
                    const SizedBox(height: PulseTokens.s4),
                    const Row(
                      children: [
                        StatTile(value: '84,320', label: 'km'),
                        SizedBox(width: PulseTokens.s4),
                        StatTile(value: '6.4', label: 'L/100'),
                        SizedBox(width: PulseTokens.s4),
                        StatTile(value: '0.31', label: 'per km'),
                      ],
                    ),
                    const SizedBox(height: PulseTokens.s4),
                    const PulseLineChart(
                      series: [6.9, 6.7, 6.6, 6.4, 6.5, 6.3],
                      semanticsSummary: 'Economy trending down',
                    ),
                    const SizedBox(height: PulseTokens.s4),
                    const PulseBarChart(
                      values: [231, 120, 60, 40],
                      semanticsSummary: 'Fuel is the largest cost',
                    ),
                    const SizedBox(height: PulseTokens.s4),
                    Row(
                      children: [
                        PulseButton(label: l10n.trashRestore, onPressed: () {}),
                        const SizedBox(width: PulseTokens.s2),
                        PulseButton(
                          label: l10n.startupErrorRetry,
                          variant: PulseButtonVariant.ghost,
                          onPressed: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
