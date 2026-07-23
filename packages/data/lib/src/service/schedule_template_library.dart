import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Loads the bundled offline maintenance-schedule templates (M4-T3) from the
/// on-device asset bundle — no network. The parsed template is editable and its
/// intervals stay overridable per vehicle when applied.
class ScheduleTemplateLibrary {
  const ScheduleTemplateLibrary();

  /// The bundled generic template (carries embedded severe-duty overrides).
  static const String genericAssetPath =
      'packages/data/assets/schedules/generic.json';

  /// Load + parse the bundled generic template from the asset bundle.
  Future<Result<ScheduleTemplate, ImportFailure>> loadGeneric() async =>
      parse(await rootBundle.loadString(genericAssetPath));

  /// Parse a template from a JSON [source] string — the pure seam the tests and a
  /// later community import share. A newer schema version is refused; malformed
  /// JSON is a typed [CorruptArchive].
  Result<ScheduleTemplate, ImportFailure> parse(String source) {
    try {
      final json = jsonDecode(source) as Map<String, dynamic>;
      final version = (json['version'] as num).toInt();
      if (version > ScheduleTemplate.currentVersion) {
        return Err(
          SchemaVersionMismatch(
            expected: ScheduleTemplate.currentVersion,
            found: version,
          ),
        );
      }
      return Ok(ScheduleTemplate.fromJson(json));
    } on Object {
      return const Err(CorruptArchive());
    }
  }
}
