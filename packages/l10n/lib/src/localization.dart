import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'generated/app_localizations.dart';

/// Sorani Kurdish (ckb) has no data in Flutter's `GlobalMaterialLocalizations`,
/// so Material widgets would assert on `ckb`. We fall back to Arabic — same
/// script and direction — for the framework strings only; our own copy comes
/// from `AppLocalizations` (which does have real ckb).
const Locale _arabicFallback = Locale('ar');

class _CkbMaterialLocalizationsDelegate
    extends LocalizationsDelegate<MaterialLocalizations> {
  const _CkbMaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ckb';

  @override
  Future<MaterialLocalizations> load(Locale locale) =>
      GlobalMaterialLocalizations.delegate.load(_arabicFallback);

  @override
  bool shouldReload(_CkbMaterialLocalizationsDelegate old) => false;
}

class _CkbCupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CkbCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'ckb';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      GlobalCupertinoLocalizations.delegate.load(_arabicFallback);

  @override
  bool shouldReload(_CkbCupertinoLocalizationsDelegate old) => false;
}

/// All localization delegates for the app. Global delegates are listed BEFORE
/// the ckb fallback so en/de/fr/fa/ar resolve normally; the fallback only
/// catches `ckb` (Global* returns unsupported for it, so resolution continues).
List<LocalizationsDelegate<dynamic>> get carAndPainLocalizationsDelegates =>
    <LocalizationsDelegate<dynamic>>[
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      const _CkbMaterialLocalizationsDelegate(),
      const _CkbCupertinoLocalizationsDelegate(),
    ];

/// The six shipping locales (en/de/fr LTR + fa/ar/ckb RTL).
List<Locale> get carAndPainSupportedLocales =>
    AppLocalizations.supportedLocales;

/// Whether [locale] is one of the RTL scripts we ship (fa/ar/ckb).
bool isRtlLocale(Locale locale) =>
    const {'fa', 'ar', 'ckb'}.contains(locale.languageCode);
