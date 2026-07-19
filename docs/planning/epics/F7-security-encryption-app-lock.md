# F7 · Security, encryption & app-lock

> The three-layer security architecture — whole-DB AES-256 at rest, a recoverable random master key, and a hardware-backed biometric/PIN daily unlock — that makes "buy-once, no telemetry, 100% offline" a guarantee the data can actually keep.

## Goal

Deliver the app's complete at-rest security posture as three cooperating layers:

1. **Mandatory whole-DB AES-256 at rest.** Every byte of the SQLite database (and, per the attachments pipeline, encrypted media) is encrypted with AES-256 — SQLCipher by default (`sqlcipher_flutter_libs`, raw 64-hex PRAGMA key), or Drift `sqlite3mc` only if the week-1 spike links and encrypts on real iOS **and** Android. Encryption is not an opt-in menu toggle; the DB is never written in plaintext.
2. **A random 256-bit master key, recoverable by default.** The key that actually keys the DB is CSPRNG-generated, never derived directly from a human secret. It is wrapped by a Key-Encryption-Key (KEK) derived from the user's passphrase via device-calibrated **Argon2id** (FFI/native), plus a **one-time recovery code** path, so a forgotten passphrase does not mean total data loss — while an un-skippable loss warning makes the residual risk honest.
3. **Hardware-keystore-backed daily unlock.** After first setup the user unlocks each day with **biometric or PIN** (`local_auth`), backed by a key held in the Android Keystore / iOS Secure Enclave via `flutter_secure_storage`, with a PIN fallback path, lock-on-background, and attempt throttling — never re-typing the long passphrase for routine use.

On top of these layers: **sensitive-section scoping** puts medical/ICE and documents behind a re-auth gate, and **redaction flags** strip those sensitive fields from handover/sell exports. All security UI is PULSE-native, fully localized (LTR + RTL), accessible (the redundant-encoding rule applies to lock state and errors), and built-in-first — the only third-party runtime deps are the already-sanctioned `sqlcipher_flutter_libs`/`sqlite3mc`, `flutter_secure_storage`, and `local_auth`, plus a native Argon2id binding.

## Tier & dependencies

- **Tier:** foundation
- **Detail level:** detailed
- **Depends on:**
  - `F1` — project scaffold, pub workspace, DI/provider root, sealed `Result`/`Failure` plumbing.
  - `F2` — data layer (Drift + encrypted SQLite, canonical model, migrations); this epic owns how that DB gets its key.
- **Consumed by (downstream):** F-backup/export (key recovery + redaction), settings-preferences (security control surface), documents-compliance & safety-incidents (sensitive-section scoping), sell-dispose (redacted handover pack).

## References

- [docs/flutter/09-security-privacy.md](../../flutter/09-security-privacy.md) — security & privacy architecture (three-layer model, KDF, keystore).
- [docs/flutter/16-permissions-onboarding-oem.md](../../flutter/16-permissions-onboarding-oem.md) — permissions/onboarding surface where lock setup and rationale live.
- [docs/features/21-settings-preferences.md](../../features/21-settings-preferences.md) — settings control surface for security & app-lock.
- [docs/features/18-data-offline-backup.md](../../features/18-data-offline-backup.md) — backup/export key derivation, recovery-code round-trip, redaction coverage.
- [docs/reference/data-model.md](../../reference/data-model.md) — entities/columns for key material, security settings, and sensitivity/redaction flags.

## Tasks

### F7-T1 · Master key lifecycle

**Description.** Implement the master-key state machine: on first setup, generate a random **256-bit** key from a CSPRNG (never derived from the passphrase). Derive a KEK from the user's passphrase via Argon2id (params from F7-T2), wrap the master key with AES-256-GCM (or AES-KW) under the KEK, and persist the **wrapped key + all KDF params + salt + nonce + a version tag** — but never the raw key at rest. Provide unwrap-on-unlock, passphrase change (re-wrap only, key unchanged), and a one-time **recovery code** that wraps the same master key under a second high-entropy KEK. Expose the lifecycle behind a `KeyManager` returning sealed `Result<T, SecurityFailure>`.

