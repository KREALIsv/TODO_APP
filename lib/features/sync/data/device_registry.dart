import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../auth/data/auth_service.dart';
import 'device_identity.dart';
import 'wodo_api_config.dart';

class DeviceRegistry {
  DeviceRegistry._();

  static final instance = DeviceRegistry._();

  Future<void> register() async {
    if (!WodoApiConfig.isConfigured) return;
    final identity = DeviceIdentity.instance;
    final appVersion = await identity.appVersionLabel();
    await AuthService.instance.authorizedRequest(
      (accessToken) => http.post(
        WodoApiConfig.uri('devices/register'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'appUserId': identity.appUserId,
          'platform': identity.platformLabel,
          'appVersion': appVersion,
        }),
      ),
      // Device metadata is best-effort; sync endpoints own session invalidation.
      invalidateSessionOnAuthFailure: false,
    );
  }
}
