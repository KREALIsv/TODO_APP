import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../../sync/data/device_registry.dart';
import '../../sync/data/wodo_api_config.dart';
import '../domain/auth_errors.dart';
import '../domain/auth_session_expired_exception.dart';
import '../domain/user_profile.dart';
import 'auth_session_repository.dart';

class AuthService extends ChangeNotifier {
  AuthService._();

  static final instance = AuthService._();

  AuthSessionRepository get _sessions => AuthSessionRepository.instance;

  String? _sessionEndedMessage;

  bool get isConfigured => WodoApiConfig.isConfigured;
  bool get isAuthenticated => _sessions.isAuthenticated;
  String? get userEmail => _sessions.userEmail;

  /// User-facing copy for a dialog after [endSessionDueToExpiry]; consumed once.
  String? consumeSessionEndedMessage() {
    final message = _sessionEndedMessage;
    _sessionEndedMessage = null;
    return message;
  }

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

  Future<void> requestPasswordReset(String email) async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }
    final response = await http.post(
      WodoApiConfig.uri('auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email.trim()}),
    );
    _responseData(response);
  }

  Future<void> resetPassword({
    required String token,
    required String password,
  }) async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }
    final response = await http.post(
      WodoApiConfig.uri('auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token.trim(), 'password': password}),
    );
    if (response.statusCode == 204) return;
    _responseData(response);
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
    _sessionEndedMessage = null;
    await _sessions.clear();
    notifyListeners();
  }

  Future<UserProfile> fetchProfile() async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }
    final response = await authorizedRequest(
      (token) => http.get(
        WodoApiConfig.uri('users/me'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    return UserProfile.fromJson(_responseData(response));
  }

  /// Deletes the remote account and all synced cloud data (cascade on server).
  Future<void> deleteRemoteAccount() async {
    if (!WodoApiConfig.isConfigured) {
      throw StateError('La sincronización aún no está configurada.');
    }
    final response = await authorizedRequest(
      (token) => http.delete(
        WodoApiConfig.uri('users/me'),
        headers: {'Authorization': 'Bearer $token'},
      ),
    );
    if (response.statusCode == 204) return;
    throw StateError(
      AuthErrors.fromHttpFailure(
        statusCode: response.statusCode,
        apiMessage: _decodeMessage(response),
      ),
    );
  }

  Future<String?> accessToken({bool forceRefresh = false}) async {
    final session = _sessions.session;
    if (session == null) return null;

    final needsRefresh = forceRefresh ||
        session.isExpired ||
        (kIsWeb && _shouldRefreshEarly(session));
    if (!needsRefresh) return session.accessToken;

    return _refreshAccessToken(session);
  }

  /// Runs [send] with a bearer token; refreshes once on 401/410 before ending session.
  ///
  /// When [invalidateSessionOnAuthFailure] is false, auth failures are surfaced
  /// without clearing the stored session (used for best-effort device registration).
  Future<http.Response> authorizedRequest(
    Future<http.Response> Function(String token) send, {
    bool invalidateSessionOnAuthFailure = true,
  }) async {
    var token = await accessToken();
    if (token == null) {
      throw AuthSessionExpiredException(AuthErrors.sessionExpiredMessage());
    }

    var response = await send(token);
    if (AuthErrors.isAuthFailureStatus(response.statusCode)) {
      token = await accessToken(forceRefresh: true);
      if (token == null) {
        throw AuthSessionExpiredException(
          _sessionEndedMessage ?? AuthErrors.sessionExpiredMessage(),
        );
      }
      response = await send(token);
    }

    if (AuthErrors.isAuthFailureStatus(response.statusCode)) {
      final message = AuthErrors.fromHttpFailure(
        statusCode: response.statusCode,
        apiMessage: _decodeMessage(response),
      );
      if (invalidateSessionOnAuthFailure) {
        await endSessionDueToExpiry(message);
      }
      throw AuthSessionExpiredException(message);
    }

    return response;
  }

  Future<void> endSessionDueToExpiry(String userMessage) async {
    if (!_sessions.isAuthenticated) return;
    await _sessions.clear();
    _sessionEndedMessage = userMessage;
    notifyListeners();
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
      body: jsonEncode({
        'email': email.trim(),
        'password': password,
        ..._clientPlatformField(),
      }),
    );
    final payload = _responseData(response);
    await _saveSession(
      payload,
      email: email.trim().toLowerCase(),
    );
    try {
      await DeviceRegistry.instance.register();
    } on AuthSessionExpiredException {
      // Sign-in succeeded; device registration is retried during sync.
    } catch (_) {
      // Network / server errors should not block login.
    }
    await _sessions.rememberLoginEmail(email.trim().toLowerCase());
    notifyListeners();
  }

  Future<String?> _refreshAccessToken(AuthSession session) async {
    try {
      final response = await http.post(
        WodoApiConfig.uri('auth/refresh'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'refreshToken': session.refreshToken,
          ..._clientPlatformField(),
        }),
      );

      if (AuthErrors.isAuthFailureStatus(response.statusCode)) {
        final message = AuthErrors.fromHttpFailure(
          statusCode: response.statusCode,
          apiMessage: _decodeMessage(response),
        );
        await endSessionDueToExpiry(message);
        return null;
      }

      final payload = _responseData(response);
      await _saveSession(payload);
      notifyListeners();
      return _sessions.session?.accessToken;
    } catch (error) {
      if (error is AuthSessionExpiredException) rethrow;
      final message = AuthErrors.sessionExpiredMessage();
      await endSessionDueToExpiry(message);
      return null;
    }
  }

  bool _shouldRefreshEarly(AuthSession session) {
    // Web tabs stay open for hours — renew well before the access token expires.
    const buffer = Duration(minutes: 30);
    return !session.expiresAt.isAfter(DateTime.now().add(buffer));
  }

  Map<String, String> _clientPlatformField() {
    if (kIsWeb) return const {'clientPlatform': 'web'};
    return const {'clientPlatform': 'mobile'};
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
      throw StateError(
        AuthErrors.fromHttpFailure(
          statusCode: response.statusCode,
          apiMessage: decoded['message']?.toString(),
        ),
      );
    }
    final data = decoded['data'];
    if (data is! Map<String, dynamic>) {
      throw const FormatException('La respuesta del servidor no es válida.');
    }
    return data;
  }

  String? _decodeMessage(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final message = decoded['message'];
      if (message is String) return message;
      if (message is Map) {
        final nested = message['message'];
        if (nested is String) return nested;
      }
      return message?.toString();
    } catch (_) {
      return null;
    }
  }
}