**Acceptance criteria.**
- [ ] Master key is 256 bits from a cryptographic RNG; raw key is never written to disk or logs and lives only in memory while unlocked.
- [ ] Wrapped-key envelope stores: ciphertext, auth tag, KDF id + params, salt, nonce, and a scheme `version` for future migration.
- [ ] Passphrase change re-wraps the existing master key without rekeying the DB (fast, no full re-encrypt).
- [ ] One-time recovery code wraps the same master key under an independent KEK; using it unlocks and forces a new passphrase set.
- [ ] An **un-skippable loss warning** is shown at setup: no passphrase and no recovery code = unrecoverable data.
- [ ] Wrong passphrase / tampered envelope returns a typed `SecurityFailure` (auth-tag failure), never a partial/garbage key.
- [ ] All key operations return `Result`; no exceptions cross the module boundary.

**Size:** M · **Depends on:** F7-T2, F7-T5 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md), [data-model.md](../../reference/data-model.md)

### F7-T2 · KDF calibration spike (week-1 encryption spike)

**Description.** Stand up the FFI/native **Argon2id** binding and a device-calibration routine that measures the device and picks memory/iteration/parallelism params hitting a target derivation time (e.g. ~0.5–1s) within a memory ceiling that won't OOM low-end devices. This is the week-1 encryption spike: it also validates that the chosen encryption backend (`sqlcipher_flutter_libs` default; `sqlite3mc` only if it links and encrypts on real iOS **and** Android) is viable before the rest of F7 commits.

**Acceptance criteria.**
- [ ] Argon2id runs via native/FFI on both iOS and Android with no pure-Dart fallback for the real KDF.
- [ ] Calibration produces params meeting a target time budget under a bounded memory ceiling; params are persisted so unlock reuses them (no re-calibration per unlock).
- [ ] Chosen params, calibration device class, and Argon2id variant are recorded in the key envelope (ties to F7-T1 versioning).
- [ ] Spike explicitly records the backend decision (SQLCipher vs sqlite3mc) with the iOS+Android link/encrypt evidence.
- [ ] Floor params are enforced so a weak device cannot calibrate below a security minimum.
- [ ] Bench harness / notes captured so params can be re-tuned later without guesswork.

**Size:** M · **Depends on:** F1 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md)

### F7-T3 · DB keying integration

**Description.** Feed the raw master key to the encrypted-SQLite backend at open time — SQLCipher raw 64-hex `PRAGMA key` (default) or the `sqlite3mc` equivalent — through the DI root that owns the opened Drift database. Implement a **rekey path** (`PRAGMA rekey` / backend equivalent) for the rotate-master-key case, guarded transactionally. Verify open, read, write, and rekey on **real iOS and Android** hardware, and confirm the on-disk file is not a readable SQLite header (encrypted from byte 0).

**Acceptance criteria.**
- [ ] DB opens only with the correct raw key; a wrong key fails cleanly with a typed `SecurityFailure`, not a corrupt-DB crash.
- [ ] Raw key is passed as bytes/hex and never logged; it is zeroed/dropped from memory on lock where the platform allows.
- [ ] Rekey path re-encrypts in place (or via safe VACUUM-based flow) without data loss, and is atomic against interruption.
- [ ] On-disk DB has no plaintext SQLite header/strings (verified with a hex/`file` check on both platforms).
- [ ] Backend selection (SQLCipher vs sqlite3mc) is centralized so switching is a single config point.
- [ ] Verified end-to-end on physical iOS and Android devices, not just simulators.

**Size:** M · **Depends on:** F7-T1, F7-T2, F2 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md), [data-model.md](../../reference/data-model.md)

### F7-T4 · Biometric / PIN daily unlock

**Description.** Implement the daily unlock surface with `local_auth` biometrics (Face/Touch/fingerprint) and a **PIN fallback**, both backed by a hardware-keystore key (Android Keystore / iOS Keychain-Secure Enclave) that gates access to the in-memory master key. Add **lock-on-background** (obscure content in the app switcher, require re-auth on resume after a configurable timeout), **attempt throttling** with exponential backoff and a lockout, and a "forgot PIN → passphrase / recovery code" escalation. Unlock UI is PULSE-native and fully accessible.

