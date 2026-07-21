import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Registers the bundled OFL font licenses (F4-T6) with Flutter's
/// [LicenseRegistry] so they surface on the app's licenses page for store
/// compliance. Call once at startup (see `bootstrap`). The license text is read
/// lazily from the bundled asset only when the licenses page is opened.
void registerFontLicenses() {
  LicenseRegistry.addLicense(() async* {
    const fonts = <String, String>{
      'Hanken Grotesk': 'packages/design_system/fonts/HankenGrotesk-OFL.txt',
      'Vazirmatn': 'packages/design_system/fonts/Vazirmatn-OFL.txt',
    };
    for (final entry in fonts.entries) {
      final text = await rootBundle.loadString(entry.value);
      yield LicenseEntryWithLineBreaks([entry.key], text);
    }
  });
}
