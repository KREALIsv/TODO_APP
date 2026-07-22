{{flutter_js}}
{{flutter_build_config}}

// Do not pass serviceWorkerSettings. Flutter's current "offline-first"
// worker is an uninstall stub that calls client.navigate() and leaves some
// mobile Safari / PWA sessions on a permanent white screen after updates.
_flutter.loader.load();
