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
import '../application/service_providers.dart';

/// The multi-line service-visit editor (M4-T4): a visit header (date, odometer,
/// DIY flag) plus an add/remove list of line items — several jobs under one
/// receipt. In-progress input autosaves to a draft that survives process death;
/// a save writes the visit + line items + odometer ledger row transactionally.
class ServiceEntryFormScreen extends ConsumerStatefulWidget {
  const ServiceEntryFormScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<ServiceEntryFormScreen> createState() => _ServiceFormState();
}

class _LineRow {
  _LineRow({this.serviceTypeId, String labour = '', String parts = ''})
      : labour = TextEditingController(text: labour),
        parts = TextEditingController(text: parts);

  String? serviceTypeId;
  final TextEditingController labour;
  final TextEditingController parts;
  bool resetsInterval = true;

  void dispose() {
    labour.dispose();
    parts.dispose();
  }
}

class _ServiceFormState extends ConsumerState<ServiceEntryFormScreen> {
  final _odometer = TextEditingController();
  final _rows = <_LineRow>[];
  bool _isDiy = false;
  DateTime _servicedAt = const SystemClock().nowUtc();
  bool _busy = false;

  String get _draftKey => 'draft:service:${widget.vehicleId}';

  @override
  void initState() {
    super.initState();
    _rows.add(_LineRow());
    _loadDraft();
  }

  Future<void> _loadDraft() async {
    final raw = await ref.read(settingsRepositoryProvider).get(_draftKey);
    if (raw == null || !mounted) return;
    try {
      _restore((jsonDecode(raw) as Map).cast<String, dynamic>());
    } on FormatException {
      // Corrupt draft ignored.
    }
  }

  Map<String, dynamic> _snapshot() => {
        'odometer': _odometer.text,
        'isDiy': _isDiy,
        'servicedAt': _servicedAt.millisecondsSinceEpoch,
        'rows': [
          for (final r in _rows)
            {
              'type': r.serviceTypeId,
              'labour': r.labour.text,
              'parts': r.parts.text,
              'resets': r.resetsInterval,
            },
        ],
      };

  void _restore(Map<String, dynamic> m) {
    for (final r in _rows) {
      r.dispose();
    }
    setState(() {
      _odometer.text = (m['odometer'] as String?) ?? '';
      _isDiy = (m['isDiy'] as bool?) ?? false;
      final ms = m['servicedAt'] as int?;
      if (ms != null) {
        _servicedAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
      _rows
        ..clear()
        ..addAll([
          for (final r in (m['rows'] as List? ?? const []))
            _LineRow(
              serviceTypeId: (r as Map)['type'] as String?,
              labour: (r['labour'] as String?) ?? '',
              parts: (r['parts'] as String?) ?? '',
            )..resetsInterval = (r['resets'] as bool?) ?? true,
        ]);
      if (_rows.isEmpty) _rows.add(_LineRow());
    });
  }

  Future<void> _saveDraft() async {
    if (!mounted) return;
    await ref
        .read(settingsRepositoryProvider)
        .set(_draftKey, jsonEncode(_snapshot()));
  }

  Future<void> _clearDraft() =>
      ref.read(settingsRepositoryProvider).set(_draftKey, null);

  @override
  void dispose() {
    _odometer.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() => _rows.add(_LineRow()));
    unawaited(_saveDraft());
  }

