import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/encryption/data/vault_service.dart';
import 'package:todos_app/features/settings/domain/privacy_security_status.dart';

void main() {
  tearDown(() {
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: false,
      clearDek: true,
    );
  });

  test('logged out is Local', () {
    final status = PrivacySecurityStatus.resolve(authenticated: false);
    expect(status.phase, PrivacySecurityPhase.local);
    expect(status.title, 'Local');
    expect(status.hubTrailing, 'Local');
    expect(status.hubSubtitle, PrivacySecurityCopy.sectionCaption);
  });

  test('signed in without E2EE is Sync sin protección', () {
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: false,
      clearDek: true,
    );
    final status = PrivacySecurityStatus.resolve(authenticated: true);
    expect(status.phase, PrivacySecurityPhase.syncUnprotected);
    expect(status.title, 'Sync sin protección');
    expect(status.hubTrailing, 'Opcional');
  });

  test('E2EE without DEK is Pendiente de vincular', () {
    VaultService.instance.debugOverrideCloudState(
      accountEncryptionEnabled: true,
      deviceVaultState: 'none',
      clearDek: true,
    );
    final status = PrivacySecurityStatus.resolve(authenticated: true);
    expect(status.phase, PrivacySecurityPhase.pendingLink);
    expect(status.title, 'Pendiente de vincular');
    expect(status.hubTrailing, 'Pendiente');
  });

  test('vault ready is Protegido', () {
    VaultService.instance.debugOverrideCloudState(markVaultReady: true);
    final status = PrivacySecurityStatus.resolve(authenticated: true);
    expect(status.phase, PrivacySecurityPhase.protected);
    expect(status.title, 'Protegido');
    expect(status.hubTrailing, 'Activa');
  });
}
