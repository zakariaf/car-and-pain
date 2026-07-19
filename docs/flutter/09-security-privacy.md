# 🔐 Security, Privacy & At-Rest Encryption

> This document governs how Car and Pain protects the user's irreplaceable, unusually sensitive data at rest, gates access, moves data off-device safely, and enforces the no-telemetry promise — without ever trading away recoverability.

📍 Part of the **[Flutter Engineering Guide](./README.md)** · See also **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** · **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** · **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)**

---

## Decision

Car and Pain uses a **three-layer, encrypt-everything, key-wrapping** architecture, because the app holds unusually sensitive PII for a "car app" (VIN, plate, driver's licence, IBAN, insurance/claim numbers, home address, GPS trip polylines, dashcam clips):

1. **Layer 1 — Mandatory whole-DB AES-256 at rest**, not a toggle. Encrypt the entire SQLite file. Default to the proven `sqlcipher_flutter_libs` (SQLCipher, raw 64-hex `PRAGMA key`); the drift `sqlite3mc` build-hook path is the target only if a blocking week-one spike proves it links and encrypts on real iOS **and** Android. Cipher/KDF selection is **explicit and asserted**, and a blocking CI test reads the raw DB header and asserts it is **not** `SQLite format 3`.
2. **Layer 2 — A random 256-bit master key that is RECOVERABLE BY DEFAULT.** The key is wrapped with a user-passphrase-derived KEK (FFI/native **Argon2id**, device-calibrated params) and/or backed by a one-time recovery code. `flutter_secure_storage` (v10.x) is the fast path — iOS `accessibleAfterFirstUnlockThisDeviceOnly`, Android hardware Keystore with `allowBackup=false`. "Key only in secure storage" is the **risky mode**, never the default.
3. **Layer 3 — App-lock as a separate gate** via `local_auth` (biometric + device-credential fallback) **plus** an app-defined PIN escape path. Android hosts `local_auth` in a `FragmentActivity`. The lock is only cryptographically real when tied to the passphrase/Argon2id KEK wrap.

Plus: per-file **AES-GCM** attachments, passphrase-encrypted backups, allow-list redacted handover export, secure wipe by **key destruction**, selective screenshot/app-switcher protection, and CI-enforced no-telemetry (lockfile scan + omitted `INTERNET` permission + `PrivacyInfo.xcprivacy`).

## Why

The two hard durability lessons drive the whole design:

- **Encryption is worthless if the key is lost.** Keystore/Keychain loss after an OEM OS update, biometric re-enrollment, or a device restore is *well-documented on exactly our target devices*. With no cloud and no account, "key only in secure storage" is an **existential single point of failure**. So recoverability is the default, not an opt-in high-security mode. The encrypted DB is *not* the backup either — see **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)**.
- **`local_auth` protects nothing on its own.** This is the single most common Flutter security mistake: a biometric prompt with the DB key sitting readable in the Keystore protects nothing against a rooted/jailbroken device dump. The passphrase/Argon2id KEK wrap is what makes the lock cryptographically meaningful.

**Alternatives considered and rejected:**

- **Field-level column encryption only** — leaks schema, row counts, timestamps, indexes, and "which vehicle has an insurance claim"; breaks SQL search/sort/analytics; easy to forget a column. The whole app is sensitive, so the blast radius is the whole DB anyway. Full-DB encryption is *simpler and stronger*.
- **`sqflite_sqlcipher` / `encrypted_drift`** — raw SQL, weak fit for the typed, migration-heavy, multi-isolate schema; drift docs flag this route as deprecated.
- **Pure-Dart Argon2id** — too slow / OOM on low-end target devices (multi-second unlocks or crashes). Use an FFI/native implementation with device-calibrated params.
- **Biometric-only lock (no PIN)** — locks users out permanently when no biometric is enrolled, hardware fails, or after biometric lockout, with no account-recovery path.
- **Passphrase to SQLCipher instead of a raw hex key** — runs PBKDF2 (256k iterations ≈ 512k SHA-512 ops) on *every* cold start, notification wake, and reboot re-arm. A raw `x'...'` key already has 256-bit entropy and skips the KDF.
- **Obfuscation as a secret store** — IP/reverse-engineering friction only, explicitly not encryption; enum names and string literals survive it.

## How we do it

### Package list

