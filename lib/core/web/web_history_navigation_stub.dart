import 'package:flutter/material.dart';

/// No-op on native platforms.
abstract final class WebHistoryNavigation {
  static void install(GlobalKey<NavigatorState> navigatorKey) {}

  static void dispose() {}
}

/// Navigator observer for native — no history integration needed.
class WebHistoryNavigatorObserver extends NavigatorObserver {}
