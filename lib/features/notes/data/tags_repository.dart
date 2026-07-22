import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

import '../domain/default_tags.dart';
import '../domain/tag_colors.dart';

/// Catálogo persistente de etiquetas/categorías.
///
/// Independiente de las notas: las defaults viven aunque nadie las use aún,
/// y las nuevas se acumulan al crearlas. Cada etiqueta recuerda un color de
/// [TagColors.swatches] (id estable) y una opacidad.
class TagsRepository {
  TagsRepository._();

  static final TagsRepository instance = TagsRepository._();

  static const String _boxName = 'tags';
  static const String _namesKey = 'names';
  static const String _colorsKey = 'colors';
  static const String _opacitiesKey = 'opacities';

  late Box<dynamic> _box;

  Future<void> init() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    await ensureDefaults();
  }

  /// For tests: inject an already-opened box.
  @visibleForTesting
  Future<void> initWithBox(Box<dynamic> box) async {
    _box = box;
    await ensureDefaults();
  }

  ValueListenable<Box<dynamic>> listenable() => _box.listenable();

  List<String> getAll() {
    final raw = _box.get(_namesKey);
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Set<String> getAllAsSet() => getAll().toSet();

  Map<String, String> getColorMap() {
    final raw = _box.get(_colorsKey);
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString().toLowerCase(): entry.value.toString(),
    };
  }

  Map<String, double> getOpacityMap() {
    final raw = _box.get(_opacitiesKey);
    if (raw is! Map) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString().toLowerCase():
            TagColors.clampOpacity(_parseOpacity(entry.value)),
    };
  }

  String? getColorId(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return null;
    return getColorMap()[key];
  }

  double getOpacity(String name) {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return TagColors.defaultOpacity;
    return getOpacityMap()[key] ?? TagColors.defaultOpacity;
  }

  TagColorPair colorFor(String name) {
    return TagColors.pairForId(
      getColorId(name),
      fallbackTag: name,
      opacity: getOpacity(name),
    );
  }

  Future<void> setColor(String name, String colorId) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;
    if (TagColors.byId(colorId) == null) return;

    final colors = Map<String, String>.from(getColorMap());
    colors[key] = colorId;
    await _box.put(_colorsKey, colors);
  }

  Future<void> setOpacity(String name, double opacity) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;

    final opacities = Map<String, double>.from(getOpacityMap());
    opacities[key] = TagColors.clampOpacity(opacity);
    await _box.put(_opacitiesKey, opacities);
  }

  Future<void> setStyle(
    String name, {
    String? colorId,
    double? opacity,
  }) async {
    if (colorId != null) await setColor(name, colorId);
    if (opacity != null) await setOpacity(name, opacity);
  }

  /// Inserta defaults que aún no existan (no borra las del usuario).
  Future<void> ensureDefaults() async {
    await ensureTags(kDefaultTags);
  }

  /// Añade nombres al catálogo si no existen (comparación case-insensitive).
  /// Conserva el display del primer uso y asigna color por defecto si falta.
  Future<void> ensureTags(Iterable<String> names) async {
    final current = getAll().toList();
    final lower = {for (final t in current) t.toLowerCase()};
    var changed = false;

    for (final raw in names) {
      final name = raw.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (lower.contains(key)) continue;
      current.add(name);
      lower.add(key);
      changed = true;
    }

    if (changed) {
      await _box.put(_namesKey, current);
    }

    await _ensureColorsFor(current);
  }

  Future<void> ensureTag(
    String name, {
    String? colorId,
    double? opacity,
  }) async {
    await ensureTags([name]);
    await setStyle(name, colorId: colorId, opacity: opacity);
  }

  Future<void> add(String name) => ensureTags([name]);

  /// Renombra en el catálogo (y mueve color/opacidad). `false` si hay conflicto.
  Future<bool> rename(String from, String to) async {
    final oldName = from.trim();
    final newName = to.trim();
    if (oldName.isEmpty || newName.isEmpty) return false;

    final oldKey = oldName.toLowerCase();
    final newKey = newName.toLowerCase();
    final current = getAll().toList();
    final oldIndex = current.indexWhere((t) => t.toLowerCase() == oldKey);
    if (oldIndex < 0) return false;

    if (oldKey != newKey &&
        current.any((t) => t.toLowerCase() == newKey)) {
      return false;
    }

    current[oldIndex] = newName;
    await _box.put(_namesKey, current);

    if (oldKey != newKey) {
      final colors = Map<String, String>.from(getColorMap());
      final color = colors.remove(oldKey);
      if (color != null) colors[newKey] = color;
      await _box.put(_colorsKey, colors);

      final opacities = Map<String, double>.from(getOpacityMap());
      final opacity = opacities.remove(oldKey);
      if (opacity != null) opacities[newKey] = opacity;
      await _box.put(_opacitiesKey, opacities);
    }

    return true;
  }

  /// Elimina del catálogo (no toca notas; el caller debe limpiar notas).
  Future<void> remove(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;
    final next = getAll()
        .where((t) => t.toLowerCase() != key)
        .toList(growable: false);
    await _box.put(_namesKey, next);

    final colors = Map<String, String>.from(getColorMap())..remove(key);
    await _box.put(_colorsKey, colors);

    final opacities = Map<String, double>.from(getOpacityMap())..remove(key);
    await _box.put(_opacitiesKey, opacities);
  }

  Future<void> _ensureColorsFor(List<String> names) async {
    final colors = Map<String, String>.from(getColorMap());
    final opacities = Map<String, double>.from(getOpacityMap());
    var colorsChanged = false;
    var opacitiesChanged = false;

    for (final name in names) {
      final key = name.toLowerCase();
      final existing = colors[key];
      if (existing == null || TagColors.byId(existing) == null) {
        colors[key] = TagColors.defaultIdForTag(name);
        colorsChanged = true;
      }
      if (!opacities.containsKey(key)) {
        opacities[key] = TagColors.defaultOpacity;
        opacitiesChanged = true;
      }
    }

    if (colorsChanged) {
      await _box.put(_colorsKey, colors);
    }
    if (opacitiesChanged) {
      await _box.put(_opacitiesKey, opacities);
    }
  }

  static double _parseOpacity(Object? raw) {
    if (raw is num) return raw.toDouble();
    return double.tryParse(raw?.toString() ?? '') ?? TagColors.defaultOpacity;
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box.clear();
  }

  /// Full catalog snapshot for backup v2.
  Map<String, dynamic> exportSnapshot() {
    return {
      'names': getAll(),
      'colors': getColorMap(),
      'opacities': getOpacityMap(),
    };
  }

  /// Restores [snapshot] from backup. Invalid color ids fall back per tag.
  Future<void> replaceSnapshot(Map<String, dynamic> snapshot) async {
    final names = _parseNameList(snapshot['names']);
    final colors = _sanitizeColorMap(snapshot['colors'] as Map?);
    final opacities = _sanitizeOpacityMap(snapshot['opacities'] as Map?);

    await _box.put(_namesKey, names);
    await _box.put(_colorsKey, colors);
    await _box.put(_opacitiesKey, opacities);
    await _ensureColorsFor(names);
  }

  /// Wipes custom tags and restores product defaults (Settings → borrar todo).
  Future<void> resetToDefaults() async {
    await _box.clear();
    await ensureDefaults();
  }

  List<String> _parseNameList(Object? raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => e.toString().trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }

  Map<String, String> _sanitizeColorMap(Map? raw) {
    if (raw == null) return const {};
    final out = <String, String>{};
    for (final entry in raw.entries) {
      final key = entry.key.toString().toLowerCase();
      final id = entry.value.toString();
      if (key.isEmpty) continue;
      out[key] = TagColors.byId(id) != null
          ? id
          : TagColors.defaultIdForTag(key);
    }
    return out;
  }

  Map<String, double> _sanitizeOpacityMap(Map? raw) {
    if (raw == null) return const {};
    return {
      for (final entry in raw.entries)
        entry.key.toString().toLowerCase():
            TagColors.clampOpacity(_parseOpacity(entry.value)),
    };
  }
}
