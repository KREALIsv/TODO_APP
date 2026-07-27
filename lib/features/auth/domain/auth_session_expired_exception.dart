/// Thrown when the server rejects credentials and the local session was cleared.
class AuthSessionExpiredException implements Exception {
  AuthSessionExpiredException(this.userMessage);

  final String userMessage;

  @override
  String toString() => userMessage;
}
