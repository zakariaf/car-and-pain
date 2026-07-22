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

/// The energy-adaptive fuel/charge quick-add form (M3-T4). Liquid mode shows
/// volume + unit price + total with **enter-any-two** (any two derive the
/// third at 3-decimal precision); charge mode swaps in kWh / SoC / home-charge.
/// Full/partial, missed-fill, exclude-from-economy and free are all reachable,
/// in-progress input autosaves to a draft, and it pre-fills the last station/
/// price for the vehicle so a routine top-up is a two-tap confirm.
class FuelEntryFormScreen extends ConsumerStatefulWidget {
  const FuelEntryFormScreen({required this.vehicleId, super.key});

  final String vehicleId;

  @override
  ConsumerState<FuelEntryFormScreen> createState() => _FuelFormState();
}

class _FuelFormState extends ConsumerState<FuelEntryFormScreen> {
  final _odometer = TextEditingController();
  final _volume = TextEditingController();
  final _price = TextEditingController();
  final _total = TextEditingController();
  final _energyKwh = TextEditingController();
  final _startSoc = TextEditingController();
  final _endSoc = TextEditingController();
  final _station = TextEditingController();

  bool _isCharge = false;
  bool _fullTank = true;
  bool _missed = false;
  bool _exclude = false;
  bool _free = false;
  bool _homeCharge = false;
  bool _busy = false;
  bool _submitted = false;
  bool _computing = false;

  String get _draftKey => 'draft:fuel:${widget.vehicleId}';

  @override
  void initState() {
    super.initState();
    for (final c in [_volume, _price, _total]) {
      c.addListener(_recompute);
    }
    _prefillAndDraft();
  }

  Future<void> _prefillAndDraft() async {
    // Pre-fill last station/price from the most recent entry for this vehicle.
    final last = (await ref
            .read(fuelRepositoryProvider)
            .watchByVehicle(widget.vehicleId)
            .first)
        .firstOrNull;
    if (!mounted) return;
    final vehicle = ref.read(vehicleProvider(widget.vehicleId)).asData?.value;
    if (mounted) {
      setState(() {
        _isCharge = vehicle?.energyType == 'electric';
        if (last != null) {
          _station.text = last.stationName ?? '';
          final fmt = ref.read(activeNumeralFormatProvider);
          if (last.pricePerUnitThousandths != null) {
            _price.text = fmt.formatScaled(last.pricePerUnitThousandths!, 3);
          }
        }
      });
    }
    // Then overlay any saved draft.
    final raw = await ref.read(settingsRepositoryProvider).get(_draftKey);
    if (raw == null || !mounted) return;
    try {
      _restore((jsonDecode(raw) as Map).cast<String, dynamic>());
    } on FormatException {
      // Corrupt draft ignored.
    }
  }

  void _recompute() {
    if (_computing || _isCharge || !mounted) return;
    final parser = ref.read(activeNumeralParserProvider);
    final vol = parser.parseScaled(_volume.text, 3); // L → mL
    final price = parser.parseScaled(_price.text, 3); // per-L thousandths
    final exp = _exponent();
    final total = parser.parseScaled(_total.text, exp);
    // Only auto-fill the total when volume + price are present and total blank.
    if (vol != null && price != null && _total.text.trim().isEmpty) {
      final r =
          completeFill(exponent: exp, volumeMl: vol, priceThousandths: price);
      if (r != null) {
        _computing = true;
        _total.text = ref
            .read(activeNumeralFormatProvider)
            .formatScaled(r.totalMinor, exp);
        _computing = false;
      }
    } else if (vol != null && total != null && _price.text.trim().isEmpty) {
      final r = completeFill(exponent: exp, volumeMl: vol, totalMinor: total);
      if (r != null) {
        _computing = true;
        _price.text = ref
            .read(activeNumeralFormatProvider)
            .formatScaled(r.priceThousandths, 3);
        _computing = false;
      }
    }
    unawaited(_saveDraft());
  }

  int _exponent() {
    final code = ref
            .read(vehicleProvider(widget.vehicleId))
            .asData
            ?.value
            ?.currencyCode ??
        'EUR';
    return Currency.tryParse(code)?.exponent ?? 2;
  }

  Map<String, dynamic> _snapshot() => {
        'odometer': _odometer.text,
        'volume': _volume.text,
        'price': _price.text,
        'total': _total.text,
        'energyKwh': _energyKwh.text,
        'startSoc': _startSoc.text,
        'endSoc': _endSoc.text,
        'station': _station.text,
        'isCharge': _isCharge,
        'fullTank': _fullTank,
        'missed': _missed,
        'exclude': _exclude,
        'free': _free,
        'homeCharge': _homeCharge,
      };

