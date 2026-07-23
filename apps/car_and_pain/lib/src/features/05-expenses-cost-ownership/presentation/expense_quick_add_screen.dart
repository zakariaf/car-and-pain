import 'dart:async';
import 'dart:convert';

import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../../01-vehicles-garage/application/vehicle_profile_providers.dart';
import '../application/expense_providers.dart';

/// The low-friction quick-add expense sheet (M6-T6): amount + currency, a
/// taxonomy category, an active-calendar date, an optional odometer + note. In
/// progress input autosaves to a draft that survives process death; a save
/// writes the canonical expense row.
class ExpenseQuickAddScreen extends ConsumerStatefulWidget {
  const ExpenseQuickAddScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<ExpenseQuickAddScreen> createState() => _State();
}

class _State extends ConsumerState<ExpenseQuickAddScreen> {
  final _amount = TextEditingController();
  final _odometer = TextEditingController();
  final _note = TextEditingController();
  String? _categoryId;
  DateTime _spentAt = const SystemClock().nowUtc();
  bool _busy = false;

  String get _draftKey => 'draft:expense:${widget.vehicleId}';

  @override
  void initState() {
    super.initState();
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final raw = await ref.read(settingsRepositoryProvider).get(_draftKey);
    if (raw == null || !mounted) return;
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      setState(() {
        _amount.text = (m['amount'] as String?) ?? '';
        _odometer.text = (m['odometer'] as String?) ?? '';
        _note.text = (m['note'] as String?) ?? '';
        _categoryId = m['category'] as String?;
        final ms = m['spentAt'] as int?;
        if (ms != null) {
          _spentAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
      });
    } on FormatException {
      // Corrupt draft ignored.
    }
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    await ref.read(settingsRepositoryProvider).set(
          _draftKey,
          jsonEncode({
            'amount': _amount.text,
            'odometer': _odometer.text,
            'note': _note.text,
            'category': _categoryId,
            'spentAt': _spentAt.millisecondsSinceEpoch,
          }),
        );
  }

  Future<void> _clearDraft() =>
      ref.read(settingsRepositoryProvider).set(_draftKey, null);

  @override
  void dispose() {
    _amount.dispose();
    _odometer.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _spentAt,
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(_spentAt.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(
      () => _spentAt = DateTime.utc(picked.year, picked.month, picked.day),
    );
    unawaited(_saveDraft());
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final parser = ref.read(activeNumeralParserProvider);
    final vehicle = ref.read(vehicleProvider(widget.vehicleId)).asData?.value;
    final code = vehicle?.currencyCode ?? 'EUR';
    final currency = Currency.tryParse(code) ?? Currency.eur;

    final amount = Money.tryParseMajor(_amount.text.trim(), currency)
        .valueOrNull
        ?.minorUnits;
    if (amount == null) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context).expenseAmountInvalid)),
      );
      return;
    }
    final odo = _odometer.text.trim().isEmpty
        ? null
        : parser.parseScaled(_odometer.text, 3); // km → metres

    final result = await ref.read(expensesRepositoryProvider).add(
          vehicleId: widget.vehicleId,
          spentAt: Instant.fromDateTime(_spentAt),
          amountMinor: amount,
          currencyCode: code,
          categoryId: _categoryId,
          odometerMetres: odo,
          notes: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
    if (!mounted) return;
    if (result.isErr) {
      // Never lose the entry: keep the draft, surface the failure.
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).expenseSaveFailed)),
      );
      return;
    }
    await _clearDraft();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);
    final categories =
        ref.watch(expenseCategoriesProvider).asData?.value ?? const [];

    return PulseScaffold(
      title: l10n.expenseAddTitle,
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.expenseSave),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            onChanged: (_) => unawaited(_saveDraft()),
            decoration: InputDecoration(labelText: l10n.expenseAmount),
          ),
          const SizedBox(height: PulseTokens.s2),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.expenseCategory),
            items: [
              for (final c in categories)
                DropdownMenuItem(
                  value: c.id,
                  child: Text(expenseCategoryName(l10n, c)),
                ),
            ],
            onChanged: (v) {
              setState(() => _categoryId = v);
              unawaited(_saveDraft());
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.expenseDate),
            subtitle: Text(
                formatExpenseDate(cal, fmt, Instant.fromDateTime(_spentAt))),
            trailing: Icon(Icons.adaptive.arrow_forward),
            onTap: _pickDate,
          ),
          TextField(
            controller: _odometer,
            keyboardType: TextInputType.number,
            onChanged: (_) => unawaited(_saveDraft()),
            decoration: InputDecoration(labelText: l10n.expenseOdometer),
          ),
          const SizedBox(height: PulseTokens.s2),
          TextField(
            controller: _note,
            onChanged: (_) => unawaited(_saveDraft()),
            decoration: InputDecoration(labelText: l10n.expenseNote),
          ),
          const SizedBox(height: PulseTokens.s2),
          // Receipt capture rides the F8 attachments pipeline; the picker UI is a
          // follow-up (the expense row already carries a receiptAttachmentId).
          PulseButton(
            label: l10n.expenseAttachReceipt,
            onPressed: null,
            variant: PulseButtonVariant.ghost,
            icon: Icons.attach_file,
          ),
        ],
      ),
    );
  }
}
