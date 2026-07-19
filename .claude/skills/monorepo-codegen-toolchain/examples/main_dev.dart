// apps/car_and_pain/lib/main_dev.dart
//
// Flavor entrypoint. Two thin entrypoints (main_dev / main_prod) call one
// shared bootstrap(). The flavor is read from the compile-time `appFlavor`
// const inside bootstrap — no third-party flavor package. Flavors exist for
// side-by-side install + distinct notification channel IDs, NOT API config
// (there is no backend).

import 'package:car_and_pain/src/bootstrap.dart';

void main() => bootstrap(Flavor.dev);

// ---------------------------------------------------------------------------
// Illustrative: how the shared bootstrap consumes the compile-time flavor.
// (Real bootstrap also inits tz, opens the encrypted DB, and wires providers.)
// ---------------------------------------------------------------------------
//
// import 'package:flutter/services.dart' show appFlavor;
//
// Future<void> bootstrap(Flavor flavor) async {
//   // Distinct channel IDs / request-code ranges keep a dev build's reminders
//   // from colliding with prod's on the same physical device.
//   final channelId = 'reminders_$appFlavor'; // e.g. reminders_dev
//   // ... open encrypted DB, override providers in ProviderScope, init tz ...
// }
//
// enum Flavor { dev, prod }