**Acceptance criteria.**
- [ ] Biometric unlock succeeds via `local_auth`; PIN fallback always available (device without/failed biometrics still unlocks).
- [ ] The unlock secret is protected by a hardware-backed key; disabling device biometrics/PIN invalidates and forces re-setup rather than silently exposing data.
- [ ] App locks on background/timeout and blurs/obscures content in the OS app switcher; resume requires re-auth per the configured timeout.
- [ ] PIN attempts are throttled with escalating delay and a lockout after N failures; throttling state survives app restart.
- [ ] "Forgot PIN" escalates to passphrase, then recovery code; never a silent bypass.
- [ ] Lock/unlock state is **redundantly encoded** (icon + label + shape/position), not colour-only; errors are announced to screen readers.
- [ ] Unlock screen works in RTL (fa/ar/ckb) with mirrored layout and localized numerals on the PIN pad.

**Size:** M · **Depends on:** F7-T1, F7-T5 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md), [16-permissions-onboarding-oem.md](../../flutter/16-permissions-onboarding-oem.md)

### F7-T5 · Secure storage wiring

**Description.** Wire `flutter_secure_storage` as the persistence for the wrapped-key envelope, PIN verifier material (salted hash, never the PIN), throttling state, and the hardware-key handle — with correct platform options (Keychain accessibility `first_unlock_this_device`, Android `EncryptedSharedPreferences`/Keystore). Provide **migration** for schema/version bumps of stored items and a hard **reset path** that securely wipes all key material (the "start over / factory reset security" flow).

**Acceptance criteria.**
- [ ] Wrapped key, KDF params, PIN verifier, and throttle state persist across restart and app update.
- [ ] Keychain items use device-only, non-iCloud, first-unlock accessibility; Android uses Keystore-backed storage — nothing exportable in a plaintext backup.
- [ ] Stored-item schema is versioned with a migration path; an older install upgrades without losing access.
- [ ] Reset path wipes every security item atomically and returns the app to first-setup state (data becomes unrecoverable — gated by explicit confirmation).
- [ ] Read/write failures surface as typed `SecurityFailure`, and a missing/corrupt item is distinguishable from a wrong-secret case.

**Size:** S · **Depends on:** F1 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md), [data-model.md](../../reference/data-model.md)

### F7-T6 · Sensitive-section scoping & redaction flags

**Description.** Introduce a **sensitivity classification** on entities/fields (medical/ICE info on drivers, glovebox/documents) and a re-auth gate: viewing or exporting a scoped section requires a fresh biometric/PIN check within a short grace window. Persist per-section **redaction flags** that the backup/export and sell-dispose handover pipelines honor, so a shared handover pack strips medical/ICE and document contents while keeping the vehicle record intact.

**Acceptance criteria.**
- [ ] Data model carries a sensitivity marker (schema column/enum) for scoped sections; migration adds it without data loss.
- [ ] Opening a scoped section triggers re-auth if outside the grace window; a fresh unlock within the window passes through.
- [ ] Redaction flags are settable per sensitive section and stored canonically.
- [ ] Handover / sell-dispose export **omits or masks** redacted fields; a round-trip test proves no sensitive value leaks into the export artifact.
- [ ] Redaction is applied at the export boundary (repository/serializer), not just hidden in the UI.
- [ ] Scoped-section gating and redaction toggles are localized and accessible (redundant status encoding on the lock/redact indicators).

**Size:** M · **Depends on:** F7-T4, F2 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md), [18-data-offline-backup.md](../../features/18-data-offline-backup.md), [21-settings-preferences.md](../../features/21-settings-preferences.md), [data-model.md](../../reference/data-model.md)

### F7-T7 · Security settings & onboarding UI (PULSE)

**Description.** *(Added for a complete vertical slice — schema→repo→logic→**PULSE UI**→i18n.)* Build the security control surface in Settings and the first-run security setup step in onboarding: passphrase creation with strength feedback, recovery-code display + confirm, biometric/PIN enable, lock-timeout selector, sensitive-section and redaction toggles, and the un-skippable loss warning. All PULSE-native components, warm-paper/ink dual theme, with the exhale-on-completion motion on successful setup.

