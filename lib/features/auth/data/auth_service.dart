import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../sync/data/device_registry.dart';
import '../../sync/data/wodo_api_config.dart';
import 'auth_session_repository.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final instance = AuthService._();

  AuthSessionRepository get _sessions => AuthSessionRepository.instance;

  bool get isConfigured => WodoApiConfig.isConfigured;
  bool get isAuthenticated => _sessions.isAuthenticated;
  String? get userEmail => _sessions.userEmail;

  String get userInitials {
    final email = userEmail;
    if (email == null || email.isEmpty) return '';
    final local = email.split('@').first.trim();
    if (local.isEmpty) return '?';
    if (local.length >= 2) return local.substring(0, 2).toUpperCase();
    return local.substring(0, 1).toUpperCase();
  }

  Future<void> register({required String email, required String password}) {
    return _authenticate('auth/register', email: email, password: password);
  }

  Future<void> login({required String email, required String password}) {
    return _authenticate('auth/login', email: email, password: password);
  }

  Future<void> logout() async {
    final session = _sessions.session;
    if (session != null && WodoApiConfig.isConfigured) {
      try {
        await http.post(
          WodoApiConfig.uri('auth/logout'),
          headers: {'Authorization': 'Bearer ${session.accessToken}'},
        );
      } catch (_) {}
    }
    await _sessions.clear();
    notifyListeners();
  }

  Future<String?> accessToken() async {
    final session = _sessions.session;
    if (session == null) return null;
    if (!session.isExpired) return session.accessToken;

    final response = await http.post(
      WodoApiConfig.uri('auth/refresh'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refreshToken': session.refreshToken}),
    );
    final payload = _responseData(response);
    await _saveSession(payload);
    return _sessions.session?.accessToken;
  }

  Future<void> _authenticate(
    String path, {
    required String email,
    required String password,
  }) async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }
    final response = await http.post(
      WodoApiConfig.uri(path),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim(), 'password': password}),
    );
    final payload = _responseData(response);
    await _saveSession(
      payload,
      email: email.trim().toLowerCase(),
    );
    final token = _sessions.session?.accessToken;
    if (token != null) {
      await DeviceRegistry.instance.register(token);
    }
    notifyListeners();
  }

  Future<void> _saveSession(
    Map<String, dynamic> payload, {
    String? email,
  }) {
    final accessToken = payload['accessToken'];
    final refreshToken = payload['refreshToken'];
    final expiresIn = payload['expiresIn'];
    if (accessToken is! String ||
        refreshToken is! String ||
        expiresIn is! num) {
      throw const FormatException(
        'La respuesta de autenticación no es válida.',
      );
    }
    return _sessions.save(
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresInSeconds: expiresIn.toInt(),
      email: email,
    );
  }

  Map<String, dynamic> _responseData(http.Response response) {
    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final error = decoded['message'] ?? 'No se pudo completar la solicitud.';
      throw StateError(error.toString());
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('La respuesta del servidor no es válida.');
    }
    return data;
  }
}
