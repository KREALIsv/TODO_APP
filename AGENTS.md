# AGENTS.md

## Cursor Cloud specific instructions

`todos_app` (branded "wodo") is a **local-first Flutter/Dart notes & tasks app**. It has **no backend, database server, or network dependencies** — all persistence is in-process via Hive, so no services beyond the Flutter app itself need to run. UI/product docs (PRD/TRD) are in Spanish; the runtime UI is Spanish.

### Toolchain
- The **Flutter SDK is preinstalled at `/opt/flutter`** (stable, Dart 3.12.2 — satisfies `pubspec.lock`'s `dart >=3.12.2`, `flutter >=3.38.4`).
- Interactive shells get `flutter`/`dart` on `PATH` via `~/.bashrc`. In non-interactive contexts, call the full path `/opt/flutter/bin/flutter` (this is what the startup update script does).
- Dependencies are refreshed automatically on startup via `flutter pub get` (the update script). No manual install needed.

### Common commands (run from repo root)
- Lint: `flutter analyze` — note there are ~21 pre-existing warnings/infos; a clean run is not expected.
- Test: `flutter test` (127 tests, all passing).
- Run (web): `flutter run -d web-server --web-port 8080 --web-hostname 0.0.0.0`, then open `http://localhost:8080/` in Chrome. First compile takes ~15-20s.
- Run (other targets): `-d chrome` or `-d linux` desktop are also available devices.

### Notes / gotchas
- First web page load is slow (Flutter compiles to JS on first request); wait ~15-20s or refresh once before assuming a failure.
- Local notifications (`flutter_local_notifications`) bootstrap is best-effort and is skipped gracefully on web/hot-reload; the app works without it.
