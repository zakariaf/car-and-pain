import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import 'routing/app_router.dart';
import 'settings/locale_controller.dart';

/// The root widget. Wires the PULSE dual theme, the six-locale gen-l10n
/// delegates (incl. the ckb fallback), an app-controlled locale, and the single
/// GoRouter. RTL is derived automatically for fa/ar/ckb.
class CarAndPainApp extends ConsumerWidget {
  const CarAndPainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: pulseLightTheme,
      darkTheme: pulseDarkTheme,
      locale: ref.watch(localeProvider),
      localizationsDelegates: carAndPainLocalizationsDelegates,
      supportedLocales: carAndPainSupportedLocales,
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
