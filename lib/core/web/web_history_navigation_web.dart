import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:web/web.dart' hide Navigator;

/// Keeps Flutter [Navigator] routes in sync with the browser history stack on web.
///
/// Without this, iOS Safari's swipe-back / hardware back triggers a full page
/// reload (HTML boot splash) instead of popping the current route.
abstract final class WebHistoryNavigation {
  static GlobalKey<NavigatorState>? _navigatorKey;
  static bool _isPopStateEvent = false;
  static bool _installed = false;

  static void install(GlobalKey<NavigatorState> navigatorKey) {
    if (_installed) return;
    _installed = true;
    _navigatorKey = navigatorKey;

    // Anchor so the first browser-back does not leave the app.
    window.history.pushState(null, '', window.location.href);

    window.onpopstate = ((Event _) {
      _handlePopState();
    }).toJS;
  }

  static void dispose() {
    _installed = false;
    _navigatorKey = null;
    window.onpopstate = null;
  }

  static void _handlePopState() {
    _isPopStateEvent = true;
    final navigator = _navigatorKey?.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    } else {
      // Root route: stay on the app instead of navigating away / reloading.
      window.history.pushState(null, '', window.location.href);
    }
    Future<void>.microtask(() => _isPopStateEvent = false);
  }
}

/// Pushes a history entry when a modal route is pushed; syncs back on Flutter pop.
class WebHistoryNavigatorObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute<dynamic> && previousRoute != null) {
      window.history.pushState(null, '', window.location.href);
    }
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (WebHistoryNavigation._isPopStateEvent) return;
    if (route is! PageRoute<dynamic>) return;
    // AppBar / programmatic pop: align browser history without a second pop.
    window.history.back();
  }
}
