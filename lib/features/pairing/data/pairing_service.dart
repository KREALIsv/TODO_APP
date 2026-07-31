import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../auth/data/auth_service.dart';
import '../../auth/domain/auth_errors.dart';
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

class PairingPollResult {
  const PairingPollResult._({
    required this.status,
    this.accessToken,
    this.refreshToken,
    this.expiresIn,
    this.email,
  });

  final String status;
  final String? accessToken;
  final String? refreshToken;
  final int? expiresIn;
  final String? email;

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
  });

  final String id;
  final String appUserId;
  final String? platform;
  final String? appVersion;
  final DateTime? lastSyncedAt;
  final DateTime? createdAt;

  bool get isThisDevice =>
      appUserId == DeviceIdentity.instance.appUserId;

  String get label {
    final platformLabel = (platform ?? 'Dispositivo').trim();
    if (isThisDevice) return '$platformLabel · este dispositivo';
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
    );
  }
}

class PairingService {
  PairingService._();

  static final instance = PairingService._();

  Future<PairingStart> start({String? appUserId}) async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }

    final response = await http.post(
      WodoApiConfig.uri('pairing/start'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        if (appUserId != null && appUserId.isNotEmpty) 'appUserId': appUserId,
        if (kIsWeb) 'clientPlatform': 'web',
      }),
    );
    return PairingStart.fromJson(_responseData(response));
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

  Future<void> approve({String? pairingId, String? code}) async {
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
        }),
      ),
    );
    _responseData(response);
  }

  /// Parses QR JSON payload or a bare display code / pairing UUID.
  Future<void> approveFromScanOrCode(String raw) async {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      throw StateError('Introduce el código que aparece en el otro dispositivo.');
    }

    if (trimmed.startsWith('{')) {
      final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
      final pairingId = decoded['pairingId']?.toString();
      final code = decoded['code']?.toString();
      await approve(pairingId: pairingId, code: code);
      return;
    }

    final uuidLike = RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    );
    if (uuidLike.hasMatch(trimmed)) {
      await approve(pairingId: trimmed);
      return;
    }

    await approve(code: trimmed);
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