```yaml
dependencies:
  # Layer 1 — encrypted DB (default path). See 03-data-persistence.md for drift wiring.
  drift: <pin-at-kickoff>
  sqlite3: <pin-at-kickoff>
  sqlite3_flutter_libs: <pin-at-kickoff>
  sqlcipher_flutter_libs: <pin-at-kickoff>   # DEFAULT cipher backend
  # sqlite3mc build-hook is adopted ONLY if the week-one spike passes on real iOS + Android

  # Layer 2 — key storage + KDF
  flutter_secure_storage: ^10.0.0            # v10 default: hardware Keystore RSA-OAEP + AES-GCM
  cryptography: <pin>                         # AES-GCM + Argon2id
  cryptography_flutter: <pin>                 # platform-accelerated primitives (FFI/native Argon2id)
  crypto: <pin>                              # hashing
  convert: <pin>                             # hex encoding for the raw key

  # Layer 3 — app-lock + leakage protection
  local_auth: ^3.0.0
  screen_protector: ^1.5.0                    # selective FLAG_SECURE / switcher overlay
```

Everything crypto-related lives in the **`data`** package (see the [structure](./01-architecture-and-structure.md)); feature folders never touch key material directly.

### Layer 1 — open the encrypted DB with a raw key (assert the cipher)

`flutter_secure_storage` needs the platform channel, so the key is read **on the main isolate** and passed *into* the drift background isolate — never read from inside the isolate.

```dart
// bootstrap.dart (main isolate): read + unwrap the recoverable key, then open the DB.
final String hexKey = await keyManager.loadOrRecoverMasterKeyHex();

final db = NativeDatabase.createInBackground(
  dbFile,
  setup: (raw) {
    // PRAGMA key MUST be the first statement, before any query.
    raw.execute('PRAGMA key = "x\'$hexKey\'";');
    raw.execute('PRAGMA cipher_page_size = 4096;');
    // Fork-vs-stock mismatch silently opens an UNENCRYPTED db — fail loud instead.
    final cipher = raw.select('PRAGMA cipher;');
    if (cipher.isEmpty) {
      throw StateError('Encryption cipher not active — refusing to open db.');
    }
    // Probe forces early failure on a wrong key instead of a corrupt read later.
    raw.select('SELECT count(*) FROM sqlite_master;');
  },
);
```

### Layer 2 — recoverable key: bootstrap and KEK-wrap

```dart
// First launch: generate a random 256-bit master key.
final Uint8List master = SecureRandom().nextBytes(32);

// Fast path: store the raw key in secure storage (recoverable mode still active via passphrase wrap).
await secureStorage.write(
  key: 'db_master_key',
  value: hex.encode(master),
  iOptions: const IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device, // AfterFirstUnlockThisDeviceOnly
  ),
  aOptions: const AndroidOptions(), // v10 default: hardware Keystore RSA-OAEP + AES-GCM
);

// Recoverable-by-default: ALSO wrap the master key with a user passphrase KEK.
final salt = SecureRandom().nextBytes(16);
final kek = await argon2id.deriveKey(
  passphrase,
  salt: salt,
  memory: calibratedMemoryKiB, // device-calibrated, e.g. >= 64 MiB with low-end fallback
  iterations: calibratedIterations, // tuned to ~0.5–1s on the slowest target device
);
final wrapped = await AesGcm.with256bits().encrypt(master, secretKey: kek); // fresh random nonce
await recoveryStore.saveWrappedKey(wrapped, salt); // survives Keystore loss
```

Changing the passphrase **re-wraps the same master key** — no DB rekey. A full "change encryption" does `PRAGMA rekey`. On restore or after Keystore loss, re-derive the KEK from the passphrase (or the one-time recovery code) and unwrap.

### Layer 3 — the app-lock gate

```dart
// A root gate above the router. See 05-navigation.md for shell wiring.
class AppLockGate extends ConsumerWidget {
  Future<void> _unlock() async {
    try {
      final ok = await LocalAuthentication().authenticate(
        localizedReason: l10n.unlockReason,
        options: const AuthenticationOptions(
          biometricOnly: false,   // allow device passcode fallback
          stickyAuth: true,       // survive backgrounding mid-prompt
          useErrorDialogs: true,
        ),
      );
      if (!ok) return _routeToPinScreen();
    } on PlatformException catch (e) {
      // notAvailable / notEnrolled / lockedOut / permanentlyLockedOut / passcodeNotSet
      _routeToPinScreen(); // the PIN is the escape hatch — never a dead end
    }
  }
}
```

