import 'dart:js_interop';

import 'package:web/web.dart';

/// Notifies other tabs on the same origin via BroadcastChannel, with a
/// localStorage ping for browsers without BroadcastChannel (older Safari).
abstract final class LocalTabSyncPlatform {
  static const _channelName = 'wodo-local-tab-sync-v1';
  static const _storageKey = 'wodo-local-tab-sync-v1';

  static bool _initialized = false;
  static void Function()? _onPeerTabChange;
  static BroadcastChannel? _channel;

  static void init(void Function() onPeerTabChange) {
    if (_initialized) return;
    _initialized = true;
    _onPeerTabChange = onPeerTabChange;

    try {
      _channel = BroadcastChannel(_channelName);
      _channel!.onmessage = (MessageEvent event) {
        _onPeerTabChange?.call();
      }.toJS;
    } catch (_) {
      _channel = null;
    }

    window.onstorage = (StorageEvent event) {
      if (event.key == _storageKey) {
        _onPeerTabChange?.call();
      }
    }.toJS;
  }

  static void notifyPeerTabs() {
    try {
      _channel?.postMessage('sync'.toJS);
    } catch (_) {}
    try {
      window.localStorage.setItem(
        _storageKey,
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
    } catch (_) {}
  }
}
