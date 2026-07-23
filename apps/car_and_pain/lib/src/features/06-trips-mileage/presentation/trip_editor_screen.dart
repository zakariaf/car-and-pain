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
import '../application/trip_providers.dart';
import 'trip_ui.dart';

/// Create or edit a trip (M7-T5). A new trip is entered by odometer (start+end)
/// or by direct distance, classified, and validated — a bad distance surfaces as
/// a localized inline error, never a crash — with a live gap warning and draft
/// autosave. Editing an existing trip touches only non-ledger fields (distance
/// and odometer are immutable once written to the shared ledger).
class TripEditorScreen extends ConsumerStatefulWidget {
  const TripEditorScreen({required this.vehicleId, this.tripId, super.key});

  final String vehicleId;
  final String? tripId;

  @override
  ConsumerState<TripEditorScreen> createState() => _State();
}

class _State extends ConsumerState<TripEditorScreen> {
  final _start = TextEditingController();
  final _end = TextEditingController();
  final _distance = TextEditingController();
  final _passengers = TextEditingController(text: '0');
  final _notes = TextEditingController();
  bool _byOdometer = true;
  TripClassification _classification = TripClassification.unclassified;
  DateTime _tripAt = const SystemClock().nowUtc();
  String? _distanceError;
  bool _busy = false;
  Trip? _existing;

