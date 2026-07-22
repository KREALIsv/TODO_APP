import 'dart:convert';

import 'package:http/http.dart' as http;

import 'device_identity.dart';
import 'wodo_api_config.dart';

class DeviceRegistry {
  DeviceRegistry._();

  static final instance = DeviceRegistry._();

  Future<void> register(String accessToken) async {
    if (!WodoApiConfig.isConfigured) return;
    final identity = DeviceIdentity.instance;
    final response = await http.post(
      WodoApiConfig.uri('devices/register'),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'appUserId': identity.appUserId,
        'platform': identity.platformLabel,
        'appVersion': await identity.appVersionLabel(),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body) as Map<String, dynamic>;
      throw StateError(
        (decoded['message'] ?? 'No se pudo registrar el dispositivo.').toString(),
      );
    }
  }
}
