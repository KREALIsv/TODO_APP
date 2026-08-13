import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_service.dart';
import '../../auth/domain/auth_errors.dart';
import '../../encryption/data/crypto_service.dart';
import '../../encryption/data/vault_service.dart';
import '../../sync/data/device_identity.dart';
import '../../sync/data/wodo_api_config.dart';

class PairingStart {
  const PairingStart({
    required this.pairingId,
    required this.displayCode,
    required this.pollToken,
    required this.expiresAt,
    required this.qrPayload,
  });

  final String pairingId;
  final String displayCode;
  final String pollToken;
  final DateTime expiresAt;
  final Map<String, dynamic> qrPayload;

  String get qrData => jsonEncode(qrPayload);

  factory PairingStart.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expiresAt'];
    final qr = json['qrPayload'];
    if (json['pairingId'] is! String ||
        json['displayCode'] is! String ||
        json['pollToken'] is! String ||
        expiresRaw is! String ||
        qr is! Map<String, dynamic>) {
      throw const FormatException('Respuesta de vinculación inválida.');
    }
    return PairingStart(
      pairingId: json['pairingId'] as String,
      displayCode: json['displayCode'] as String,
      pollToken: json['pollToken'] as String,
      expiresAt: DateTime.parse(expiresRaw),
      qrPayload: qr,
    );
  }
}

class PairingPending {
  const PairingPending({
    required this.pairingId,
    required this.displayCode,
    required this.ephemeralPub,
    required this.expiresAt,
  });

  final String pairingId;
  final String displayCode;
  final String? ephemeralPub;
  final DateTime expiresAt;

