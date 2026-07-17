import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../domain/default_tags.dart';

/// Catálogo persistente de etiquetas/categorías.
///
/// Independiente de las notas: las defaults viven aunque nadie las use aún,
/// y las nuevas se acumulan al crearlas. Deja API lista para una pantalla
/// de mantenimiento (listar / renombrar / eliminar).
class TagsRepository {
  TagsRepository._();

  static final TagsRepository instance = TagsRepository._();

  static const String _boxName = 'tags';
  static const String _namesKey = 'names';

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

  /// Inserta defaults que aún no existan (no borra las del usuario).
  Future<void> ensureDefaults() async {
    await ensureTags(kDefaultTags);
  }

  /// Añade nombres al catálogo si no existen (comparación case-insensitive).
  /// Conserva el display del primer uso.
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
  }

  Future<void> add(String name) => ensureTags([name]);

  /// Para mantenimiento futuro: elimina del catálogo (no toca notas).
  Future<void> remove(String name) async {
    final key = name.trim().toLowerCase();
    if (key.isEmpty) return;
    final next = getAll()
        .where((t) => t.toLowerCase() != key)
        .toList(growable: false);
    await _box.put(_namesKey, next);
  }

  @visibleForTesting
  Future<void> clear() async {
    await _box.clear();
  }
}
