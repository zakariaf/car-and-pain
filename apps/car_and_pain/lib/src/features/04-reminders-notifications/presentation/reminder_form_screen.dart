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
import '../application/reminder_providers.dart';

/// The reminder create/edit flow (M5-T3): rule-kind selection (date / distance /
/// engine-hour / whichever-first) with calendar- and numeral-aware inputs,
/// lead-time, severity, and recurrence. In-progress input autosaves to a draft
/// that survives process death; a failed save keeps the draft and surfaces the
/// error (never loses the user's entry). Pass [reminderId] to edit an existing
/// reminder (fields prefill from it; save overwrites via `repo.update`).
class ReminderFormScreen extends ConsumerStatefulWidget {
  const ReminderFormScreen(
      {required this.vehicleId, this.reminderId, super.key});

  final String vehicleId;
  final String? reminderId;

  @override
  ConsumerState<ReminderFormScreen> createState() => _ReminderFormState();
}

class _ReminderFormState extends ConsumerState<ReminderFormScreen> {
  final _title = TextEditingController();
  final _notes = TextEditingController();
  final _distanceKm = TextEditingController();
  final _engineHours = TextEditingController();
  final _leadDays = TextEditingController();
  final _recurrenceEvery = TextEditingController();

  TriggerKind _kind = TriggerKind.date;
  DateTime _dueDate = const SystemClock().nowUtc();
  String _severity = 'info';
  RecurrenceUnit? _recurrenceUnit;
  bool _busy = false;

  bool get _isEdit => widget.reminderId != null;

  // An edit gets its own draft key so an in-progress edit never clobbers a
  // half-typed new reminder (and vice-versa).
  String get _draftKey => _isEdit
      ? 'draft:reminder:edit:${widget.reminderId}'
      : 'draft:reminder:${widget.vehicleId}';