  factory PairingPending.fromJson(Map<String, dynamic> json) {
    return PairingPending(
      pairingId: json['pairingId']?.toString() ?? '',
      displayCode: json['displayCode']?.toString() ?? '',
      ephemeralPub: json['ephemeralPub']?.toString(),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class PairingPollResult {
  const PairingPollResult._({
    required this.status,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.email,
    this.wrappedDek,
    this.approverEphemeralPub,
    this.encryptionEnabled = false,
  });

  final String status;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? email;
  final String? wrappedDek;
  final String? approverEphemeralPub;
  final bool encryptionEnabled;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isExpired => status == 'expired';

  factory PairingPollResult.fromJson(Map<String, dynamic> json) {
    final status = json['status']?.toString() ?? 'pending';
    return PairingPollResult._(
      status: status,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresIn: (json['expiresIn'] as num?)?.toInt(),
      email: json['email'] as String?,
      wrappedDek: json['wrappedDek'] as String?,
      approverEphemeralPub: json['approverEphemeralPub'] as String?,
      encryptionEnabled: json['encryptionEnabled'] == true,
    );
  }
}

class LinkedDevice {
  const LinkedDevice({
    required this.id,
    required this.appUserId,
    this.platform,
    this.appVersion,
    this.lastSyncedAt,
    this.createdAt,
    this.vaultState = 'none',
    this.trusted = false,
  });

  final String id;
  final String appUserId;
  final String? platform;
  final String? appVersion;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;
  final String vaultState;
  final bool trusted;

  bool get isThisDevice =>
      appUserId == DeviceIdentity.instance.appUserId;

  String get label {
    final platformLabel = (platform ?? 'Dispositivo').trim();
    if (isThisDevice) return '$platformLabel · este dispositivo';
    if (vaultState == 'revoked') return '$platformLabel · revocado';
    return platformLabel;
  }

  factory LinkedDevice.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(Object? value) {
      if (value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value)?.toLocal();
    }

    return LinkedDevice(
      id: json['id']?.toString() ?? '',
      appUserId: json['appUserId']?.toString() ?? '',
      platform: json['platform']?.toString(),
      appVersion: json['appVersion']?.toString(),
      lastSyncedAt: parseDate(json['lastSyncedAt']),
      createdAt: parseDate(json['createdAt']),
      vaultState: json['vaultState']?.toString() ?? 'none',
      trusted: json['trusted'] == true,
    );
  }
}

class PairingService {
  PairingService._();

  static final instance = PairingService._();

  Future<PairingStart> start({
    String? appUserId,
    String? ephemeralPub,
  }) async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }

    final response = await http.post(
      WodoApiConfig.uri('pairing/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (appUserId != null && appUserId.isNotEmpty) 'appUserId': appUserId,
        if (kIsWeb) 'clientPlatform': 'web',
        if (ephemeralPub != null && ephemeralPub.isNotEmpty)
          'ephemeralPub': ephemeralPub,
      }),
    );
    return PairingStart.fromJson(_responseData(response));
  }

  Future<PairingPending> fetchPending(String code) async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.get(
        WodoApiConfig.uri('pairing/pending', {'code': code.trim().toUpperCase()}),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return PairingPending.fromJson(_responseData(response));
  }

  Future<PairingPollResult> poll(String pollToken) async {
    final response = await http.get(
      WodoApiConfig.uri('pairing/poll'),
      headers: {
        'X-Pairing-Token': pollToken,
      },
    );
    return PairingPollResult.fromJson(_responseData(response));
  }

  Future<void> approve({
    String? pairingId,
    String? code,
    String? wrappedDek,
    String? approverEphemeralPub,
  }) async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.post(
        WodoApiConfig.uri('pairing/approve'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          if (pairingId != null && pairingId.isNotEmpty) 'pairingId': pairingId,
          if (code != null && code.isNotEmpty) 'code': code.trim().toUpperCase(),
          if (wrappedDek != null) 'wrappedDek': wrappedDek,
          if (approverEphemeralPub != null)
            'approverEphemeralPub': approverEphemeralPub,
        }),
      ),
    );
    _responseData(response);
  }

  /// Parses QR JSON / code and approves, wrapping DEK when vault is ready.
  Future<void> approveFromScanOrCode(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw StateError('Introduce el código que aparece en el otro dispositivo.');
    }

    String? pairingId;
    String? code;
    String? ephemeralPub;

    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
      pairingId = decoded['pairingId']?.toString();
      code = decoded['code']?.toString();
      ephemeralPub = decoded['ephemeralPub']?.toString();
    } else {
      final uuidLike = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      );
      if (uuidLike.hasMatch(trimmed)) {
        pairingId = trimmed;
      } else {
        code = trimmed;
      }
    }

    if (ephemeralPub == null && code != null) {
      final pending = await fetchPending(code);
      pairingId ??= pending.pairingId;
      ephemeralPub = pending.ephemeralPub;
    }

    String? wrappedDek;
    String? approverPub;
    final vault = VaultService.instance;
    if (vault.canSyncEncrypted && ephemeralPub != null && ephemeralPub.isNotEmpty) {
      final wrap = await vault.wrapDekForPairing(ephemeralPub);
      if (wrap != null) {
        wrappedDek = wrap.wrappedDek;
        approverPub = wrap.approverEphemeralPub;
      }
    }

    await approve(
      pairingId: pairingId,
      code: code,
      wrappedDek: wrappedDek,
      approverEphemeralPub: approverPub,
    );
  }

  Future<List<LinkedDevice>> listDevices() async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.get(
        WodoApiConfig.uri('devices'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    final data = _responseDataDynamic(response);
    if (data is! List) {
      throw const FormatException('Lista de dispositivos inválida.');
    }
    return data
        .whereType<Map<String, dynamic>>()
        .map(LinkedDevice.fromJson)
        .toList();
  }

  Future<void> revokeDevice(String appUserId) async {
    final response = await AuthService.instance.authorizedRequest(
      (token) => http.delete(
        WodoApiConfig.uri('devices/${Uri.encodeComponent(appUserId)}'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 204) return;
    _responseData(response);
  }

  Map<String, dynamic> _responseData(http.Response response) {
    final data = _responseDataDynamic(response);
    if (data is! Map<String, dynamic>) {
      throw const FormatException('La respuesta del servidor no es válida.');
    }
    return data;
  }

  dynamic _responseDataDynamic(http.Response response) {
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
    return decoded['data'];
  }
}

/// Holds the new-device X25519 keypair for the duration of a QR login attempt.
class PairingKeySession {
  PairingKeySession(this.keyPair);

  final SimpleKeyPair keyPair;

  static Future<PairingKeySession> create() async {
    final pair = await CryptoService.instance.generateX25519KeyPair();
    return PairingKeySession(pair);
  }

  Future<String> get publicKeyBase64 =>
      CryptoService.instance.publicKeyBase64(keyPair);
}
