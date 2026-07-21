import 'package:car_and_pain/src/settings/locale_controller.dart';
import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:l10n/l10n.dart';

void main() {
  group('preference resolution (F4-T2)', () {
    // A fixed device locale keeps resolution deterministic across platforms;
    // resolveLocalizationPrefs is pure — no async, no binding, no provider.
    const device = [Locale('en', 'US')];
    LocalizationPrefs resolve(Map<String, String> stored) =>
        resolveLocalizationPrefs(stored, device);

    test('no stored prefs → follow device (en), gregorian, western', () {
      final prefs = resolve(const {});
      expect(prefs.locale, isNull); // follow device
      expect(prefs.languageCode, 'en');
      expect(prefs.calendar, CalendarSystem.gregorian);
      expect(prefs.numeralSystem, NumeralSystem.western);
      expect(prefs.isRtl, isFalse);
    });

    test('choosing fa resolves Jalali + Persian by default, and is RTL', () {
      final prefs = resolve(const {'locale': 'fa'});
      expect(prefs.locale, const Locale('fa'));
      expect(prefs.calendar, CalendarSystem.jalali);
      expect(prefs.numeralSystem, NumeralSystem.persian);
      expect(prefs.isRtl, isTrue);
    });

    test('choosing ar resolves Hijri + Eastern-Arabic', () {
      final prefs = resolve(const {'locale': 'ar'});
      expect(prefs.calendar, CalendarSystem.hijri);
      expect(prefs.numeralSystem, NumeralSystem.easternArabic);
      expect(prefs.isRtl, isTrue);
    });

    test('explicit calendar/numeral override the locale defaults', () {
      final prefs = resolve(
        const {'locale': 'fa', 'calendar': 'gregorian', 'numeral': 'western'},
      );
      expect(prefs.calendar, CalendarSystem.gregorian);
      expect(prefs.numeralSystem, NumeralSystem.western);
    });
  });

  group('controller persistence (F4-T2)', () {
    test('writes land in the encrypted settings store', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final controller = LocalizationController(SettingsRepository(db));

      expect((await controller.setLocale(const Locale('ckb'))).isOk, isTrue);
      expect((await controller.setCalendar(CalendarSystem.hijri)).isOk, isTrue);
      expect(
        (await controller.setNumeralSystem(NumeralSystem.persian)).isOk,
        isTrue,
      );

      final map = await SettingsRepository(db).readAll();
      expect(map['locale'], 'ckb');
      expect(map['calendar'], 'hijri');
      expect(map['numeral'], 'persian');

      // Clearing the locale removes the key (revert to device).
      expect((await controller.setLocale(null)).isOk, isTrue);
      expect(await SettingsRepository(db).get('locale'), isNull);
    });
  });
}