- Require unlock on **cold start** and after a configurable **idle/background timeout**.
- On `AppLifecycleState.inactive`/`paused`, paint an **opaque cover** so the OS task-switcher snapshot is blank.
- Android: host `local_auth` in a **`FragmentActivity`** (not `FlutterActivity`), declare `USE_BIOMETRIC`. iOS: `NSFaceIDUsageDescription`.

### Attachments, backups, redaction, wipe

```dart
// Per-file attachment encryption (receipts, PDFs, dashcam) OUTSIDE the db:
//   <uuid>.enc = nonce(prepended) || AES-GCM(fileKey, plaintext) || tag(appended)
// Store only content-hash + nonce in the (already encrypted) db. Stream large clips in chunks.

// Encrypted backup container (leaves the device boundary → passphrase-encrypted):
//   header(magic, schemaVersion, kdf=argon2id, salt, nonce)
//     || AES-GCM(passphraseKey, zip(json + csv + attachment blobs)) || checksum
```

- **Redacted handover export** (Sell/Dispose module): an **allow-list** of fields per module — INCLUDES service history + odometer ledger + tire life (value to a buyer), STRIPS identity, home address, GPS polylines, financials, insurance/claim/licence data. Allow-list so a new field **defaults to redacted**.
- **Secure wipe ("panic delete")**: close DB → delete DB + WAL/SHM → delete all `.enc` attachments → `secureStorage.deleteAll()` + destroy the wrapped-key/recovery material. Destroying the key is the real erasure (flash wear-leveling means file deletion alone does not guarantee physical erasure; full-DB encryption is what makes deletion trustworthy).

### No-telemetry enforcement

```yaml
# .github/workflows/ci.yaml — lockfile scan lane (offline flavor)
- name: No-telemetry lockfile scan
  run: |
    if grep -Eiq 'firebase_analytics|sentry|crashlytics|amplitude|mixpanel|posthog' pubspec.lock; then
      echo "Forbidden telemetry SDK found in lockfile"; exit 1
    fi
```

```xml
<!-- android/app/src/offline/AndroidManifest.xml -->
<!-- NO <uses-permission android:name="android.permission.INTERNET"/> on the offline flavor:
     the OS enforces the no-network claim, it is not merely promised. -->
<application android:allowBackup="false" android:usesCleartextTraffic="false" ... />
```

Ship `ios/Runner/PrivacyInfo.xcprivacy` declaring **no tracking** and any required-reason APIs, and keep the Play Data-Safety form declaring no collection — see **[Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md)**.

## Rules

**Do:**

- **Assert `PRAGMA cipher` is non-empty on every DB open**, and set `PRAGMA key` as the *first* statement before any query.
- Keep a **blocking CI test** that reads the raw DB file header and asserts it is **not** `SQLite format 3\000`.
- Use a **raw 64-hex-char key** (`x'...'`), never a human passphrase, to SQLCipher.
- Store the master key with iOS `accessibleAfterFirstUnlockThisDeviceOnly` and Android hardware Keystore; set **`allowBackup=false`** and exclude secure storage/DB from any `fullBackupContent` rules.
- Make the master key **recoverable by default** (passphrase-wrapped KEK and/or one-time recovery code) at first run.
- Read `flutter_secure_storage` only on the **main isolate**; pass key bytes into background isolates.
- Always provide a **PIN escape path** alongside biometrics; route every `local_auth` error code to it.
- Encrypt **attachments and any exported/backup file** explicitly (per-file AES-GCM; passphrase-encrypted backups).
- Use a **fresh random nonce** per AES-GCM encryption; never reuse a `(key, nonce)` pair.
- Hold keys in `Uint8List`, overwrite after use, keep lifetime short.
- Warn **un-skippably** at backup/export time that a lost passphrase = unrecoverable backup.

**Don't:**

- Don't treat `local_auth` as data protection.
- Don't link plain `sqlite3_flutter_libs` in a way that can win the native link and silently open an unencrypted DB.
- Don't hold the key in a Dart `String` (can't be zeroed; lingers in heap dumps).
- Don't rely on `--obfuscate` to hide any secret or key.
- Don't apply `FLAG_SECURE` globally — scope it to genuinely sensitive screens.
- Don't share the device-local master key between phones for P2P household sync — use per-pairing ephemeral key exchange (QR + short-authentication-string); the at-rest key stays device-local.

