import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The app-controlled locale. `null` follows the device locale.
///
/// This is the seam the app uses to drive language independently of the OS.
/// TODO(F4): persist the chosen locale in the encrypted DB and hydrate it here;
/// resolve numerals/calendars off the same preference.
final localeProvider = Provider<Locale?>((ref) => null);
