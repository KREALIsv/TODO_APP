/// Cross-tab signal transport (web: BroadcastChannel + localStorage fallback).
library;

export 'local_tab_sync_stub.dart'
    if (dart.library.js_interop) 'local_tab_sync_web.dart';