  bool get _isEdit => widget.tripId != null;
  String get _draftKey => 'draft:trip:${widget.vehicleId}';

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _loadExisting();
    } else {
      _loadDraft();
    }
  }

  Future<void> _loadExisting() async {
    final trip = await ref.read(tripsRepositoryProvider).byId(widget.tripId!);
    if (trip == null || !mounted) return;
    setState(() {
      _existing = trip;
      _classification = trip.classification;
      _passengers.text = '${trip.passengerCount}';
      _notes.text = trip.notes ?? '';
      _tripAt = DateTime.fromMillisecondsSinceEpoch(trip.tripAt.epochMillis,
          isUtc: true);
    });
  }

  Future<void> _loadDraft() async {
    final raw = await ref.read(settingsRepositoryProvider).get(_draftKey);
    if (raw == null || !mounted) return;
    try {
      final m = (jsonDecode(raw) as Map).cast<String, dynamic>();
      setState(() {
        _byOdometer = (m['byOdometer'] as bool?) ?? true;
        _start.text = (m['start'] as String?) ?? '';
        _end.text = (m['end'] as String?) ?? '';
        _distance.text = (m['distance'] as String?) ?? '';
        _passengers.text = (m['passengers'] as String?) ?? '0';
        _notes.text = (m['notes'] as String?) ?? '';
        final ms = m['tripAt'] as int?;
        if (ms != null) {
          _tripAt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
        }
      });
    } on FormatException {
      // Corrupt draft ignored.
    }
  }

  Future<void> _saveDraft() async {
    if (!mounted || _isEdit) return;
    await ref.read(settingsRepositoryProvider).set(
          _draftKey,
          jsonEncode({
            'byOdometer': _byOdometer,
            'start': _start.text,
            'end': _end.text,
            'distance': _distance.text,
            'passengers': _passengers.text,
            'notes': _notes.text,
            'tripAt': _tripAt.millisecondsSinceEpoch,
          }),
        );
  }

  Future<void> _clearDraft() =>
      ref.read(settingsRepositoryProvider).set(_draftKey, null);

  @override
  void dispose() {
    _start.dispose();
    _end.dispose();
    _distance.dispose();
    _passengers.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tripAt,
      firstDate: DateTime.utc(1970),
      lastDate: DateTime.utc(_tripAt.year + 1, 12, 31),
    );
    if (picked == null || !mounted) return;
    setState(
        () => _tripAt = DateTime.utc(picked.year, picked.month, picked.day));
    unawaited(_saveDraft());
  }

  /// The gap (metres) the entered start odometer would leave after the most
  /// recent prior trip that closed with an odometer, or null.
  int? _gapPreview() {
    if (_isEdit || !_byOdometer) return null;
    final parser = ref.read(activeNumeralParserProvider);
    final start = _parseMetres(parser, _start.text);
    if (start == null) return null;
    final trips =
        ref.read(tripHistoryProvider(widget.vehicleId)).asData?.value ??
            const <Trip>[];
    final prior = trips.where((t) => t.endOdometerMetres != null).toList()
      ..sort((a, b) => b.tripAt.epochMillis.compareTo(a.tripAt.epochMillis));
    if (prior.isEmpty) return null;
    return const GapReconciler()
        .between(
          prevEndOdometerMetres: prior.first.endOdometerMetres!,
          nextStartOdometerMetres: start,
        )
        .gapMetres;
  }

  int? _parseMetres(NumeralParser parser, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;
    return parser.parseScaled(trimmed, 3); // km → metres
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _distanceError = null;
    });
    final l10n = AppLocalizations.of(context);

    if (_isEdit) {
      final result = await ref.read(tripsRepositoryProvider).updateDetails(
            widget.tripId!,
            classification: _classification,
            passengerCount: int.tryParse(_passengers.text.trim()) ?? 0,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      if (result.isErr) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
        return;
      }
      if (mounted) context.pop();
      return;
    }

    final parser = ref.read(activeNumeralParserProvider);
    final result = await ref.read(tripsRepositoryProvider).add(
          vehicleId: widget.vehicleId,
          tripAt: Instant.fromDateTime(_tripAt),
          startOdometerMetres:
              _byOdometer ? _parseMetres(parser, _start.text) : null,
          endOdometerMetres:
              _byOdometer ? _parseMetres(parser, _end.text) : null,
          directDistanceMetres:
              _byOdometer ? null : _parseMetres(parser, _distance.text),
          classification: _classification,
          passengerCount: int.tryParse(_passengers.text.trim()) ?? 0,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        );
    if (!mounted) return;
    if (result.isErr) {
      // Never lose the entry: keep the draft, surface a typed failure inline.
      final failure = result.failureOrNull;
      setState(() {
        _busy = false;
        _distanceError = failure is ValidationFailure
            ? _distanceMessage(l10n, failure)
            : null;
      });
      if (failure is! ValidationFailure) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.tripSaveFailed)));
      }
      return;
    }
    await _clearDraft();
    if (mounted) context.pop();
  }

  String _distanceMessage(AppLocalizations l10n, ValidationFailure f) {
    final code = f.fieldErrors
        .firstWhere((e) => e.field == 'distance',
            orElse: () => f.fieldErrors.first)
        .code;
    return code == 'non_positive'
        ? l10n.tripDistanceNonPositive
        : l10n.tripDistanceRequired;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final fmt = ref.watch(activeNumeralFormatProvider);
    final cal = ref.watch(activeCalendarProvider);
    final vehicle = ref.watch(vehicleProvider(widget.vehicleId)).asData?.value;
    final unit = distanceUnitOf(vehicle?.distanceUnit);
    final gap = _gapPreview();

    return PulseScaffold(
      title: _isEdit ? l10n.tripEditTitle : l10n.tripAddTitle,
      actions: [
        if (_isEdit)
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: l10n.tripDelete,
            onPressed: _busy ? null : _delete,
          ),
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.tripSave),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          if (!_isEdit) ...[
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(value: true, label: Text(l10n.tripByOdometer)),
                ButtonSegment(value: false, label: Text(l10n.tripByDistance)),
              ],
              selected: {_byOdometer},
              onSelectionChanged: (s) => setState(() => _byOdometer = s.first),
            ),
            const SizedBox(height: PulseTokens.s3),
            if (_byOdometer) ...[
              TextField(
                controller: _start,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) {
                  setState(() {}); // refresh the gap preview
                  unawaited(_saveDraft());
                },
                decoration: InputDecoration(labelText: l10n.tripStartOdometer),
              ),
              const SizedBox(height: PulseTokens.s2),
              TextField(
                controller: _end,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => unawaited(_saveDraft()),
                decoration: InputDecoration(labelText: l10n.tripEndOdometer),
              ),
            ] else
              TextField(
                controller: _distance,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => unawaited(_saveDraft()),
                decoration: InputDecoration(labelText: l10n.tripDistance),
              ),
            if (_distanceError != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: PulseTokens.s1),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16),
                    const SizedBox(width: PulseTokens.sHalf),
                    Expanded(child: Text(_distanceError!)),
                  ],
                ),
              ),
            if (gap != null && gap > 0)
              Padding(
                padding: const EdgeInsetsDirectional.only(top: PulseTokens.s1),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 16),
                    const SizedBox(width: PulseTokens.sHalf),
                    Expanded(
                      child: Text(
                          l10n.tripGapPreview(formatDistance(fmt, gap, unit))),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: PulseTokens.s3),
          ] else
            _ReadonlyDistance(
                trip: _existing, unit: unit, fmt: fmt, l10n: l10n),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined),
            title: Text(l10n.tripDate),
            subtitle:
                Text(formatTripDate(cal, fmt, Instant.fromDateTime(_tripAt))),
            trailing: Icon(Icons.adaptive.arrow_forward),
            onTap: _isEdit ? null : _pickDate,
          ),
          DropdownButtonFormField<TripClassification>(
            initialValue: _classification,
            isExpanded: true,
            decoration:
                InputDecoration(labelText: l10n.tripClassificationLabel),
            items: [
              for (final c in TripClassification.values)
                DropdownMenuItem(
                  value: c,
                  child: Text(classificationBadge(l10n, c).$2),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _classification = v);
            },
          ),
          const SizedBox(height: PulseTokens.s2),
          TextField(
            controller: _passengers,
            keyboardType: TextInputType.number,
            onChanged: (_) => unawaited(_saveDraft()),
            decoration: InputDecoration(labelText: l10n.tripPassengers),
          ),
          const SizedBox(height: PulseTokens.s2),
          TextField(
            controller: _notes,
            onChanged: (_) => unawaited(_saveDraft()),
            decoration: InputDecoration(labelText: l10n.tripNote),
          ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final result =
        await ref.read(tripsRepositoryProvider).softDelete(widget.tripId!);
    if (!mounted) return;
    if (result.isErr) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).tripSaveFailed)),
      );
      return;
    }
    if (mounted) context.pop();
  }
}

class _ReadonlyDistance extends StatelessWidget {
  const _ReadonlyDistance({
    required this.trip,
    required this.unit,
    required this.fmt,
    required this.l10n,
  });

  final Trip? trip;
  final DistanceUnit unit;
  final NumeralFormat fmt;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (trip == null) return const SizedBox.shrink();
    return PulseCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.route_outlined),
        title: Text(formatDistance(fmt, trip!.distanceMetres, unit)),
        subtitle: Text(l10n.tripDistanceLocked),
      ),
    );
  }
}
