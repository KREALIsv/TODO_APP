class WodoApiConfig {
  const WodoApiConfig._();

  static const baseUrl = String.fromEnvironment('WODO_API_URL');

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
