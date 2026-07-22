import 'dart:math';

import 'package:core/core.dart';

import 'key_envelope.dart';
import 'key_manager.dart';
import 'secure_vault.dart';

/// Orchestrates the master-key lifecycle over the [SecureVault] (F7-T3/T5): mint
/// on first run, wrap under a passphrase (+ a one-time recovery code), persist
/// both envelopes, and unlock back to the raw key that opens the encrypted DB.
///
/// Pure over the vault's `SecureStore` port — no plugins — so the whole flow is
/// unit-tested. The app feeds [toHexKey] to the SQLCipher opener; the platform
/// (biometric gate, native Argon2, keystore) lives in the app layer.
final class MasterKeyService {
  MasterKeyService({
    required SecureVault vault,
    KeyManager? keyManager,
    Random? rng,
  })  : _vault = vault,
        _km = keyManager ?? KeyManager(rng: rng);

  final SecureVault _vault;
  final KeyManager _km;

  /// The master key as the 64-char hex SQLCipher raw key.
  static String toHexKey(List<int> masterKey) => KeyManager.toHexKey(masterKey);

  /// Whether security has been set up (an envelope exists).
  Future<Result<bool, SecurityFailure>> isConfigured() => _vault.isConfigured();

  /// First-run setup: mint a master key, wrap it under [passphrase] and a
  /// one-time recovery code, persist both envelopes. Returns the raw key (to
  /// open the DB now) and the recovery code (to surface exactly once).
  Future<Result<MasterKeySetup, SecurityFailure>> setup({
    required String passphrase,
    Argon2idParams params = Argon2idParams.floor,
  }) =>
      _protect(_km.generateMasterKey(), passphrase, params);

  /// Make an **already-generated** key recoverable: wrap the existing DB key
  /// (e.g. the F2 keystore key) under [passphrase] + a one-time recovery code
  /// and persist both envelopes — the key is unchanged, so the open DB keeps
  /// working while gaining a recovery path. This is how "recoverable by default"
  /// is switched on without re-encrypting the database.
  Future<Result<MasterKeySetup, SecurityFailure>> protectExistingKey({
    required List<int> masterKey,
    required String passphrase,
    Argon2idParams params = Argon2idParams.floor,
  }) =>
      _protect(masterKey, passphrase, params);

  Future<Result<MasterKeySetup, SecurityFailure>> _protect(
    List<int> master,
    String passphrase,
    Argon2idParams params,
  ) async {
    final envelope = await _km.wrap(master, passphrase, params: params);
    final recovery = await _km.createRecovery(master, params: params);

    final saved = await _vault.saveEnvelope(envelope);
    if (saved case Err(:final failure)) return Err(failure);
    final savedRec = await _vault.saveRecovery(recovery.envelope);
    if (savedRec case Err(:final failure)) return Err(failure);

    return Ok((masterKey: master, recoveryCode: recovery.code));
  }

  /// Unlock with the passphrase → the raw master key.
  Future<Result<List<int>, SecurityFailure>> unlockWithPassphrase(
    String passphrase,
  ) async =>
      _unlock(await _vault.loadEnvelope(), passphrase);

  /// Unlock with the one-time recovery code → the raw master key. Input is
  /// re-canonicalised, so lost dashes or lowercase still verify. Does NOT
  /// consume the code — see [redeemRecovery] for single-use redemption.
  Future<Result<List<int>, SecurityFailure>> unlockWithRecovery(
    String code,
  ) async =>
      _unlock(
        await _vault.loadRecovery(),
        KeyManager.formatRecoveryInput(code),
      );

  /// Single-use recovery redemption (F6-T7): unlock with the code, then CONSUME
  /// it so a second redemption of the same code fails. The recovered key is
  /// returned; the caller restores access and re-issues a fresh code
  /// ([regenerateRecovery]). A wrong code fails closed before anything is
  /// consumed.
  Future<Result<List<int>, SecurityFailure>> redeemRecovery(String code) async {
    final master = await unlockWithRecovery(code);
    if (master case Err()) return master; // wrong/absent → nothing consumed
    final removed = await _vault.deleteRecovery();
    if (removed case Err(:final failure)) return Err(failure);
    return master;
  }

  /// Re-wrap the master key under [newPassphrase] (requires the old one). The
  /// recovery envelope is untouched — it still wraps the same master key.
  Future<Result<void, SecurityFailure>> changePassphrase({
    required String oldPassphrase,
    required String newPassphrase,
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    final loaded = await _vault.loadEnvelope();
    if (loaded case Err(:final failure)) return Err(failure);
    final env = (loaded as Ok<KeyEnvelope?, SecurityFailure>).value;
    if (env == null) return const Err(EnvelopeCorrupt());

    final rewrapped = await _km.changePassphrase(
      env,
      oldPassphrase,
      newPassphrase,
      params: params,
    );
    if (rewrapped case Err(:final failure)) return Err(failure);
    return _vault.saveEnvelope(
      (rewrapped as Ok<KeyEnvelope, SecurityFailure>).value,
    );
  }

  /// Mint a fresh recovery code (invalidating the old one) that wraps the same
  /// master key. Requires the passphrase to prove ownership.
  Future<Result<String, SecurityFailure>> regenerateRecovery(
    String passphrase, {
    Argon2idParams params = Argon2idParams.floor,
  }) async {
    final unlocked = await unlockWithPassphrase(passphrase);
    if (unlocked case Err(:final failure)) return Err(failure);
    final master = (unlocked as Ok<List<int>, SecurityFailure>).value;
    final recovery = await _km.createRecovery(master, params: params);
    final saved = await _vault.saveRecovery(recovery.envelope);
    if (saved case Err(:final failure)) return Err(failure);
    return Ok(recovery.code);
  }

  Future<Result<List<int>, SecurityFailure>> _unlock(
    Result<KeyEnvelope?, SecurityFailure> loaded,
    String secret,
  ) async {
    if (loaded case Err(:final failure)) return Err(failure);
    final env = (loaded as Ok<KeyEnvelope?, SecurityFailure>).value;
    // A missing envelope on an unlock path is a corrupt/absent-state error,
    // never "wrong secret" — the caller distinguishes not-set-up from bad-input.
    if (env == null) return const Err(EnvelopeCorrupt());
    return _km.unwrap(env, secret);
  }
}

/// The two artifacts of a first-run setup: the raw master key (to open the DB
/// now) and the recovery code (to show the owner exactly once).
typedef MasterKeySetup = ({List<int> masterKey, String recoveryCode});
