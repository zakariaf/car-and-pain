import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_vitals_screen.dart';

/// The Cockpit Room root — the "Now" home (PULSE screen A2). Delegates to the
/// breathing-vital Home (M1-T4), which reads live streams and shows the empty
/// first-run state when there are no vehicles.
class CockpitScreen extends ConsumerWidget {
  const CockpitScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => const HomeVitalsScreen();
}
