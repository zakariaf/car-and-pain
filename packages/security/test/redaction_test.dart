import 'dart:convert';

import 'package:security/security.dart';
import 'package:test/test.dart';

Map<String, dynamic> _doc() => {
      'formatVersion': 1,
      'entities': {
        'vehicles': [
          {'id': 'v1', 'nickname': 'Golf', 'vin': 'WVW-PUBLIC'},
        ],
        'drivers': [
          {'id': 'd1', 'name': 'Alex', 'bloodType': 'O-', 'iceContact': '999'},
        ],
      },
    };

void main() {
  test('redaction strips flagged fields at the export boundary (F7-T6)', () {
    const spec = RedactionSpec({
      'drivers': {'bloodType', 'iceContact'},
    });
    final redacted = redactExport(_doc(), spec);
    final entities = redacted['entities'] as Map;

    final driver = (entities['drivers'] as List).first as Map;
    // The sensitive medical/ICE fields are gone entirely (no masked stub)…
    expect(driver.containsKey('bloodType'), isFalse);
    expect(driver.containsKey('iceContact'), isFalse);
    // …while the rest of the record stays intact.
    expect(driver['name'], 'Alex');
    // Untouched entities pass through unchanged.
    final vehicle = (entities['vehicles'] as List).first as Map;
    expect(vehicle['vin'], 'WVW-PUBLIC');

    // The clinching proof: no sensitive value survives anywhere in the artifact.
    final serialized = jsonEncode(redacted);
    expect(serialized, isNot(contains('O-')));
    expect(serialized, isNot(contains('999')));
  });

  test('an empty spec is a full-fidelity export (owner backup)', () {
    final doc = _doc();
    expect(redactExport(doc, const RedactionSpec.none()), same(doc));
  });

  test('a spec naming an absent entity/field is a no-op', () {
    final redacted = redactExport(
        _doc(),
        const RedactionSpec({
          'nonexistent': {'x'},
          'vehicles': {'notAField'},
        }));
    final entities = redacted['entities'] as Map;
    expect((entities['vehicles'] as List).first,
        {'id': 'v1', 'nickname': 'Golf', 'vin': 'WVW-PUBLIC'});
  });
}
