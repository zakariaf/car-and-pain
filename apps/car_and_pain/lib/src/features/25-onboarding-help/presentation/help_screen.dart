import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../application/help_content.dart';

/// M10-T5/T4 · the offline help & FAQ centre: numeral-folded search over bundled
/// topics, browse-by-expansion articles (the contextual explainers for TCO,
/// full-to-full economy, and the calendars), and the demo-vehicle seed/teardown
/// entry point. Fully localized, RTL-correct, works with the radio off.
class HelpScreen extends ConsumerStatefulWidget {
  const HelpScreen({super.key});

  @override
  ConsumerState<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends ConsumerState<HelpScreen> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final topics = bundledHelpTopics(l10n);
    final results = searchHelpTopics(topics, _query.text);

    return PulseScaffold(
      title: l10n.helpTitle,
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          TextField(
            controller: _query,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: l10n.helpSearchHint,
              prefixIcon: const Icon(Icons.search),
            ),
          ),
          const SizedBox(height: PulseTokens.s3),
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
              child: Row(
                children: [
                  const Icon(Icons.help_outline),
                  const SizedBox(width: PulseTokens.s2),
                  Expanded(child: Text(l10n.helpNoResults)),
                ],
              ),
            )
          else
            for (final t in results)
              PulseCard(
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding:
                      const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
                  leading: const Icon(Icons.article_outlined),
                  title: Text(t.title),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(t.body),
                    ),
                  ],
                ),
              ),
          const SizedBox(height: PulseTokens.s3),
          SectionHeader(title: l10n.helpDemoSection),
          _DemoControls(l10n: l10n),
        ],
      ),
    );
  }
}

/// Seed or remove the sample vehicle (M10-T3), re-runnable from Help.
class _DemoControls extends ConsumerWidget {
  const _DemoControls({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<bool>(
      future: ref.watch(demoSeederProvider).isActive(),
      builder: (context, snapshot) {
        final active = snapshot.data ?? false;
        return PulseButton(
          label: active ? l10n.helpDemoRemove : l10n.helpDemoSeed,
          icon: active ? Icons.delete_outline : Icons.auto_awesome_outlined,
          variant: PulseButtonVariant.ghost,
          onPressed: () async {
            final seeder = ref.read(demoSeederProvider);
            final result =
                active ? await seeder.teardown() : await seeder.seed();
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result.isOk
                    ? (active ? l10n.helpDemoRemoved : l10n.helpDemoSeeded)
                    : l10n.helpDemoFailed),
              ),
            );
          },
        );
      },
    );
  }
}
