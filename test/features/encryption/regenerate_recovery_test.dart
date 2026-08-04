import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/encryption/data/crypto_service.dart';

void main() {
  test('regenerate uses same DEK with new recovery wrap', () async {
    final crypto = CryptoService.instance;
    final dek = await crypto.generateDek();
    final firstCode = crypto.generateRecoveryCode();
    final secondCode = crypto.generateRecoveryCode();

    final firstWrap = await crypto.wrapDekForRecovery(
      dek: dek,
      recoveryCode: firstCode,
    );
    final secondWrap = await crypto.wrapDekForRecovery(
      dek: dek,
      recoveryCode: secondCode,
    );

    expect(firstWrap.salt, isNot(equals(secondWrap.salt)));
    expect(
      firstWrap.encryptedDekRecovery,
      isNot(equals(secondWrap.encryptedDekRecovery)),
    );

    final fromFirst = await crypto.unwrapDekFromRecovery(
      recoveryCode: firstCode,
      saltBase64: firstWrap.salt,
      encryptedDekRecovery: firstWrap.encryptedDekRecovery,
    );
    final fromSecond = await crypto.unwrapDekFromRecovery(
      recoveryCode: secondCode,
      saltBase64: secondWrap.salt,
      encryptedDekRecovery: secondWrap.encryptedDekRecovery,
    );

    expect(await fromFirst.extractBytes(), await fromSecond.extractBytes());
  });
}