**Acceptance criteria.**
- [ ] Settings exposes: change passphrase, regenerate recovery code, enable/disable biometrics, set PIN, lock timeout, sensitive-section scoping, redaction defaults, and security reset.
- [ ] Onboarding security step is reachable, resumable, and cannot be dismissed past the loss warning without an explicit acknowledgement.
- [ ] Recovery code is shown once, confirmed by re-entry, and never persisted in plaintext.
- [ ] All strings are in ARB (en/de/fr/fa/ar/ckb); RTL verified with mirrored layout and localized numerals.
- [ ] Every control meets minimum touch target, has a Semantics label, and status is redundantly encoded (icon + label + shape).
- [ ] Screens honor dynamic type / high-contrast / reduced-motion.

**Size:** M · **Depends on:** F7-T1, F7-T4, F7-T6 · **Governing docs:** [21-settings-preferences.md](../../features/21-settings-preferences.md), [16-permissions-onboarding-oem.md](../../flutter/16-permissions-onboarding-oem.md), [09-security-privacy.md](../../flutter/09-security-privacy.md)

### F7-T8 · Security tests

**Description.** Comprehensive test coverage across the crypto core, unlock flow, storage, scoping, and redaction. Table-driven unit tests on the pure logic (key wrap/unwrap, envelope versioning, PIN throttling math) and integration tests for the platform-touching paths (secure storage round-trip, DB open with key, lock timeout, redaction export).

**Acceptance criteria.**
- [ ] Unit: key wrap → unwrap round-trip returns the identical master key; **wrong passphrase** and tampered envelope both fail with the correct typed `SecurityFailure` (no key returned).
- [ ] Unit: passphrase change re-wraps and still unwraps; recovery-code path unwraps the same key.
- [ ] Unit: PIN throttle/backoff/lockout schedule is exhaustively table-tested, including persistence across restart.
- [ ] Unit: **lock-timeout** logic locks at/after the boundary and stays unlocked within the grace window (deterministic clock).
- [ ] Integration: DB opens only with correct key; on-disk file has no plaintext header (both platforms in CI where feasible).
- [ ] Integration: **redaction** export strips every flagged sensitive field — asserted against the serialized artifact, not the UI.
- [ ] Integration: secure-storage migration and reset paths verified.

**Size:** M · **Depends on:** F7-T1, F7-T3, F7-T4, F7-T5, F7-T6 · **Governing docs:** [09-security-privacy.md](../../flutter/09-security-privacy.md), [18-data-offline-backup.md](../../features/18-data-offline-backup.md)

## Definition of Done

- **Three layers live end-to-end:** DB is AES-256 encrypted from byte 0 on real iOS and Android; master key is random-256-bit, recoverable via passphrase KEK **and** one-time recovery code; daily unlock is biometric/PIN with hardware-keystore backing, lock-on-background, and throttling.
- **No plaintext leaks:** raw master key, PIN, and passphrase are never written to disk or logs; the DB file and any encrypted attachments show no plaintext header/strings; secure-storage items are device-only and excluded from plaintext backup.
- **Recovery is honest:** the un-skippable data-loss warning is shown at setup; recovery-code and passphrase-change flows are verified; the reset path securely wipes all key material.
- **Sensitive-section scoping + redaction** gate medical/ICE and documents behind re-auth, and redaction flags are honored at the export boundary so handover/sell packs carry no sensitive data (proven by test).
- **Tests green:** unit + integration coverage per F7-T8 (wrap/unwrap, wrong-passphrase, throttle, lock-timeout, keyed-DB-open, redaction) passing in CI; crypto core at high coverage.
- **i18n complete:** all security/onboarding/settings strings in ARB for en/de/fr/fa/ar/ckb; no hardcoded user-facing strings.
- **RTL verified:** unlock, onboarding, and settings screens render mirrored in fa/ar/ckb with localized numerals on the PIN pad.
- **In backup/export:** security settings, KDF params, sensitivity/redaction flags, and wrapped-key material are represented per the data model (wrapped key restorable only with the user's secret); redaction applied to exports.
- **Accessible:** lock/unlock/redaction status is **redundantly encoded** (icon + label + shape/position beyond colour) per the PULSE rule; Semantics labels present; error states announced to screen readers; dynamic type, high-contrast, reduced-motion, and minimum touch targets honored.
- **Built-in-first upheld:** no new runtime deps beyond the sanctioned `sqlcipher_flutter_libs`/`sqlite3mc`, `flutter_secure_storage`, `local_auth`, and the native Argon2id binding; all boundaries return sealed `Result`/`Failure`.
