import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../app/content_bootstrap.dart';
import '../../core/storage/local_storage_service.dart';

/// Session UI lock + cold-start unlock. Does not close Hive boxes on pause.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController._();

  static final instance = AppLockController._();

  bool _contentReady = true;
  bool _uiLocked = false;
  bool _observing = false;

  bool get contentReady => _contentReady;
  bool get uiLocked => _uiLocked;

  bool get shouldShowLock {
    final storage = LocalStorageService.instance;
    if (!storage.isAppLockEnabled) return false;
    if (!storage.isSessionUnlocked) return true;
    return _uiLocked;
  }

  void attach() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_observing) return;
    _observing = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// Call from bootstrap when content boxes were opened before [TodosApp].
  void markContentReady() {
    _contentReady = true;
    _uiLocked = false;
  }

  /// Call from bootstrap when the PIN wrap exists and LDEK is not in memory.
  void prepareLockedLaunch() {
    _contentReady = false;
    _uiLocked = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!LocalStorageService.instance.isAppLockEnabled) return;
    if (!_contentReady) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      if (!_uiLocked) {
        _uiLocked = true;
        notifyListeners();
      }
    }
  }

  Future<bool> unlock(String pin) async {
    final storage = LocalStorageService.instance;
    if (!storage.isSessionUnlocked) {
      final ok = await storage.unlockWithPin(pin);
      if (!ok) return false;
      if (!_contentReady) {
        await openContentRepositories();
        unawaited(runPostContentBootstrap());
        _contentReady = true;
      }
    }
    _uiLocked = false;
    notifyListeners();
    return true;
  }

  Future<void> resetForgottenPin() async {
    await LocalStorageService.instance.resetAfterForgottenPin();
    await openContentRepositories(force: true);
    unawaited(runPostContentBootstrap());
    _contentReady = true;
    _uiLocked = false;
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _contentReady = true;
    _uiLocked = false;
  }
}
