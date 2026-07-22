import 'package:core/core.dart';
import 'package:data/data.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:l10n/l10n.dart';

import '../../../settings/locale_controller.dart';
import '../../../shell/shell_state.dart';
import '../application/vehicle_enums.dart';

/// The powertrain-adaptive add/edit vehicle form (M2-T2). Field visibility is
/// driven by [PowertrainProfile] from the chosen type + energy; hidden-field
/// values are preserved (their controllers live for the form's lifetime, so
/// switching energy back restores what was typed). VIN is decoded live and
/// rendered LTR (bidi-isolated) even under RTL. Numeric input honours the active
/// numeral system and the vehicle's display units.
class VehicleFormScreen extends ConsumerStatefulWidget {
  const VehicleFormScreen({this.vehicleId, super.key});

  /// Null → add a new vehicle; otherwise edit the existing one.
  final String? vehicleId;

  @override
  ConsumerState<VehicleFormScreen> createState() => _VehicleFormScreenState();
}

class _VehicleFormScreenState extends ConsumerState<VehicleFormScreen> {
  static const _profile = PowertrainProfile();
  static const _vinDecoder = VinDecoder();

  final _nickname = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _trim = TextEditingController();
  final _year = TextEditingController();
  final _plate = TextEditingController();
  final _vin = TextEditingController();
  final _tank = TextEditingController();
  final _battery = TextEditingController();
  final _usable = TextEditingController();

  VehicleType _type = VehicleType.car;
  EnergyType? _energy;
  EnergyType? _secondary;
  bool _distanceTracking = true;
  bool _busy = false;
  bool _submitted = false;
  VinDecodeResult? _vinResult;

  bool get _isEdit => widget.vehicleId != null;

  @override
  void initState() {
    super.initState();
    _vin.addListener(_onVinChanged);
    if (_isEdit) _load();
  }

  Future<void> _load() async {
    final v =
        (await ref.read(vehiclesRepositoryProvider).getById(widget.vehicleId!))
            .valueOrNull;
    if (v == null || !mounted) return;
    final fmt = ref.read(activeNumeralFormatProvider);
    setState(() {
      _nickname.text = v.nickname;
      _make.text = v.make ?? '';
      _model.text = v.model ?? '';
      _trim.text = v.trim ?? '';
      _year.text = v.modelYear == null ? '' : fmt.formatInt(v.modelYear!);
      _plate.text = v.licensePlate ?? '';
      _vin.text = v.vin ?? '';
      _type = vehicleTypeFromCode(v.vehicleType);
      _energy = energyTypeFromCode(v.energyType);
      _secondary = energyTypeFromCode(v.secondaryEnergyType);
      _distanceTracking = v.distanceTrackingEnabled;
      if (v.tankCapacityMl != null) {
        _tank.text = fmt.formatScaled(v.tankCapacityMl!, 3); // mL → L display
      }
      if (v.batteryCapacityJoules != null) {
        _battery.text = _joulesToKwhText(v.batteryCapacityJoules!, fmt);
      }
      if (v.usableCapacityJoules != null) {
        _usable.text = _joulesToKwhText(v.usableCapacityJoules!, fmt);
      }
    });
  }

  void _onVinChanged() {
    final text = _vin.text.trim();
    setState(() => _vinResult = text.isEmpty ? null : _vinDecoder.decode(text));
  }

