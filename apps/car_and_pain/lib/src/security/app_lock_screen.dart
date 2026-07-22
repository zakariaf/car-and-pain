import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:l10n/l10n.dart';

import '../settings/locale_controller.dart';
import 'app_lock_controller.dart';
import 'pin_pad.dart';
import 'security_providers.dart';

/// The full-screen unlock gate shown while the app is locked (F7-T4). Offers
/// biometric unlock (auto-prompted once when available) and a PIN pad, with an
/// exponential-backoff countdown when throttled. Status is encoded redundantly:
/// a lock icon + text prompt + the error line, never colour alone.
class AppLockScreen extends ConsumerStatefulWidget {
  const AppLockScreen({super.key});

  @override
  ConsumerState<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends ConsumerState<AppLockScreen> {
  String _entered = '';
  bool _wrong = false;
  bool _biometricTried = false;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Auto-offer biometric once after the first frame, if available.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoBiometric());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  int get _now => ref.read(clockProvider).nowUtc().millisecondsSinceEpoch;

  Future<void> _maybeAutoBiometric() async {
    if (_biometricTried) return;
    final state = ref.read(appLockControllerProvider).asData?.value;
    if (state == null || !state.biometricOffered || state.throttled) return;
    _biometricTried = true;
    await _biometric();
  }

  Future<void> _biometric() async {
    final reason = AppLocalizations.of(context).appLockBiometricReason;
    await ref
        .read(appLockControllerProvider.notifier)
        .unlockWithBiometric(reason);
  }

  Future<void> _submit() async {
    final pin = _entered;
    final ok =
        await ref.read(appLockControllerProvider.notifier).submitPin(pin);
    if (!mounted) return;
    setState(() {
      _entered = '';
      _wrong = !ok;
    });
  }

  void _onDigit(String d) {
    if (_entered.length >= kPinLength) return;
    setState(() {
      _entered += d;
      _wrong = false;
    });
    if (_entered.length == kPinLength) unawaited(_submit());
  }

  void _onBackspace() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  void _ensureTicker(bool throttled) {
    if (throttled && _ticker == null) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!throttled && _ticker != null) {
      _ticker!.cancel();
      _ticker = null;
    }
  }

  String _formatRemaining(int untilMillis, NumeralSystem numerals) {
    final remainingMs = (untilMillis - _now).clamp(0, 1 << 31);
    final secs = (remainingMs / 1000).ceil();
    final m = secs ~/ 60;
    final s = secs % 60;
    return numerals.shape('$m:${s.toString().padLeft(2, '0')}');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final pc = theme.extension<PulseColorsExt>()!.c;
    final numerals = ref.watch(localizationPrefsProvider).numeralSystem;
    final state = ref.watch(appLockControllerProvider).asData?.value;

    final lockedUntil = state?.lockedUntilMillis;
    final throttled = lockedUntil != null && lockedUntil > _now;
    _ensureTicker(throttled);

    final String? message;
    if (throttled) {
      message = l10n.appLockLockedFor(_formatRemaining(lockedUntil, numerals));
    } else if (_wrong) {
      message = l10n.appLockWrongPin;
    } else {
      message = null;
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(PulseTokens.s3),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 40, color: pc.text2),
                  const SizedBox(height: PulseTokens.s2),
                  Text(l10n.appLockPrompt, style: theme.textTheme.titleMedium),
                  const SizedBox(height: PulseTokens.s3),
                  PinDots(filled: _entered.length),
                  const SizedBox(height: PulseTokens.s2),
                  SizedBox(
                    height: 24,
                    child: message == null
                        ? null
                        : Text(
                            message,
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: theme.colorScheme.error),
                          ),
                  ),
                  const SizedBox(height: PulseTokens.s2),
                  PinPad(
                    enabled: !throttled,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    onBiometric:
                        (state?.biometricOffered ?? false) ? _biometric : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
