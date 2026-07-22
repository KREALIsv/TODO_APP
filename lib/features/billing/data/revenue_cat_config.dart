import 'package:flutter/foundation.dart';

class RevenueCatConfig {
  const RevenueCatConfig._();

  static const appleApiKey = String.fromEnvironment('RC_APPLE_API_KEY');
  static const googleApiKey = String.fromEnvironment('RC_GOOGLE_API_KEY');
  static const webApiKey = String.fromEnvironment('RC_WEB_API_KEY');
  static const appUserIdOverride = String.fromEnvironment('WODO_APP_USER_ID');

  static String get apiKey {
    if (kIsWeb) return webApiKey;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS || TargetPlatform.macOS => appleApiKey,
      TargetPlatform.android => googleApiKey,
      _ => '',
    };
  }

  static bool get isConfigured => apiKey.trim().isNotEmpty;

  static String get platformLabel {
    if (kIsWeb) return 'Web / Paddle';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'iOS / App Store',
      TargetPlatform.android => 'Android / Google Play',
      TargetPlatform.macOS => 'macOS / App Store',
      _ => 'Plataforma no compatible',
    };
  }
}