  @override
  void dispose() {
    for (final c in [
      _nickname, _make, _model, _trim, _year, _plate, _vin, //
      _tank, _battery, _usable,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Set<VehicleField> get _visible => _profile.fieldsFor(
        type: _type,
        energy: _energy,
        secondaryEnergy: _secondary,
      );

  String _joulesToKwhText(int joules, NumeralFormat fmt) {
    final kwh = Energy.joules(joules).toDisplay(EnergyUnit.kilowattHour);
    return fmt.formatScaled((kwh * 1000).round(), 3); // kWh with 3 decimals
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _submitted = true);
    final name = _nickname.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);

    final parser = ref.read(activeNumeralParserProvider);
    final vehicles = ref.read(vehiclesRepositoryProvider);
    final vinText = _vin.text.trim();
    final vinResult = vinText.isEmpty ? null : _vinDecoder.decode(vinText);

    final edit = VehicleEdit(
      nickname: name,
      make: _textOrNull(_make),
      model: _textOrNull(_model),
      trim: _textOrNull(_trim),
      modelYear: parser.parseScaled(_year.text, 0),
      vehicleType: _type.name,
      energyType: _energy?.name,
      secondaryEnergyType: _secondary?.name,
      vin: vinText.isEmpty ? null : vinText.toUpperCase(),
      vinChecksumValid: vinResult?.checkDigitValid,
      wmiDecoded: _wmiSummary(vinResult),
      licensePlate: _textOrNull(_plate),
      tankCapacityMl: _visible.contains(VehicleField.tankCapacity)
          ? _mlFrom(_tank, parser)
          : null,
      batteryCapacityJoules: _visible.contains(VehicleField.batteryCapacity)
          ? _joulesFrom(_battery, parser)
          : null,
      usableCapacityJoules: _visible.contains(VehicleField.usableCapacity)
          ? _joulesFrom(_usable, parser)
          : null,
      distanceTrackingEnabled: _distanceTracking,
    );

    final String? id;
    if (_isEdit) {
      id = widget.vehicleId;
      await vehicles.update(id!, edit);
    } else {
      final created = await vehicles.add(nickname: name);
      id = created.valueOrNull?.id;
      if (id != null) {
        await vehicles.update(id, edit);
        await ref.read(shellStateControllerProvider).setActiveVehicle(id);
      }
    }
    if (mounted) context.pop();
  }

  String? _textOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  int? _mlFrom(TextEditingController c, NumeralParser parser) =>
      c.text.trim().isEmpty ? null : parser.parseScaled(c.text, 3); // L → mL

  int? _joulesFrom(TextEditingController c, NumeralParser parser) {
    if (c.text.trim().isEmpty) return null;
    final milliKwh = parser.parseScaled(c.text, 3);
    if (milliKwh == null) return null;
    return Energy.fromDisplay(EnergyUnit.kilowattHour, milliKwh / 1000).joules;
  }

  String? _wmiSummary(VinDecodeResult? r) {
    if (r == null || r.manufacturer == null) return null;
    return r.modelYear == null
        ? r.manufacturer
        : '${r.manufacturer} · ${r.modelYear}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final visible = _visible;

    return PulseScaffold(
      title: _isEdit ? l10n.vehicleEditTitle : l10n.vehicleAddTitle,
      actions: [
        TextButton(
          onPressed: _busy ? null : _save,
          child: Text(l10n.vehicleSave),
        ),
      ],
      body: ListView(
        padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
        children: [
          SectionHeader(title: l10n.vehicleSectionIdentity),
          _text(_nickname, l10n.vehicleName,
              errorText: _submitted && _nickname.text.trim().isEmpty
                  ? l10n.vehicleNameRequired
                  : null),
          _text(_make, l10n.vehicleMake),
          _text(_model, l10n.vehicleModel),
          _text(_trim, l10n.vehicleTrim),
          _text(_year, l10n.vehicleYear, keyboard: TextInputType.number),
          _text(_plate, l10n.vehiclePlate, forceLtr: true),
          _vinField(l10n),
          const SizedBox(height: PulseTokens.s3),
          SectionHeader(title: l10n.vehicleSectionPowertrain),
          _typeDropdown(l10n),
          _energyDropdown(l10n),
          if (visible.contains(VehicleField.tankCapacity))
            _text(_tank, l10n.vehicleTankCapacity,
                keyboard: TextInputType.number),
          if (visible.contains(VehicleField.batteryCapacity))
            _text(_battery, l10n.vehicleBatteryCapacity,
                keyboard: TextInputType.number),
          if (visible.contains(VehicleField.usableCapacity))
            _text(_usable, l10n.vehicleUsableCapacity,
                keyboard: TextInputType.number),
          SwitchListTile.adaptive(
            value: _distanceTracking,
            onChanged: (v) => setState(() => _distanceTracking = v),
            title: Text(l10n.vehicleTrackDistance),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _text(
    TextEditingController controller,
    String label, {
    String? errorText,
    TextInputType? keyboard,
    bool forceLtr = false,
  }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        textDirection: forceLtr ? TextDirection.ltr : null,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(labelText: label, errorText: errorText),
      ),
    );
  }

  Widget _vinField(AppLocalizations l10n) {
    final r = _vinResult;
    final pc = Theme.of(context).extension<PulseColorsExt>()!.c;
    String? helper;
    Widget? icon;
    if (r != null && r.wellFormed) {
      helper = r.checkDigitValid ? l10n.vinChecksumOk : l10n.vinChecksumBad;
      icon = Icon(
        r.checkDigitValid ? Icons.verified_outlined : Icons.error_outline,
        color: r.checkDigitValid ? pc.okText : pc.text2,
      );
    }
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _vin,
            textDirection: TextDirection.ltr, // VIN is always LTR
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: l10n.vehicleVin,
              helperText: helper,
              suffixIcon: icon,
            ),
          ),
          if (r?.manufacturer != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: PulseTokens.sHalf),
              child: LtrText(_wmiSummary(r) ?? '',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Widget _typeDropdown(AppLocalizations l10n) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
        child: DropdownButtonFormField<VehicleType>(
          key: const Key('vehicleTypeField'),
          initialValue: _type,
          decoration: InputDecoration(labelText: l10n.vehicleTypeLabel),
          items: [
            for (final t in VehicleType.values)
              DropdownMenuItem(
                  value: t, child: Text(vehicleTypeLabel(l10n, t))),
          ],
          onChanged: (t) => setState(() {
            _type = t ?? _type;
            _distanceTracking = _profile.distanceTrackingByDefault(_type);
          }),
        ),
      );

  Widget _energyDropdown(AppLocalizations l10n) => Padding(
        padding: const EdgeInsetsDirectional.only(bottom: PulseTokens.s2),
        child: DropdownButtonFormField<EnergyType?>(
          key: const Key('energyField'),
          initialValue: _energy,
          decoration: InputDecoration(labelText: l10n.vehicleEnergyLabel),
          items: [
            DropdownMenuItem(child: Text(l10n.energyNone)),
            for (final e in EnergyType.values)
              DropdownMenuItem(value: e, child: Text(energyTypeLabel(l10n, e))),
          ],
          // Changing energy recomputes visible fields; hidden controllers keep
          // their values so switching back restores them (M2-T2 AC).
          onChanged: (e) => setState(() => _energy = e),
        ),
      );
}
