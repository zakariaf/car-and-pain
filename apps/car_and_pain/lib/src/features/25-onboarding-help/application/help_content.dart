import 'package:l10n/l10n.dart';

/// M10-T5 · the bundled, fully-offline help/FAQ content model + a numeral-folded
/// ranked search. Content is authored as localized ARB (translatable, RTL-safe);
/// search normalizes both query and content through [normalizeForSearch] so a
/// query typed in Eastern-Arabic/Persian digits or with diacritics still matches.

/// One help article. [title] and [body] are already localized by the caller.
class HelpTopic {
  const HelpTopic({required this.id, required this.title, required this.body});

  final String id;
  final String title;
  final String body;
}

/// The bundled topics for the active locale (the genuinely non-obvious features).
List<HelpTopic> bundledHelpTopics(AppLocalizations l10n) => [
      HelpTopic(
          id: 'offline',
          title: l10n.helpOfflineTitle,
          body: l10n.helpOfflineBody),
      HelpTopic(id: 'tco', title: l10n.helpTcoTitle, body: l10n.helpTcoBody),
      HelpTopic(
          id: 'economy',
          title: l10n.helpEconomyTitle,
          body: l10n.helpEconomyBody),
      HelpTopic(
          id: 'calendars',
          title: l10n.helpCalendarsTitle,
          body: l10n.helpCalendarsBody),
      HelpTopic(
          id: 'reminders',
          title: l10n.helpRemindersTitle,
          body: l10n.helpRemindersBody),
    ];

/// Rank [topics] against [query]. Both sides are folded (digits→ASCII, diacritics
/// stripped, lower-cased) so matching is script/numeral-insensitive. A title hit
/// outweighs a body hit. An empty query returns every topic (browse mode). Pure.
List<HelpTopic> searchHelpTopics(List<HelpTopic> topics, String query) {
  final normalized = normalizeForSearch(query).trim();
  if (normalized.isEmpty) return topics;
  final terms = normalized.split(RegExp(r'\s+'));
  final scored = <(HelpTopic, int)>[];
  for (final t in topics) {
    final title = normalizeForSearch(t.title);
    final body = normalizeForSearch(t.body);
    var score = 0;
    for (final term in terms) {
      if (title.contains(term)) score += 2; // title weight
      if (body.contains(term)) score += 1;
    }
    if (score > 0) scored.add((t, score));
  }
  scored.sort((a, b) => b.$2.compareTo(a.$2));
  return [for (final s in scored) s.$1];
}
