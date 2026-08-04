import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../auth/data/auth_service.dart';
import '../../sync/data/device_identity.dart';
import '../domain/cloud_vault_state.dart';
import 'crypto_service.dart';
import 'encryption_api.dart';

/// Local DEK vault + remote encryption security state.
class VaultService extends ChangeNotifier {
  VaultService._();

  static final instance = VaultService._();

  static const _dekKey = 'wodo.vault.dek.v1';
  static const _enabledKey = 'wodo.vault.encryption_enabled.v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final CryptoService _crypto = CryptoService.instance;
  final EncryptionApi _api = EncryptionApi.instance;

  SecretKey? _dek;
  bool _accountEncryptionEnabled = false;
  String _deviceVaultState = 'none';
  bool _loaded = false;

  bool get isLoaded => _loaded;
  bool get hasDek => _dek != null;
  bool get accountEncryptionEnabled => _accountEncryptionEnabled;
  SecretKey? get dek => _dek;

  CloudVaultState get state {
    if (!_accountEncryptionEnabled) return CloudVaultState.encryptionOff;
    if (_deviceVaultState == 'revoked') return CloudVaultState.revoked;
    if (_dek == null) return CloudVaultState.authOnly;
    return CloudVaultState.vaultReady;
  }

  bool get canSyncEncrypted => state == CloudVaultState.vaultReady;
  bool get blocksEncryptedSync =>
      _accountEncryptionEnabled && state != CloudVaultState.vaultReady;

  Future<void> init() async {
    AuthService.instance.addListener(_onAuthChanged);
    await _restoreLocalDek();
    if (AuthService.instance.isAuthenticated) {
      await refreshSecurity();
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> refreshSecurity() async {
    if (!AuthService.instance.isAuthenticated) {
      _accountEncryptionEnabled = false;
      _deviceVaultState = 'none';
      notifyListeners();
      return;
    }
    try {
      final security = await _api.fetchSecurity(
        appUserId: DeviceIdentity.instance.appUserId,
      );
      _accountEncryptionEnabled = security.encryptionEnabled;
      _deviceVaultState = security.deviceVaultState;
      await _storage.write(
        key: _enabledKey,
        value: _accountEncryptionEnabled ? '1' : '0',
      );
      notifyListeners();
    } catch (_) {
      // Keep last known local flags.
    }
  }

  /// Enables cloud protection: generates DEK + recovery code, uploads wrap.
  Future<String> enableProtection() async {
    final dek = await _crypto.generateDek();
    final recoveryCode = _crypto.generateRecoveryCode();
    final wrap = await _crypto.wrapDekForRecovery(
      dek: dek,
      recoveryCode: recoveryCode,
    );
    await _api.enable(
      appUserId: DeviceIdentity.instance.appUserId,
      dekSalt: wrap.salt,
      encryptedDekRecovery: wrap.encryptedDekRecovery,
    );
    await _persistDek(dek);
    _accountEncryptionEnabled = true;
    _deviceVaultState = 'trusted';
    notifyListeners();
    return recoveryCode;
  }

  /// Re-wraps the local DEK with a new recovery code and uploads it.
  /// Only callable when this device already has the DEK (vaultReady).
  Future<String> regenerateRecoveryCode() async {
    final dek = _dek;
    if (dek == null) {
      throw StateError(
        'Este dispositivo no tiene acceso a tus datos protegidos.',
      );
    }
    if (!_accountEncryptionEnabled) {
      throw StateError('La protección no está activada.');
    }

    final recoveryCode = _crypto.generateRecoveryCode();
    final wrap = await _crypto.wrapDekForRecovery(
      dek: dek,
      recoveryCode: recoveryCode,
    );
    await _api.regenerateRecoveryWrap(
      appUserId: DeviceIdentity.instance.appUserId,
      dekSalt: wrap.salt,
      encryptedDekRecovery: wrap.encryptedDekRecovery,
    );
    return recoveryCode;
  }

  Future<void> unlockWithRecoveryCode(String recoveryCode) async {
    final wrap = await _api.fetchRecoveryWrap();
    final dek = await _crypto.unwrapDekFromRecovery(
      recoveryCode: recoveryCode,
      saltBase64: wrap.dekSalt,
      encryptedDekRecovery: wrap.encryptedDekRecovery,
    );
    await _persistDek(dek);
    _accountEncryptionEnabled = true;
    _deviceVaultState = 'trusted';
    notifyListeners();
  }

  Future<void> storeDekFromPairing(SecretKey dek) async {
    await _persistDek(dek);
    _accountEncryptionEnabled = true;
    _deviceVaultState = 'trusted';
    notifyListeners();
  }

  Future<void> clearLocalDek() async {
    _dek = null;
    await _storage.delete(key: _dekKey);
    notifyListeners();
  }

  Future<Map<String, dynamic>?> encryptSyncPayload({
    required Map<String, dynamic> payload,
    required String entityType,
    required String entityId,
  }) async {
    final key = _dek;
    if (key == null) return null;
    return _crypto.encryptPayload(
      payload: payload,
      dek: key,
      entityType: entityType,
      entityId: entityId,
    );
  }

  Future<Map<String, dynamic>?> decryptSyncPayload({
    required Map<String, dynamic> payload,
    required String entityType,
    required String entityId,
  }) async {
    final key = _dek;
    if (key == null) return null;
    if (!_crypto.isOpaqueEnvelope(payload)) return payload;
    return _crypto.decryptPayload(
      envelope: payload,
      dek: key,
      entityType: entityType,
      entityId: entityId,
    );
  }

  Future<({String wrappedDek, String approverEphemeralPub})?>
      wrapDekForPairing(String newDeviceEphemeralPub) async {
    final key = _dek;
    if (key == null) return null;
    return _crypto.wrapDekForPairing(
      dek: key,
      newDeviceEphemeralPubBase64: newDeviceEphemeralPub,
    );
  }

  Future<void> _persistDek(SecretKey dek) async {
    _dek = dek;
    final bytes = await dek.extractBytes();
    await _storage.write(key: _dekKey, value: base64Encode(bytes));
  }

  Future<void> _restoreLocalDek() async {
    final raw = await _storage.read(key: _dekKey);
    if (raw == null || raw.isEmpty) {
      _dek = null;
      return;
    }
    try {
      _dek = SecretKey(base64Decode(raw));
    } catch (_) {
      _dek = null;
    }
    final enabled = await _storage.read(key: _enabledKey);
    _accountEncryptionEnabled = enabled == '1';
  }

  Future<void> _onAuthChanged() async {
    if (!AuthService.instance.isAuthenticated) {
      // Keep DEK across short session blips on web? TRD Opción B: clear on logout.
      await clearLocalDek();
      _accountEncryptionEnabled = false;
      _deviceVaultState = 'none';
      notifyListeners();
      return;
    }
    await refreshSecurity();
  }

  /// Overrides cloud vault flags for widget/golden tests only.
  @visibleForTesting
  void debugOverrideCloudState({
    bool? accountEncryptionEnabled,
    String? deviceVaultState,
    bool clearDek = false,
    bool markVaultReady = false,
  }) {
    if (accountEncryptionEnabled != null) {
      _accountEncryptionEnabled = accountEncryptionEnabled;
    }
    if (deviceVaultState != null) {
      _deviceVaultState = deviceVaultState;
    }
    if (clearDek) {
      _dek = null;
    }
    if (markVaultReady) {
      _dek = SecretKey(List<int>.filled(32, 1));
      _accountEncryptionEnabled = true;
      _deviceVaultState = 'trusted';
    }
    _loaded = true;
    notifyListeners();
  }
}
