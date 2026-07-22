import 'package:flutter/foundation.dart';

/// Notifies when a Hive-backed repository changes locally or reloads from
/// another browser tab (web).
class HiveRepoNotifier extends ChangeNotifier {
  Listenable? _boxListenable;

  void bind(Listenable boxListenable) {
    _boxListenable?.removeListener(_notify);
    _boxListenable = boxListenable;
    _boxListenable!.addListener(_notify);
  }

  void reloadComplete() => _notify();

  void _notify() {
    notifyListeners();
  }

  @override
  void dispose() {
    _boxListenable?.removeListener(_notify);
    super.dispose();
  }
}
