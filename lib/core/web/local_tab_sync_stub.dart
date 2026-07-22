/// No-op on native — cross-tab sync is a web-only concern.
abstract final class LocalTabSyncPlatform {
  static void init(void Function() onPeerTabChange) {}

  static void notifyPeerTabs() {}
}
