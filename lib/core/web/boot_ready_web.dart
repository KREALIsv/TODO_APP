import 'dart:js_interop';

import 'package:web/web.dart';

@JS('wodoRemoveBoot')
external void _wodoRemoveBoot();

const _sessionReadyKey = 'wodo-session-ready-v1';

void notifyWebAppReady() {
  try {
    window.sessionStorage.setItem(_sessionReadyKey, '1');
    _wodoRemoveBoot();
  } catch (_) {
    // Boot shell may already be gone (hot reload, tests).
  }
}
