import 'dart:convert';
import 'dart:math';

import 'package:core/core.dart';
import 'package:cryptography/cryptography.dart';

import 'key_envelope.dart';
import 'secure_store.dart';
import 'unlock_policy.dart';

/// Persists the security items behind the [SecureStore] port (F7-T5): the
/// wrapped-key envelope, the recovery envelope, the PIN verifier (a salted hash
/// — never the PIN), and the throttle state. Items are schema-versioned for
/// migration; [reset] wipes everything (factory-reset security). Result-typed —
/// a platform failure and a missing item are distinguishable from a corrupt one.
final class SecureVault {
  SecureVault(this._store, {Random? rng}) : _rng = rng ?? Random.secure();

  final SecureStore _store;
  final Random _rng;

  static const int schemaVersion = 1;
  static const _kVersion = 'sec.schema_version';
  static const _kEnvelope = 'sec.envelope';
  static const _kRecovery = 'sec.recovery';
  static const _kThrottle = 'sec.throttle';
  static const _kPin = 'sec.pin_verifier';
  static const _kLockPrefs = 'sec.lock_prefs';

  /// Whether the master key has been set up (an envelope exists).
  Future<Result<bool, SecurityFailure>> isConfigured() async {
    try {
      return Ok((await _store.read(_kEnvelope)) != null);
    } on Object {
      return const Err(SecureStorageFailed());
    }
  }

  Future<Result<void, SecurityFailure>> saveEnvelope(KeyEnvelope env) =>
      _writeJson(_kEnvelope, env.toJson());

  /// `Ok(null)` = first-run (no envelope); `Err(EnvelopeCorrupt)` = present but
  /// unparseable; `Err(SecureStorageFailed)` = platform read failure.
  Future<Result<KeyEnvelope?, SecurityFailure>> loadEnvelope() =>
      _loadEnvelope(_kEnvelope);

  Future<Result<void, SecurityFailure>> saveRecovery(KeyEnvelope env) =>
      _writeJson(_kRecovery, env.toJson());
  Future<Result<KeyEnvelope?, SecurityFailure>> loadRecovery() =>
      _loadEnvelope(_kRecovery);

  Future<Result<void, SecurityFailure>> saveThrottle(ThrottleState s) =>
      _writeJson(_kThrottle, s.toJson());

  Future<Result<ThrottleState, SecurityFailure>> loadThrottle() async {
    final r = await _readJson(_kThrottle);
    if (r case Err(:final failure)) return Err(failure);
    final json = (r as Ok<Map<String, dynamic>?, SecurityFailure>).value;
    return Ok(
        json == null ? const ThrottleState() : ThrottleState.fromJson(json));
  }

  /// Store a salted hash of [pin] — never the PIN itself.
  Future<Result<void, SecurityFailure>> savePin(String pin) async {
    final salt = _randomBytes(16);
    final hash = await _pinHash(pin, salt);
    return _writeJson(_kPin, {
      'salt': base64.encode(salt),
      'hash': base64.encode(hash),
    });
  }

  /// Verify [pin] against the stored verifier (constant-time). `Ok(false)` when
  /// no PIN is set or the PIN is wrong.
  Future<Result<bool, SecurityFailure>> verifyPin(String pin) async {
    final r = await _readJson(_kPin);
    if (r case Err(:final failure)) return Err(failure);
    final value = (r as Ok<Map<String, dynamic>?, SecurityFailure>).value;
    if (value == null) return const Ok(false);
    try {
      final salt = base64.decode(value['salt'] as String);
      final expected = base64.decode(value['hash'] as String);
      final actual = await _pinHash(pin, salt);
      return Ok(_constEq(actual, expected));
    } on Object {
      return const Err(EnvelopeCorrupt());
    }
  }

  /// Whether an app-lock PIN has been set.
  Future<Result<bool, SecurityFailure>> hasPin() async {
    final r = await _readJson(_kPin);
    if (r case Err(:final failure)) return Err(failure);
    return Ok((r as Ok<Map<String, dynamic>?, SecurityFailure>).value != null);
  }

  Future<Result<void, SecurityFailure>> saveLockPrefs(LockPrefs prefs) =>
      _writeJson(_kLockPrefs, prefs.toJson());

  /// The persisted app-lock prefs, or [LockPrefs.disabled] when unset.
  Future<Result<LockPrefs, SecurityFailure>> loadLockPrefs() async {
    final r = await _readJson(_kLockPrefs);
    if (r case Err(:final failure)) return Err(failure);
    final json = (r as Ok<Map<String, dynamic>?, SecurityFailure>).value;
    return Ok(json == null ? LockPrefs.disabled : LockPrefs.fromJson(json));
  }

  /// Wipe every security item (factory reset) — data becomes unrecoverable.
  Future<void> reset() => _store.deleteAll();

  // ── internals ───────────────────────────────────────────────────────────
  Future<Result<KeyEnvelope?, SecurityFailure>> _loadEnvelope(
      String key) async {
    final r = await _readJson(key);
    if (r case Err(:final failure)) return Err(failure);
    final json = (r as Ok<Map<String, dynamic>?, SecurityFailure>).value;
    if (json == null) return const Ok(null);
    final env = KeyEnvelope.tryFromJson(json);
    return env == null ? const Err(EnvelopeCorrupt()) : Ok(env);
  }

  Future<Result<Map<String, dynamic>?, SecurityFailure>> _readJson(
    String key,
  ) async {
    final String? raw;
    try {
      raw = await _store.read(key);
    } on Object {
      return const Err(SecureStorageFailed());
    }
    if (raw == null) return const Ok(null);
    try {
      return Ok(jsonDecode(raw) as Map<String, dynamic>);
    } on Object {
      return const Err(EnvelopeCorrupt());
    }
  }

  Future<Result<void, SecurityFailure>> _writeJson(
    String key,
    Map<String, dynamic> json,
  ) async {
    try {
      await _store.write(_kVersion, '$schemaVersion');
      await _store.write(key, jsonEncode(json));
      return const Ok(null);
    } on Object {
      return const Err(SecureStorageFailed());
    }
  }

  Future<List<int>> _pinHash(String pin, List<int> salt) async {
    final digest = await Sha256().hash([...salt, ...utf8.encode(pin)]);
    return digest.bytes;
  }

  List<int> _randomBytes(int n) => List.generate(n, (_) => _rng.nextInt(256));

  bool _constEq(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}
