import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/encryption/data/crypto_service.dart';

void main() {
  final crypto = CryptoService.instance;

  test('recovery wrap roundtrips DEK', () async {
    final dek = await crypto.generateDek();
    final code = crypto.generateRecoveryCode();
    expect(code.contains('-'), isTrue);

    final wrap = await crypto.wrapDekForRecovery(
      dek: dek,
      recoveryCode: code,
    );
    final restored = await crypto.unwrapDekFromRecovery(
      recoveryCode: code.replaceAll('-', '').toLowerCase(),
      saltBase64: wrap.salt,
      encryptedDekRecovery: wrap.encryptedDekRecovery,
    );

    expect(await restored.extractBytes(), await dek.extractBytes());
  });

  test('pairing ECDH wrap roundtrips DEK', () async {
    final dek = await crypto.generateDek();
    final newDevice = await crypto.generateX25519KeyPair();
    final newPub = await crypto.publicKeyBase64(newDevice);

    final wrap = await crypto.wrapDekForPairing(
      dek: dek,
      newDeviceEphemeralPubBase64: newPub,
    );
    final restored = await crypto.unwrapDekFromPairing(
      wrappedDek: wrap.wrappedDek,
      approverEphemeralPubBase64: wrap.approverEphemeralPub,
      newDeviceKeyPair: newDevice,
    );

    expect(await restored.extractBytes(), await dek.extractBytes());
  });

  test('sync payload envelope encrypt/decrypt', () async {
    final dek = await crypto.generateDek();
    final payload = {
      'id': 'n1',
      'title': 'Privado',
      'body': 'contenido sensible',
      'tags': ['salud'],
    };
    final envelope = await crypto.encryptPayload(
      payload: payload,
      dek: dek,
      entityType: 'note',
      entityId: 'n1',
    );
    expect(crypto.isOpaqueEnvelope(envelope), isTrue);
    expect(envelope.containsKey('title'), isFalse);

    final clear = await crypto.decryptPayload(
      envelope: envelope,
      dek: dek,
      entityType: 'note',
      entityId: 'n1',
    );
    expect(clear['title'], 'Privado');
    expect(clear['body'], 'contenido sensible');
  });
}