  void _restore(Map<String, dynamic> m) {
    String s(String k) => (m[k] as String?) ?? '';
    setState(() {
      _odometer.text = s('odometer');
      _volume.text = s('volume');
      _price.text = s('price');
      _total.text = s('total');
      _energyKwh.text = s('energyKwh');
      _startSoc.text = s('startSoc');
      _endSoc.text = s('endSoc');
      _station.text = s('station');
      _isCharge = (m['isCharge'] as bool?) ?? _isCharge;
      _fullTank = (m['fullTank'] as bool?) ?? true;
      _missed = (m['missed'] as bool?) ?? false;
      _exclude = (m['exclude'] as bool?) ?? false;
      _free = (m['free'] as bool?) ?? false;
      _homeCharge = (m['homeCharge'] as bool?) ?? false;
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
    for (final c in [
      _odometer, _volume, _price, _total, _energyKwh, //
      _startSoc, _endSoc, _station,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _submitted = true);
    final parser = ref.read(activeNumeralParserProvider);
    final odo = parser.parseScaled(_odometer.text, 3); // km → metres
    if (odo == null) return;
    setState(() => _busy = true);

    final exp = _exponent();
    final vehicle = ref.read(vehicleProvider(widget.vehicleId)).asData?.value;
    final currency = vehicle?.currencyCode ?? 'EUR';
    final total = _free ? 0 : (parser.parseScaled(_total.text, exp) ?? 0);

    var volumeMl = 0;
    int? energyJoules;
    if (_isCharge) {
      final kwh = parser.parseScaled(_energyKwh.text, 3); // milli-kWh
      if (kwh != null) {
        energyJoules =
            Energy.fromDisplay(EnergyUnit.kilowattHour, kwh / 1000).joules;
      } else {
        final start = parser.parseScaled(_startSoc.text, 0);
        final end = parser.parseScaled(_endSoc.text, 0);
        if (start != null &&
            end != null &&
            vehicle?.usableCapacityJoules != null) {
          energyJoules = energyFromSocJoules(
            startSocPct: start,
            endSocPct: end,
            usableCapacityJoules: vehicle!.usableCapacityJoules!,
          );
        }
      }
    } else {
      volumeMl = parser.parseScaled(_volume.text, 3) ?? 0;
    }

    await ref.read(fuelRepositoryProvider).add(
          vehicleId: widget.vehicleId,
          filledAt: Instant.fromDateTime(const SystemClock().nowUtc()),
          odometerMetres: odo,
          volumeMl: volumeMl,
          totalCostMinor: total,
          currencyCode: currency,
          isFullTank: _isCharge || _fullTank,
          isMissedPrevious: _missed,
          excludeFromEconomy: _exclude,
          isFree: _free,
          fuelType:
              _isCharge ? 'electric' : (vehicle?.energyType ?? 'gasoline'),
          energyJoules: energyJoules,
          pricePerUnitThousandths: parser.parseScaled(_price.text, 3),
          startSocPct: _isCharge ? parser.parseScaled(_startSoc.text, 0) : null,
          endSocPct: _isCharge ? parser.parseScaled(_endSoc.text, 0) : null,
          isHomeCharge: _homeCharge,
          stationName:
              _station.text.trim().isEmpty ? null : _station.text.trim(),
        );
    await _clearDraft();
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return PulseScaffold(
      title: l10n.fuelAddTitle,
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.vehicleSave),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          _field(_odometer, l10n.vehicleOdometer,
              number: true,
              error: _submitted && _odometer.text.trim().isEmpty
                  ? l10n.vehicleNameRequired
                  : null),
          SwitchListTile.adaptive(
            value: _isCharge,
            onChanged: (v) => setState(() => _isCharge = v),
            title: Text(l10n.fuelSectionCharge),
            contentPadding: EdgeInsets.zero,
          ),
          if (_isCharge) ...[
            _field(_energyKwh, l10n.fuelEnergyKwh, number: true),
            _field(_startSoc, l10n.fuelStartSoc, number: true),
            _field(_endSoc, l10n.fuelEndSoc, number: true),
            SwitchListTile.adaptive(
              value: _homeCharge,
              onChanged: (v) => setState(() => _homeCharge = v),
              title: Text(l10n.fuelHomeCharge),
              contentPadding: EdgeInsets.zero,
            ),
          ] else ...[
            _field(_volume, l10n.fuelVolume, number: true),
            SwitchListTile.adaptive(
              value: _fullTank,
              onChanged: (v) => setState(() => _fullTank = v),
              title: Text(l10n.fuelFullTank),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              value: _missed,
              onChanged: (v) => setState(() => _missed = v),
              title: Text(l10n.fuelMissedFill),
              contentPadding: EdgeInsets.zero,
            ),
            SwitchListTile.adaptive(
              value: _exclude,
              onChanged: (v) => setState(() => _exclude = v),
              title: Text(l10n.fuelExcludeEconomy),
              contentPadding: EdgeInsets.zero,
            ),
          ],
          _field(_price, l10n.fuelPricePerUnit, number: true),
          _field(_total, l10n.fuelTotalCost, number: true, enabled: !_free),
          SwitchListTile.adaptive(
            value: _free,
            onChanged: (v) => setState(() => _free = v),
            title: Text(l10n.fuelFree),
            contentPadding: EdgeInsets.zero,
          ),
          _field(_station, l10n.fuelStation),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label, {
    bool number = false,
    bool enabled = true,
    String? error,
  }) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
        child: TextField(
          controller: c,
          enabled: enabled,
          keyboardType: number ? TextInputType.number : null,
          onChanged: (_) => unawaited(_saveDraft()),
          decoration: InputDecoration(labelText: label, errorText: error),
        ),
      );
}
