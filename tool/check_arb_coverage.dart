// F4-T1 missing-key policy gate: every locale ARB MUST cover the full set of
// message keys in the template (app_en.arb). Run in CI before gen-l10n so a
// forgotten translation fails the build instead of silently falling back to en.
//
//   dart run tool/check_arb_coverage.dart
//
// Exits non-zero if any locale is missing a template key or carries a key the
// template does not define (a dead/renamed string).
import 'dart:convert';
import 'dart:io';

const _arbDir = 'packages/l10n/lib/l10n';
const _template = 'app_en.arb';

Set<String> _messageKeys(File f) {
  final map = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
  return map.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  final dir = Directory(_arbDir);
  if (!dir.existsSync()) {
    stderr.writeln('ARB dir not found: $_arbDir');
    exit(2);
  }
  final template = _messageKeys(File('$_arbDir/$_template'));
  final arbs = dir
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.arb') && !f.path.endsWith(_template))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  var failed = false;
  for (final f in arbs) {
    final name = f.uri.pathSegments.last;
    final keys = _messageKeys(f);
    final missing = template.difference(keys).toList()..sort();
    final extra = keys.difference(template).toList()..sort();
    if (missing.isEmpty && extra.isEmpty) {
      stdout.writeln('OK   $name  (${keys.length} keys)');
      continue;
    }
    failed = true;
    if (missing.isNotEmpty) {
      stdout.writeln('FAIL $name  missing ${missing.length}: $missing');
    }
    if (extra.isNotEmpty) {
      stdout.writeln('FAIL $name  extra ${extra.length}: $extra');
    }
  }

  if (failed) {
    stderr.writeln(
      '\nARB coverage failed: every locale must cover exactly the '
      'app_en.arb message keys (no missing, no orphans).',
    );
    exit(1);
  }
  stdout.writeln('\nARB coverage OK: all locales cover the en template.');
}
