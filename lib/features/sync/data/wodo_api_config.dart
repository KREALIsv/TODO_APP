class WodoApiConfig {
  const WodoApiConfig._();

  /// Compile-time override; when empty, production API is used so sync works
  /// in local dev without extra flags (same as release deploy).
  static const _compileTimeUrl = String.fromEnvironment('WODO_API_URL');

  static const productionBaseUrl = 'https://api.wodo.app/api/v1';

  static String get baseUrl {
    final configured = _compileTimeUrl.trim();
    return configured.isEmpty ? productionBaseUrl : configured;
  }

  static bool get isConfigured => baseUrl.trim().isNotEmpty;

  static Uri uri(String path, [Map<String, String>? queryParameters]) {
    final base = Uri.parse(baseUrl);
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: '${base.path.replaceFirst(RegExp(r'/$'), '')}$normalizedPath',
      queryParameters: queryParameters,
    );
  }
}