  void _removeRow(int index) {
    setState(() => _rows.removeAt(index).dispose());
    unawaited(_saveDraft());
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _servicedAt,
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(_servicedAt.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(() => _servicedAt = DateTime.utc(
          picked.year,
          picked.month,
          picked.day,
        ));
    unawaited(_saveDraft());
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final parser = ref.read(activeNumeralParserProvider);
    final vehicle = ref.read(vehicleProvider(widget.vehicleId)).asData?.value;
    final code = vehicle?.currencyCode ?? 'EUR';
    final currency = Currency.tryParse(code) ?? Currency.eur;

    int money(TextEditingController c) =>
        Money.tryParseMajor(c.text.trim(), currency).valueOrNull?.minorUnits ??
        0;

    final odo = parser.parseScaled(_odometer.text, 3); // km → metres
    final lineItems = [
      for (final r in _rows)
        ServiceLineItemDraft(
          serviceTypeId: r.serviceTypeId,
          labourMinor: money(r.labour),
          partsMinor: money(r.parts),
          resetsInterval: r.resetsInterval,
        ),
    ];

    final result = await ref.read(serviceRepositoryProvider).add(
          vehicleId: widget.vehicleId,
          servicedAt: Instant.fromDateTime(_servicedAt),
          currencyCode: code,
          odometerMetres: odo,
          isDiy: _isDiy,
          lineItems: lineItems,
        );
    if (!mounted) return;
    if (result.isErr) {
      // Never lose the user's entry (CLAUDE.md invariant): keep the draft and
      // surface the failure rather than clearing + popping on a silent error.
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).serviceSaveFailed)),
      );
      return;
    }
    await _clearDraft();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final types = ref.watch(serviceTypesProvider).asData?.value ?? const [];
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);

    return PulseScaffold(
      title: l10n.serviceAddTitle,
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.serviceSave),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.serviceDate),
            subtitle: Text(
              formatServiceDate(cal, fmt, Instant.fromDateTime(_servicedAt)),
            ),
            trailing: Icon(Icons.adaptive.arrow_forward),
            onTap: _pickDate,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
            child: TextField(
              controller: _odometer,
              keyboardType: TextInputType.number,
              onChanged: (_) => unawaited(_saveDraft()),
              decoration: InputDecoration(labelText: l10n.serviceOdometer),
            ),
          ),
          SwitchListTile.adaptive(
            value: _isDiy,
            onChanged: (v) {
              setState(() => _isDiy = v);
              unawaited(_saveDraft());
            },
            title: Text(l10n.serviceDiy),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: PulseTokens.s2),
          SectionHeader(title: l10n.serviceLineItem),
          for (var i = 0; i < _rows.length; i++) _lineItemCard(l10n, i, types),
          const SizedBox(height: PulseTokens.s2),
          PulseButton(
            label: l10n.serviceAddLineItem,
            onPressed: _addRow,
            variant: PulseButtonVariant.ghost,
            icon: Icons.add,
          ),
        ],
      ),
    );
  }

  Widget _lineItemCard(
    AppLocalizations l10n,
    int index,
    List<Category> types,
  ) {
    final row = _rows[index];
    return PulseCard(
      // A transparent Material so the inner SwitchListTile paints its ink on it
      // rather than being swallowed by the PulseCard's decorated background.
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: row.serviceTypeId,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.serviceType),
                    items: [
                      for (final t in types)
                        DropdownMenuItem(
                          value: t.id,
                          child: Text(serviceTypeName(l10n, t)),
                        ),
                    ],
                    onChanged: (v) {
                      setState(() => row.serviceTypeId = v);
                      unawaited(_saveDraft());
                    },
                  ),
                ),
                if (_rows.length > 1)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    tooltip: l10n.serviceRemoveLineItem,
                    onPressed: () => _removeRow(index),
                  ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: row.labour,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => unawaited(_saveDraft()),
                    decoration:
                        InputDecoration(labelText: l10n.serviceLabourCost),
                  ),
                ),
                const SizedBox(width: PulseTokens.s2),
                Expanded(
                  child: TextField(
                    controller: row.parts,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => unawaited(_saveDraft()),
                    decoration:
                        InputDecoration(labelText: l10n.servicePartsCost),
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              value: row.resetsInterval,
              onChanged: (v) {
                setState(() => row.resetsInterval = v);
                unawaited(_saveDraft());
              },
              title: Text(l10n.serviceResetsInterval),
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
