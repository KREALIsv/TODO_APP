import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_service.dart';
import '../../auth/domain/auth_errors.dart';
import '../../sync/data/wodo_api_config.dart';

class SecuritySnapshot {
  const SecuritySnapshot({
    required this.encryptionEnabled,
    required this.encryptionVersion,
    required this.hasRecovery,
    required this.deviceVaultState,
    required this.deviceTrusted,
  });

  final bool encryptionEnabled;
  final int encryptionVersion;
  final bool hasRecovery;
  final String deviceVaultState;
  final bool deviceTrusted;

  factory SecuritySnapshot.fromJson(Map<String, dynamic> json) {
    return SecuritySnapshot(
      encryptionEnabled: json['encryptionEnabled'] == true,
      encryptionVersion: (json['encryptionVersion'] as num?)?.toInt() ?? 1,
      hasRecovery: json['hasRecovery'] == true,
      deviceVaultState: json['deviceVaultState']?.toString() ?? 'none',
      deviceTrusted: json['deviceTrusted'] == true,
    );
  }
}

class RecoveryWrap {
  const RecoveryWrap({
    required this.dekSalt,
    required this.encryptedDekRecovery,
    required this.encryptionVersion,
    this.recoveryHint,
  });

  final String dekSalt;
  final String encryptedDekRecovery;
  final int encryptionVersion;
  final String? recoveryHint;

  factory RecoveryWrap.fromJson(Map<String, dynamic> json) {
    return RecoveryWrap(
      dekSalt: json['dekSalt']?.toString() ?? '',
      encryptedDekRecovery: json['encryptedDekRecovery']?.toString() ?? '',
      encryptionVersion: (json['encryptionVersion'] as num?)?.toInt() ?? 1,
      recoveryHint: json['recoveryHint']?.toString(),
    );
  }
}

class EncryptionApi {
  EncryptionApi._();

  static final instance = EncryptionApi._();

  Future<SecuritySnapshot> fetchSecurity({required String appUserId}) async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.get(
        WodoApiConfig.uri('users/me/security', {'appUserId': appUserId}),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return SecuritySnapshot.fromJson(_data(response));
  }

  Future<void> enable({
    required String appUserId,
    required String dekSalt,
    required String encryptedDekRecovery,
    String? recoveryHint,
  }) async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.post(
        WodoApiConfig.uri('encryption/enable'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'appUserId': appUserId,
          'dekSalt': dekSalt,
          'encryptedDekRecovery': encryptedDekRecovery,
          'encryptionVersion': 1,
          if (recoveryHint != null) 'recoveryHint': recoveryHint,
        }),
      ),
    );
    _data(response);
  }

  Future<RecoveryWrap> fetchRecoveryWrap() async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.get(
        WodoApiConfig.uri('encryption/recovery/wrap'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return RecoveryWrap.fromJson(_data(response));
  }

  Map<String, dynamic> _data(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        AuthErrors.fromHttpFailure(
          statusCode: response.statusCode,
          apiMessage: decoded['message']?.toString(),
        ),
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de seguridad inválida.');
    }
    return data;
  }
}
