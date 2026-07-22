/// Car and Pain — `security`.
///
/// The at-rest security core (F7): the master-key lifecycle (CSPRNG key,
/// Argon2id KEK, AES-256-GCM wrap/unwrap, one-time recovery code, passphrase
/// re-wrap), the versioned wrapped-key envelope, and the pure PIN-throttling /
/// lock-timeout logic. Result-typed; no plugins. Native acceleration, secure
/// storage, biometrics, and DB keying are wired in the app.
library;

export 'src/blob_sealer.dart' show BlobSealer, SealedBlob;
export 'src/kdf_calibrator.dart' show KdfCalibrator;
export 'src/key_envelope.dart' show Argon2idParams, KeyEnvelope;
export 'src/key_manager.dart' show KeyManager;
export 'src/master_key_service.dart' show MasterKeyService, MasterKeySetup;
export 'src/redaction.dart' show RedactionSpec, redactExport;
export 'src/secure_store.dart' show InMemorySecureStore, SecureStore;
export 'src/secure_vault.dart' show SecureVault;
export 'src/unlock_policy.dart'
    show LockPolicy, LockPrefs, PinThrottle, ThrottleState;
