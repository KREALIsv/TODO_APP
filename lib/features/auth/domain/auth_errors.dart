/// Maps API auth errors to user-facing Spanish messages.
abstract final class AuthErrors {
  static String message(Object error, {required bool registering}) {
    final raw = error.toString().replaceFirst('Bad state: ', '').trim();

    if (raw.contains('Invalid credentials')) {
      return 'Correo o contraseña incorrectos. Revísalos e inténtalo de nuevo.';
    }
    if (raw.contains('Email already registered')) {
      return registering
          ? 'Este correo ya tiene cuenta. Inicia sesión o pulsa «Usar otra cuenta».'
          : 'Este correo ya está registrado. Prueba a iniciar sesión.';
    }
    if (raw.contains('Invalid or expired reset token')) {
      return 'El enlace ha caducado o ya se usó. Solicita uno nuevo desde «¿Olvidaste tu contraseña?».';
    }
    if (raw.contains('Has alcanzado el límite de correos')) {
      return 'Has alcanzado el límite de correos para este proceso. Inténtalo más tarde.';
    }
    if (raw.contains('Too Many Requests') ||
        raw.contains('ThrottlerException')) {
      return 'Demasiados intentos seguidos. Espera unos minutos e inténtalo de nuevo.';
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