  bool get _hasDate =>
      _kind == TriggerKind.date || _kind == TriggerKind.whicheverFirst;
  bool get _hasDistance =>
      _kind == TriggerKind.distance || _kind == TriggerKind.whicheverFirst;
  bool get _hasHours =>
      _kind == TriggerKind.engineHours || _kind == TriggerKind.whicheverFirst;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    // Editing prefills from the stored reminder first; any in-progress edit draft
    // then overlays it (the user's unsaved edits win).
    if (_isEdit) await _prefillFromReminder();
    await _loadDraft();
  }

  Future<void> _prefillFromReminder() async {
    final r =
        await ref.read(remindersRepositoryProvider).byId(widget.reminderId!);
    if (r == null || !mounted) return;
    final fmt = ref.read(activeNumeralFormatProvider);
    setState(() {
      _title.text = r.title;
      _notes.text = r.notes ?? '';
      _kind = Reminder.triggerKindFromName(r.triggerType);
      _severity = r.severity;
      if (r.dueDate != null) _dueDate = r.dueDate!.utc;
      if (r.dueOdometerMetres != null) {
        _distanceKm.text = fmt.formatScaled(r.dueOdometerMetres!, 3);
      }
      if (r.dueEngineMinutes != null) {
        _engineHours.text = fmt.formatUngrouped(r.dueEngineMinutes! ~/ 60);
      }
      if (r.leadMinutes > 0) {
        _leadDays.text = fmt.formatUngrouped(r.leadMinutes ~/ 1440);
      }
      if (r.recurrenceEvery != null) {
        _recurrenceEvery.text = fmt.formatUngrouped(r.recurrenceEvery!);
      }
      _recurrenceUnit = r.recurrenceUnit == null
          ? null
          : Reminder.recurrenceUnitFromName(r.recurrenceUnit!);
    });
  }

  Future<void> _loadDraft() async {
    final raw = await ref.read(settingsRepositoryProvider).get(_draftKey);
    if (raw == null || !mounted) return;
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      setState(() {
        _title.text = (m['title'] as String?) ?? '';
        _notes.text = (m['notes'] as String?) ?? '';
        _distanceKm.text = (m['distanceKm'] as String?) ?? '';
        _engineHours.text = (m['engineHours'] as String?) ?? '';
        _leadDays.text = (m['leadDays'] as String?) ?? '';
        _recurrenceEvery.text = (m['recurrenceEvery'] as String?) ?? '';
        _kind = TriggerKind.values.asNameMap()[m['kind']] ?? TriggerKind.date;
        _severity = (m['severity'] as String?) ?? 'info';
        _recurrenceUnit =
            RecurrenceUnit.values.asNameMap()[m['recurrenceUnit']];
        final ms = m['dueDate'] as int?;
        if (ms != null) {
          _dueDate = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
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
            'title': _title.text,
            'notes': _notes.text,
            'distanceKm': _distanceKm.text,
            'engineHours': _engineHours.text,
            'leadDays': _leadDays.text,
            'recurrenceEvery': _recurrenceEvery.text,
            'kind': _kind.name,
            'severity': _severity,
            'recurrenceUnit': _recurrenceUnit?.name,
            'dueDate': _dueDate.millisecondsSinceEpoch,
          }),
        );
  }

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    _distanceKm.dispose();
    _engineHours.dispose();
    _leadDays.dispose();
    _recurrenceEvery.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(_dueDate.year + 20, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(
        () => _dueDate = DateTime.utc(picked.year, picked.month, picked.day));
    unawaited(_saveDraft());
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final parser = ref.read(activeNumeralParserProvider);
    final title = _title.text.trim();
    if (title.isEmpty) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).reminderTitleHint)),
      );
      return;
    }

    final leadDays = parser.parseScaled(_leadDays.text, 0) ?? 0;
    final every = parser.parseScaled(_recurrenceEvery.text, 0) ?? 0;
    final hours = _hasHours ? parser.parseScaled(_engineHours.text, 0) : null;
    final repo = ref.read(remindersRepositoryProvider);
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final dueDate = _hasDate ? Instant.fromDateTime(_dueDate) : null;
    final dueOdo =
        _hasDistance ? parser.parseScaled(_distanceKm.text, 3) : null;
    final dueEngineMinutes = hours == null ? null : hours * 60;
    final recEvery = (_recurrenceUnit != null && every > 0) ? every : null;
    final recUnit = every > 0 ? _recurrenceUnit : null;

    final result = _isEdit
        ? await repo.update(
            widget.reminderId!,
            title: title,
            kind: _kind,
            notes: notes,
            dueDate: dueDate,
            dueOdometerMetres: dueOdo,
            dueEngineMinutes: dueEngineMinutes,
            leadMinutes: leadDays * 1440,
            recurrenceEvery: recEvery,
            recurrenceUnit: recUnit,
            severity: _severity,
          )
        : await repo.add(
            vehicleId: widget.vehicleId,
            title: title,
            kind: _kind,
            notes: notes,
            dueDate: dueDate,
            dueOdometerMetres: dueOdo,
            dueEngineMinutes: dueEngineMinutes,
            leadMinutes: leadDays * 1440,
            recurrenceEvery: recEvery,
            recurrenceUnit: recUnit,
            severity: _severity,
          );
    if (!mounted) return;
    if (result.isErr) {
      // Never lose the user's entry: keep the draft and surface the failure.
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).reminderSaveFailed),
        ),
      );
      return;
    }
    await ref.read(settingsRepositoryProvider).set(_draftKey, null);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);

    return PulseScaffold(
      title: _isEdit ? l10n.reminderEditTitle : l10n.reminderAddTitle,
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.reminderSave),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          TextField(
            controller: _title,
            onChanged: (_) => unawaited(_saveDraft()),
            decoration: InputDecoration(labelText: l10n.reminderTitle),
          ),
          const SizedBox(height: PulseTokens.s2),
          Text(l10n.reminderKind,
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: PulseTokens.sHalf),
          DropdownButtonFormField<TriggerKind>(
            initialValue: _kind,
            isExpanded: true,
            items: [
              for (final k in TriggerKind.values)
                DropdownMenuItem(
                    value: k, child: Text(reminderKindLabel(l10n, k))),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _kind = v);
              unawaited(_saveDraft());
            },
          ),
          const SizedBox(height: PulseTokens.s2),
          if (_hasDate)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(l10n.reminderDueDate),
              subtitle:
                  Text(formatDueDate(cal, fmt, Instant.fromDateTime(_dueDate))),
              trailing: Icon(Icons.adaptive.arrow_forward),
              onTap: _pickDate,
            ),
          if (_hasDistance)
            _numberField(_distanceKm, l10n.reminderDistanceThreshold),
          if (_hasHours)
            _numberField(_engineHours, l10n.reminderEngineHourThreshold),
          _numberField(_leadDays, l10n.reminderLeadDays),
          const SizedBox(height: PulseTokens.s2),
          DropdownButtonFormField<String>(
            initialValue: _severity,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.reminderSeverity),
            items: [
              DropdownMenuItem(
                  value: 'overdue', child: Text(l10n.reminderSevOverdue)),
              DropdownMenuItem(
                  value: 'dueSoon', child: Text(l10n.reminderSevDueSoon)),
              DropdownMenuItem(
                  value: 'documents', child: Text(l10n.reminderSevDocuments)),
              DropdownMenuItem(
                  value: 'info', child: Text(l10n.reminderSevInfo)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() => _severity = v);
              unawaited(_saveDraft());
            },
          ),
          const SizedBox(height: PulseTokens.s2),
          SectionHeader(title: l10n.reminderRecurrence),
          Row(
            children: [
              Expanded(
                child: _numberField(_recurrenceEvery, l10n.reminderEvery),
              ),
              const SizedBox(width: PulseTokens.s2),
              Expanded(
                child: DropdownButtonFormField<RecurrenceUnit?>(
                  initialValue: _recurrenceUnit,
                  isExpanded: true,
                  decoration: InputDecoration(labelText: l10n.reminderUnit),
                  items: [
                    DropdownMenuItem(child: Text(l10n.reminderOnce)),
                    for (final u in RecurrenceUnit.values)
                      DropdownMenuItem(
                          value: u, child: Text(_unitLabel(l10n, u))),
                  ],
                  onChanged: (v) {
                    setState(() => _recurrenceUnit = v);
                    unawaited(_saveDraft());
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _numberField(TextEditingController c, String label) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
        child: TextField(
          controller: c,
          keyboardType: TextInputType.number,
          onChanged: (_) => unawaited(_saveDraft()),
          decoration: InputDecoration(labelText: label),
        ),
      );

  String _unitLabel(AppLocalizations l10n, RecurrenceUnit u) => switch (u) {
        RecurrenceUnit.days => l10n.reminderUnitDays,
        RecurrenceUnit.weeks => l10n.reminderUnitWeeks,
        RecurrenceUnit.months => l10n.reminderUnitMonths,
        RecurrenceUnit.years => l10n.reminderUnitYears,
      };
}
