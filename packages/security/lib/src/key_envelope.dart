import 'dart:convert';

/// Argon2id KEK parameters (F7-T2). [memory] is in KiB. The [floor] is a
/// security minimum a weak device may not calibrate below (OWASP-ish); [fast]
/// is for tests only — never persisted for a real key.
final class Argon2idParams {
  const Argon2idParams({
    required this.memory,
    required this.iterations,
    required this.parallelism,
  });

  final int memory;
  final int iterations;
  final int parallelism;

  /// Enforced minimum for a real key.
  static const floor =
      Argon2idParams(memory: 19456, iterations: 2, parallelism: 1);

  /// Fast params for host tests (NOT for production key material).
  static const fast =
      Argon2idParams(memory: 256, iterations: 1, parallelism: 1);

  /// Raise each param to at least the [floor] — a device can calibrate *up*,
  /// never below the security minimum.
  Argon2idParams atLeastFloor() => Argon2idParams(
        memory: memory < floor.memory ? floor.memory : memory,
        iterations:
            iterations < floor.iterations ? floor.iterations : iterations,
        parallelism:
            parallelism < floor.parallelism ? floor.parallelism : parallelism,
      );
}

/// The persisted wrapped-key envelope (F7-T1). It holds everything needed to
/// re-derive the KEK and unwrap the master key — ciphertext, auth tag (MAC),
/// KDF id + params, salt, nonce, and a scheme [version] for migration — but
/// **never** the raw master key.
final class KeyEnvelope {
  const KeyEnvelope({
    required this.version,
    required this.kdf,
    required this.params,
    required this.salt,
    required this.nonce,
    required this.ciphertext,
    required this.mac,
  });

  /// Current scheme version.
  static const int currentVersion = 1;

  final int version;

  /// KDF identifier — always `argon2id` in v1.
  final String kdf;
  final Argon2idParams params;
  final List<int> salt;
  final List<int> nonce;
  final List<int> ciphertext;
  final List<int> mac;

  Map<String, dynamic> toJson() => {
        'v': version,
        'kdf': kdf,
        'm': params.memory,
        't': params.iterations,
        'p': params.parallelism,
        'salt': base64.encode(salt),
        'nonce': base64.encode(nonce),
        'ct': base64.encode(ciphertext),
        'mac': base64.encode(mac),
      };

  /// Parse from JSON; returns null if the shape is malformed (caller maps that
  /// to a typed EnvelopeCorrupt failure).
  static KeyEnvelope? tryFromJson(Map<String, dynamic> json) {
    try {
      return KeyEnvelope(
        version: json['v'] as int,
        kdf: json['kdf'] as String,
        params: Argon2idParams(
          memory: json['m'] as int,
          iterations: json['t'] as int,
          parallelism: json['p'] as int,
        ),
        salt: base64.decode(json['salt'] as String),
        nonce: base64.decode(json['nonce'] as String),
        ciphertext: base64.decode(json['ct'] as String),
        mac: base64.decode(json['mac'] as String),
      );
    } on Object {
      return null;
    }
  }
}
