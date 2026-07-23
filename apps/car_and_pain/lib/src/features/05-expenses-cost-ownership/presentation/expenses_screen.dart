import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../routing/app_locations.dart';
import '../../../settings/locale_controller.dart';
import '../application/expense_providers.dart';

/// The expense timeline (M6-T6): a live list of a vehicle's costs with localized
/// money + date + category. The add action opens the quick-add sheet.
class ExpensesScreen extends ConsumerWidget {
  const ExpensesScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final expenses =
        ref.watch(expenseHistoryProvider(vehicleId)).asData?.value ?? const [];
    final categories =
        ref.watch(expenseCategoriesProvider).asData?.value ?? const [];
    final catById = {for (final c in categories) c.id: c};
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);

    return PulseScaffold(
      title: l10n.expensesTitle,
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: l10n.expenseAddTitle,
          onPressed: () => context.push(AppLocations.logExpense(vehicleId)),
        ),
      ],
      body: expenses.isEmpty
          ? Center(child: Text(l10n.expensesEmpty))
          : ListView(
              padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
              children: [
                for (final e in expenses)
                  PulseCard(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        e.isProjected
                            ? Icons.link
                            : Icons.receipt_long_outlined,
                      ),
                      title: Text(_categoryLabel(l10n, catById[e.categoryId])),
                      subtitle: Text(
                        formatExpenseDate(cal, fmt, e.spentAt),
                      ),
                      trailing: Text(
                        formatMoney(fmt, e.amountMinor, e.currencyCode),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  String _categoryLabel(AppLocalizations l10n, Category? c) =>
      c == null ? l10n.expenseUncategorized : expenseCategoryName(l10n, c);
}
