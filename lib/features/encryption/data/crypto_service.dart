import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// AES-256-GCM + X25519 helpers for vault / pairing / sync envelopes.
class CryptoService {
  CryptoService._();

  static final instance = CryptoService._();

  static const envelopeVersion = 1;
  static const algorithmName = 'AES-256-GCM';
  static const _recoveryInfo = 'wodo-recovery-dek-v1';
  static const _pairingInfo = 'wodo-pairing-dek-v1';
  static const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

  final AesGcm _aes = AesGcm.with256bits();
  final X25519 _x25519 = X25519();
  final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  Future<SecretKey> generateDek() => _aes.newSecretKey();

  Future<SimpleKeyPair> generateX25519KeyPair() => _x25519.newKeyPair();

  Future<String> publicKeyBase64(SimpleKeyPair keyPair) async {
    final pub = await keyPair.extractPublicKey();
    return base64Encode(pub.bytes);
  }

  /// 128-bit recovery secret rendered as XXXX-XXXX-XXXX-XXXX-XXXX-XXXX.
  String generateRecoveryCode() {
    final rng = Random.secure();
    final chars = List<String>.generate(24, (_) {
      return _codeAlphabet[rng.nextInt(_codeAlphabet.length)];
    });
    final buf = StringBuffer();
    for (var i = 0; i < chars.length; i++) {
      if (i > 0 && i % 4 == 0) buf.write('-');
      buf.write(chars[i]);
    }
    return buf.toString();
  }

  String normalizeRecoveryCode(String raw) {
    return raw.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  }

  Future<({String salt, String encryptedDekRecovery})> wrapDekForRecovery({
    required SecretKey dek,
    required String recoveryCode,
  }) async {
    final saltBytes = _randomBytes(16);
    final key = await _deriveRecoveryKey(recoveryCode, saltBytes);
    final envelope = await encryptBytes(
      plaintext: Uint8List.fromList(await dek.extractBytes()),
      key: key,
      aad: utf8.encode(_recoveryInfo),
    );
    return (
      salt: base64Encode(saltBytes),
      encryptedDekRecovery: jsonEncode(envelope),
    );
  }

  Future<SecretKey> unwrapDekFromRecovery({
    required String recoveryCode,
    required String saltBase64,
    required String encryptedDekRecovery,
  }) async {
    final saltBytes = base64Decode(saltBase64);
    final key = await _deriveRecoveryKey(recoveryCode, saltBytes);
    final envelope = Map<String, dynamic>.from(
      jsonDecode(encryptedDekRecovery) as Map,
    );
    final dekBytes = await decryptBytes(
      envelope: envelope,
      key: key,
      aad: utf8.encode(_recoveryInfo),
    );
    return SecretKey(dekBytes);
  }

  Future<({String wrappedDek, String approverEphemeralPub})> wrapDekForPairing({
    required SecretKey dek,
    required String newDeviceEphemeralPubBase64,
  }) async {
    final approverPair = await generateX25519KeyPair();
    final remotePub = SimplePublicKey(
      base64Decode(newDeviceEphemeralPubBase64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: approverPair,
      remotePublicKey: remotePub,
    );
    final wrapKey = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(_pairingInfo),
      info: utf8.encode(_pairingInfo),
    );
    final envelope = await encryptBytes(
      plaintext: Uint8List.fromList(await dek.extractBytes()),
      key: wrapKey,
      aad: utf8.encode(_pairingInfo),
    );
    return (
      wrappedDek: jsonEncode(envelope),
      approverEphemeralPub: await publicKeyBase64(approverPair),
    );
  }

  Future<SecretKey> unwrapDekFromPairing({
    required String wrappedDek,
    required String approverEphemeralPubBase64,
    required SimpleKeyPair newDeviceKeyPair,
  }) async {
    final remotePub = SimplePublicKey(
      base64Decode(approverEphemeralPubBase64),
      type: KeyPairType.x25519,
    );
    final shared = await _x25519.sharedSecretKey(
      keyPair: newDeviceKeyPair,
      remotePublicKey: remotePub,
    );
    final wrapKey = await _hkdf.deriveKey(
      secretKey: shared,
      nonce: utf8.encode(_pairingInfo),
      info: utf8.encode(_pairingInfo),
    );
    final envelope = Map<String, dynamic>.from(jsonDecode(wrappedDek) as Map);
    final dekBytes = await decryptBytes(
      envelope: envelope,
      key: wrapKey,
      aad: utf8.encode(_pairingInfo),
    );
    return SecretKey(dekBytes);
  }

  Future<Map<String, dynamic>> encryptPayload({
    required Map<String, dynamic> payload,
    required SecretKey dek,
    required String entityType,
    required String entityId,
  }) async {
    final plaintext = utf8.encode(jsonEncode(payload));
    final aad = utf8.encode('$entityType:$entityId');
    return encryptBytes(plaintext: Uint8List.fromList(plaintext), key: dek, aad: aad);
  }

  Future<Map<String, dynamic>> decryptPayload({
    required Map<String, dynamic> envelope,
    required SecretKey dek,
    required String entityType,
    required String entityId,
  }) async {
    final aad = utf8.encode('$entityType:$entityId');
    final bytes = await decryptBytes(envelope: envelope, key: dek, aad: aad);
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) {
      throw const FormatException('Payload desencriptado inválido.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  bool isOpaqueEnvelope(Map<String, dynamic> payload) {
    return payload['v'] == envelopeVersion &&
        payload['alg'] == algorithmName &&
        payload['nonce'] is String &&
        payload['ciphertext'] is String;
  }

  Future<Map<String, dynamic>> encryptBytes({
    required Uint8List plaintext,
    required SecretKey key,
    List<int>? aad,
  }) async {
    final secretBox = await _aes.encrypt(
      plaintext,
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return {
      'v': envelopeVersion,
      'alg': algorithmName,
      'nonce': base64Encode(secretBox.nonce),
      'ciphertext': base64Encode([
        ...secretBox.cipherText,
        ...secretBox.mac.bytes,
      ]),
      if (aad != null) 'aad': base64Encode(aad),
    };
  }

  Future<Uint8List> decryptBytes({
    required Map<String, dynamic> envelope,
    required SecretKey key,
    List<int>? aad,
  }) async {
    final nonce = base64Decode(envelope['nonce'] as String);
    final packed = base64Decode(envelope['ciphertext'] as String);
    if (packed.length < 16) {
      throw const FormatException('Ciphertext demasiado corto.');
    }
    final cipherText = packed.sublist(0, packed.length - 16);
    final macBytes = packed.sublist(packed.length - 16);
    final clear = await _aes.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
      secretKey: key,
      aad: aad ?? const <int>[],
    );
    return Uint8List.fromList(clear);
  }

  Future<SecretKey> _deriveRecoveryKey(
    String recoveryCode,
    List<int> salt,
  ) async {
    final normalized = normalizeRecoveryCode(recoveryCode);
    final ikm = SecretKey(utf8.encode(normalized));
    return _hkdf.deriveKey(
      secretKey: ikm,
      nonce: salt,
      info: utf8.encode(_recoveryInfo),
    );
  }

  Uint8List _randomBytes(int length) {
    final rng = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(length, (_) => rng.nextInt(256)),
    );
  }
}