## For Car and Pain specifically

- **Offline-first / no-telemetry:** there is no server to re-sync from and no telemetry to tell us something broke, so recoverability and a verified local backup — not the encryption itself — are the durability guarantee. The offline flavor **omits `INTERNET`** so the no-network claim is OS-enforced. Purchases validate locally via StoreKit/Play Billing receipts (no license phone-home).
- **Notifications / reboot survival:** the reboot receiver may run while the device is still locked after a reboot, so `accessibleAfterFirstUnlockThisDeviceOnly` is a **hard requirement**, not a preference — the receiver must read the DB key to re-arm reminders from the DB. See **[Local Notifications & Background Reliability](./07-notifications.md)** and **[Reminders & Notifications (product)](../features/04-reminders-notifications.md)**.
- **Canonical storage:** because everything is stored canonically (SI units, minor-unit money, UTC/wall-clock) and the whole DB is encrypted, switching language/calendar/units/numerals **never touches the crypto layer**. See the [Canonical Data Model](../reference/data-model.md).
- **RTL / i18n:** RTL, Jalali/Hijri, and Eastern-Arabic/Persian numerals are pure presentation and have no security impact — **but** the PIN entry pad and biometric prompts must be mirrored/localized, and **PINs must be stored as normalized ASCII digits**, never locale-specific numerals. See **[Internationalization, RTL, Calendars & Numerals](./06-i18n-rtl-calendars.md)**.
- **Sensitive-screen mapping:** glovebox, compliance, insurance/claims, and safety/incidents modules get `screen_protector` selectively; the Sell/Dispose module gets the allow-list handover profile.

## Testing

See the full strategy in **[Testing Strategy](./11-testing.md)**. Security-specific suites:

- **Prove encryption is real (blocking):** after writing rows, open the raw file with stock tooling (`sqlite3 file .schema` / `hexdump -C`) — it must fail; assert the first 16 bytes are **not** `SQLite format 3\000` and that `PRAGMA cipher` is non-empty at open.
- **Key lifecycle:** master-key persistence across hot restart, cold start, OS reboot, and app **update** (Keychain/Keystore survive); and the fresh-install edge case (stale iOS Keychain key with no DB → detect and reconcile).
- **Key recovery:** destroy the Keystore/Keychain key, then prove the **passphrase / recovery-code** path restores access.
- **App-lock matrix:** biometric success; biometric fail → PIN; not enrolled → PIN; `lockedOut`/`permanentlyLockedOut` → PIN; `passcodeNotSet`. Drive `local_auth` via `adb emu finger touch` (Android) and Simulator Enrolled/Matching Face ID; use **Patrol** for the native surfaces.
- **High-security KEK-wrap:** wrong PIN/passphrase cannot decrypt the wrapped key; correct one does; changing PIN re-wraps **without** a DB rekey; "change encryption" performs `PRAGMA rekey`.
- **Attachments:** AES-GCM round-trip; a flipped ciphertext byte **fails the GCM tag** (tamper detection); confirm no plaintext `.jpg`/`.pdf` is written to disk.
- **Backups:** encrypt→decrypt with correct passphrase; rejection on wrong passphrase; schema-version/checksum validation before restore.
- **Redaction (golden):** the handover export CONTAINS service/odometer/tire data and OMITS identity/GPS/financial/insurance/licence fields; add a new field and assert it defaults to redacted.
- **Secure wipe:** after wipe, the DB won't open, attachments are gone, and `secureStorage.readAll()` is empty.
- **No-telemetry (negative):** CI lockfile scan fails on forbidden SDKs; an instrumented test asserts **zero outbound connections** on the offline flavor; verify the manifest lacks `INTERNET`, has `allowBackup=false` + `usesCleartextTraffic=false`, and that `PrivacyInfo.xcprivacy` exists.
- **Obfuscation:** build a release with `--obfuscate --split-debug-info`, force a crash, confirm `flutter symbolize` reconstructs the trace; run `strings` on the release lib to confirm no key/secret material is embedded.
- **Device coverage (manual):** OEM Androids with Keystore quirks (Xiaomi/MIUI, Huawei, Samsung) and a range of iOS devices for Keychain accessibility + Face ID behavior.

