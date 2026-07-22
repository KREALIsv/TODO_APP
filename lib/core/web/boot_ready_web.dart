import 'dart:js_interop';

@JS('wodoRemoveBoot')
external void _wodoRemoveBoot();

void notifyWebAppReady() {
  try {
    _wodoRemoveBoot();
  } catch (_) {
    // Boot shell may already be gone (hot reload, tests).
  }
}
