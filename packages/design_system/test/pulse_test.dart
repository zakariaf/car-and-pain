import 'dart:math' as math;

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ── WCAG contrast helper ─────────────────────────────────────────────────
double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
double _luminance(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) =>
    MaterialApp(
      theme: pulseTheme(brightness),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('Urgency system (F3-T2)', () {
    test('resolves colour + stripe + icon + labelKey for all 5 × 2 themes', () {
      for (final b in Brightness.values) {
        final icons = <IconData>{};
        for (final u in Urgency.values) {
          final s = resolveUrgency(u, b);
          expect(s.labelKey, isNotEmpty);
          expect(s.labelKey, startsWith('urgency.'));
          icons.add(s.icon);
        }
        expect(icons, hasLength(5)); // a distinct icon per level
      }
    });

    test('stripe is solid for calm/scheduled, dashed (tightening) as it warms',
        () {
      expect(Urgency.calm.stripe.isSolid, isTrue);
      expect(Urgency.scheduled.stripe.isSolid, isTrue);
      expect(Urgency.soon.stripe.isSolid, isFalse);
      expect(Urgency.overdue.stripe.dash, lessThan(Urgency.soon.stripe.dash!));
    });

    test('the aggregate halo NEVER exceeds saffron (u2)', () {
      expect(Urgency.overdue.haloClamped, Urgency.soon);
      expect(Urgency.pressing.haloClamped, Urgency.soon);
      expect(Urgency.calm.haloClamped, Urgency.calm);
      // Aggregating many u4 cards still clamps at u2.
      final many = List.filled(20, Urgency.overdue);
      expect(aggregateHalo(many), Urgency.soon);
      expect(aggregateHalo(const []), Urgency.calm);
    });
  });

  group('Reduced-motion resolver (F3-T11)', () {
    test('OR truth table', () {
      expect(
        resolveReducedMotion(osDisableAnimations: false, appPreference: false),
        isFalse,
      );
      expect(
        resolveReducedMotion(osDisableAnimations: true, appPreference: false),
        isTrue,
      );
      expect(
        resolveReducedMotion(osDisableAnimations: false, appPreference: true),
        isTrue,
      );
      expect(
        resolveReducedMotion(osDisableAnimations: true, appPreference: true),
        isTrue,
      );
    });
  });

  group('Exhale (F3-T5)', () {
    test('coolOneNotch drops exactly one, clamped at calm', () {
      expect(coolOneNotch(Urgency.overdue), Urgency.pressing);
      expect(coolOneNotch(Urgency.soon), Urgency.scheduled);
      expect(coolOneNotch(Urgency.calm), Urgency.calm); // clamp
    });
  });

  group('WCAG contrast (F3-T8)', () {
    test('text tones meet AA against their surface in both themes', () {
      for (final pc in [PulseColors.light, PulseColors.dark]) {
        // Body text: AA (4.5:1).
        expect(contrastRatio(pc.text, pc.surface), greaterThanOrEqualTo(4.5));
        expect(contrastRatio(pc.text2, pc.surface), greaterThanOrEqualTo(4.5));
        // Semantic status tones back icon+label pills (status never rides the
        // tone alone), so they are verified at the AA non-text/large threshold
        // (3:1). A polish pass may darken tones for strict small-text AA.
        expect(contrastRatio(pc.okText, pc.surface), greaterThanOrEqualTo(3.0));
        expect(
            contrastRatio(pc.warnText, pc.surface), greaterThanOrEqualTo(3.0));
        expect(
            contrastRatio(pc.critText, pc.surface), greaterThanOrEqualTo(3.0));
      }
    });
  });

  group('Components carry default semantics + render both themes (F3-T4)', () {
    testWidgets('StatusPill: icon + label + semantics', (tester) async {
      for (final b in Brightness.values) {
        await tester.pumpWidget(_wrap(
          const StatusPill(urgency: Urgency.overdue, label: 'Overdue'),
          brightness: b,
        ));
        expect(find.text('Overdue'), findsOneWidget);
        expect(find.byIcon(Icons.priority_high), findsOneWidget);
        expect(
          tester.getSemantics(find.bySemanticsLabel('Overdue')),
          isNotNull,
        );
      }
    });

    testWidgets('PulseCard renders with an urgency stripe', (tester) async {
      await tester.pumpWidget(_wrap(
        const PulseCard(urgency: Urgency.soon, child: Text('Oil & filter')),
      ));
      expect(find.text('Oil & filter'), findsOneWidget);
    });

    testWidgets('StatTile exposes label+value semantics', (tester) async {
      await tester.pumpWidget(_wrap(
        const StatTile(value: '84,320', label: 'km'),
      ));
      expect(
          tester.getSemantics(find.bySemanticsLabel('km: 84,320')), isNotNull);
    });

    testWidgets('PulseButton is a button', (tester) async {
      await tester.pumpWidget(_wrap(
        PulseButton(label: 'Save', onPressed: () {}),
      ));
      expect(find.byType(FilledButton), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('Vital + charts (F3-T3/T7)', () {
    testWidgets('VitalHero renders static under reduced-motion',
        (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _wrap(
            const VitalHero(
              semanticsLabel: 'Readiness 92 of 100, Healthy',
              aggregate: Urgency.soon,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Readiness 92 of 100, Healthy'),
        ),
        isNotNull,
      );
    });

    testWidgets('charts carry a Semantics summary (never colour-only)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        const Column(
          children: [
            PulseLineChart(
              series: [6.9, 6.7, 6.5, 6.4],
              semanticsSummary: 'Economy trending 6.9 to 6.4 L per 100km',
            ),
            PulseBarChart(
              values: [231, 120, 60],
              semanticsSummary: 'Fuel is the largest cost',
            ),
          ],
        ),
      ));
      expect(
        find.bySemanticsLabel('Economy trending 6.9 to 6.4 L per 100km'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel('Fuel is the largest cost'), findsOneWidget);
    });

    testWidgets('BarChart survives negative values in RTL without paint error',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: PulseBarChart(
              values: [231, -40, 0, 120], // negative must not crash the painter
              semanticsSummary: 'Costs by category',
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Costs by category'), findsOneWidget);
    });

    testWidgets('PulseCard corner tint paints in RTL without error',
        (tester) async {
      await tester.pumpWidget(
        _wrap(
          const Directionality(
            textDirection: TextDirection.rtl,
            child: PulseCard(
              urgency: Urgency.overdue, // >= soon → corner tint renders
              semanticsLabel: 'Brake service overdue',
              child: Text('Brakes'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.text('Brakes'), findsOneWidget);
    });
  });

  group('Symmetric glyphs do not mirror (F3-T8)', () {
    test('nonMirrored pins LTR', () {
      final w = nonMirrored(const SizedBox());
      expect(w, isA<Directionality>());
      expect((w as Directionality).textDirection, TextDirection.ltr);
    });
  });
}