## Pitfalls

- **`local_auth` protects nothing on its own** — a rooted device that dumps the Keystore bypasses the prompt entirely. Only the Argon2id-KEK wrap makes the lock cryptographically real.
- **iOS default `WhenUnlocked` breaks background reboot re-arm** — the rescheduling code runs while the phone is still locked and cannot read the key. Use `AfterFirstUnlockThisDeviceOnly`.
- **iOS Keychain items persist across uninstall/reinstall** — a reinstall can find a stale key but no DB (or a restored DB with no key) → decrypt fails. Detect first-run-after-install and reconcile.
- **Silent unencrypted open** — mixing plain `sqlite3_flutter_libs` with the cipher (or a dependency winning the native link) yields a readable DB with no error. Assert `PRAGMA cipher` + verify the file header in CI.
- **PBKDF2 tax** — a human passphrase to SQLCipher runs 256k iterations on every open (cold start, notification wake, reboot re-arm). Use the raw `x'...'` key.
- **`allowBackup=true`** — can trigger `InvalidKeyException` on restore and exfiltrate secure data via `adb backup`. Set it `false`.
- **secure_storage from a background isolate** — needs the main-isolate platform channel; read on main, pass bytes in.
- **Attachments/exports live outside the DB** — encrypting the DB but leaving receipts/dashcam/backups plaintext defeats the whole model.
- **GCM nonce reuse is catastrophic** — fresh random nonce per encryption, always.
- **Keys in Dart strings** can't be zeroed and linger in heap dumps — use `Uint8List`.
- **Pure-Dart Argon2id** is too slow/OOM on low-end devices — use the FFI/native path with a defined low-end fallback.
- **Biometric lockout with no PIN** locks users out of their own offline data with no recovery path.
- **Global `FLAG_SECURE`** stops users screenshotting their own fuel charts — scope it.
- **Missing `PrivacyInfo.xcprivacy`** causes App Store rejection even for a zero-tracking app — don't let the no-telemetry stance produce a missing manifest.
- **Obfuscation misconceptions** — release-only, encrypts nothing, leaves enum names/string literals visible, and breaks `runtimeType.toString()`-based logic.

## Decisions to confirm

- **Default recovery mechanism & first-run flow:** user-passphrase KEK vs auto-issued one-time recovery code vs **both**, and the exact first-run UX — this is now the app's primary durability guarantee, not an opt-in high-security mode.
- **Argon2id parameters:** settle the FFI/native library and device-calibrated memory/iteration params (with a low-end fallback), benchmarked against the slowest target device so unlock/backup does not take multiple seconds or OOM.
- **Encryption-toolchain spike:** does drift's `sqlite3mc` build-hook link and encrypt on real iOS **and** Android, or does v1 ship on `sqlcipher_flutter_libs`? Confirm no dependency pulls a plaintext `sqlite3` library that wins the native link. Pin verified current-stable SDK/package majors at that time.
- **Household P2P sync in/out of MVP:** if in-scope, the per-pairing ephemeral key-exchange design (device-local master key never shared) must be specified, and the merge/tombstone/backup/notification-reconcile work adjusted accordingly.

## Related

- **[Local Database, Schema, Indexing & Migrations](./03-data-persistence.md)** — the encrypted Drift wiring, cipher assertion, and forward-only migrations this layer sits on.
- **[Backup, Export & Disaster Recovery](./13-backup-export-recovery.md)** — passphrase-encrypted backups, `VACUUM INTO`, verify-by-reopen, and the recovery-code flow.
- **[Local Notifications & Background Reliability](./07-notifications.md)** — why `AfterFirstUnlockThisDeviceOnly` is a hard requirement for reboot re-arm.
- **[Permissions, Onboarding & OEM Survival](./16-permissions-onboarding-oem.md)** — the guided app-lock and OEM-battery setup flow.
- **[Store Compliance, Privacy Declarations & Licensing](./17-store-compliance-licensing.md)** — `PrivacyInfo.xcprivacy`, Play Data-Safety, and how the no-telemetry posture is declared.
- **[Data, Offline, Backup & Portability (product)](../features/18-data-offline-backup.md)** — the product-side promise this architecture backs.
