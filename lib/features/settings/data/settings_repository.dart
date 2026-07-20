import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/list_background.dart';

class SettingsRepository extends ChangeNotifier {
  SettingsRepository._();

  static final SettingsRepository instance = SettingsRepository._();

  static const String _boxName = 'settings';
  static const String _themeModeKey = 'themeMode';
  static const String _listBackgroundIdKey = 'listBackgroundId';
  static const String _showHeatmapDayNumbersKey = 'showHeatmapDayNumbers';

  late Box _box;

  Future<void> init() async {
    _box = await Hive.openBox(_boxName);
  }

  /// For tests: inject an already-opened box.
  @visibleForTesting
  Future<void> initWithBox(Box box) async {
    _box = box;
    notifyListeners();
  }

  ThemeMode get themeMode {
    final raw = _box.get(_themeModeKey) as String?;
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  String get themeModeLabel => switch (themeMode) {
        ThemeMode.light => 'Claro',
        ThemeMode.dark => 'Oscuro',
        ThemeMode.system => 'Sistema',
      };

  Future<void> setThemeMode(ThemeMode mode) async {
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _box.put(_themeModeKey, value);
    notifyListeners();
  }

  String get listBackgroundId {
    final raw = _box.get(_listBackgroundIdKey) as String?;
    if (raw == null || raw.isEmpty) return ListBackgrounds.defaultId;
    return raw;
  }

  ListBackgroundOption get listBackground =>
      ListBackgrounds.byId(listBackgroundId);

  Future<void> setListBackgroundId(String id) async {
    await _box.put(_listBackgroundIdKey, id);
    notifyListeners();
  }

  /// Whether heatmap cells show the calendar day number. Defaults to on.
  bool get showHeatmapDayNumbers {
    final raw = _box.get(_showHeatmapDayNumbersKey);
    if (raw is bool) return raw;
    return true;
  }

  String get showHeatmapDayNumbersLabel =>
      showHeatmapDayNumbers ? 'Visibles' : 'Ocultos';

  Future<void> setShowHeatmapDayNumbers(bool value) async {
    await _box.put(_showHeatmapDayNumbersKey, value);
    notifyListeners();
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box.clear();
    notifyListeners();
  }
}
