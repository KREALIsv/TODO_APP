import '../domain/auth_session_expired_exception.dart';

/// Maps API auth errors to user-facing Spanish messages.
abstract final class AuthErrors {
  static const sessionExpiredTitle = 'Sesión cerrada';

  /// Default copy when the cloud session is no longer valid.
  static String sessionExpiredMessage() {
    return 'Tu sesión en la nube expiró. '
        'Tus notas y tareas siguen guardadas en este dispositivo.\n\n'
        'Vuelve a iniciar sesión cuando quieras sincronizar.';
  }

  static bool isAuthFailureStatus(int statusCode) =>
      statusCode == 401 || statusCode == 410;

  static bool looksLikeAuthMessage(String? message) {
    if (message == null || message.isEmpty) return false;
    final lower = message.toLowerCase();
    return lower.contains('unauthorized') ||
        lower.contains('invalid token') ||
        lower.contains('token expired') ||
        lower.contains('session invalid') ||
        lower.contains('refresh token') ||
        lower.contains('authorization header');
  }

  static String fromHttpFailure({
    required int statusCode,
    String? apiMessage,
  }) {
    final normalized = apiMessage?.trim().toLowerCase() ?? '';
    if (normalized.contains('invalid credentials')) {
      return 'Correo o contraseña incorrectos. Revísalos e inténtalo de nuevo.';
    }
    if (isAuthFailureStatus(statusCode) || looksLikeAuthMessage(apiMessage)) {
      return sessionExpiredMessage();
    }
    if (apiMessage != null && apiMessage.trim().isNotEmpty) {
      return apiMessage.trim();
    }
    return 'No se pudo completar la solicitud.';
  }

  static String message(Object error, {required bool registering}) {
    if (error is AuthSessionExpiredException) {
      return error.userMessage;
    }

    final raw = error.toString().replaceFirst('Bad state: ', '').trim();

    if (looksLikeAuthMessage(raw) ||
        raw.contains('401') ||
        raw.contains('410')) {
      return sessionExpiredMessage();
    }
    if (raw.contains('Invalid credentials')) {
      return 'Correo o contraseña incorrectos. Revísalos e inténtalo de nuevo.';
    }
    if (raw.contains('Email already registered')) {
      return registering
          ? 'Este correo ya tiene cuenta. Inicia sesión o pulsa «Usar otra cuenta».'
          : 'Este correo ya está registrado. Prueba a iniciar sesión.';
    }
    if (raw.contains('La sincronización aún no está configurada')) {
      return 'La sincronización aún no está disponible en esta versión.';
    }
    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.contains('Connection refused')) {
      return 'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.';
    }

    return raw.isEmpty ? 'No se pudo completar la solicitud.' : raw;
  }
}
