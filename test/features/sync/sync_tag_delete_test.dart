import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/sync/domain/sync_snapshot.dart';
import 'package:todos_app/features/sync/domain/sync_tags.dart';

void main() {
  group('tagSyncEntityId', () {
    test('normalizes display names', () {
      expect(tagSyncEntityId('Work'), 'tag_work');
      expect(tagSyncEntityId('  Gym  '), 'tag_gym');
    });
  });

  group('resolveTagNameForDelete', () {
    test('uses pre-pull snapshot when available', () {
      expect(
        resolveTagNameForDelete(
          entityId: 'tag_work',
          beforePullTags: {
            'tag_work': {'name': 'Work'},
          },
          catalogNames: const [],
        ),
        'Work',
      );
    });

    test('falls back to local catalog on fresh device replay', () {
      expect(
        resolveTagNameForDelete(
          entityId: 'tag_work',
          beforePullTags: const {},
          catalogNames: const ['Work', 'Personal'],
        ),
        'Work',
      );
    });

    test('returns null when tag cannot be resolved', () {
      expect(
        resolveTagNameForDelete(
          entityId: 'tag_missing',
          beforePullTags: const {},
          catalogNames: const ['Other'],
        ),
        isNull,
      );
    });
  });

  group('fresh device tag delete replay', () {
    SyncEntitySnapshot applyTagMutations(
      SyncEntitySnapshot base,
      List<Map<String, dynamic>> mutations, {
      required List<String> catalog,
    }) {
      final next = {
        for (final section in base.entries)
          section.key: Map<String, Map<String, dynamic>>.from(section.value),
      };

      for (final mutation in mutations) {
        final entityType = mutation['entityType'] as String;
        final entityId = mutation['entityId'] as String;
        final operation = mutation['operation'] as String;
        if (entityType != 'tag') continue;

        if (operation == 'DELETE') {
          final name = resolveTagNameForDelete(
            entityId: entityId,
            beforePullTags: base['tag'],
            catalogNames: catalog,
          );
          if (name != null) {
            catalog.removeWhere((tag) => tag.toLowerCase() == name.toLowerCase());
          }
          next['tag']?.remove(entityId);
          continue;
        }

        final payload = mutation['payload'] as Map<String, dynamic>?;
        final name = payload?['name'] as String?;
        if (name != null && name.trim().isNotEmpty) {
          if (!catalog.any((tag) => tag.toLowerCase() == name.toLowerCase())) {
            catalog.add(name);
          }
          next.putIfAbsent('tag', () => {})[entityId] = payload!;
        }
      }

      return next;
    }

    test('DELETE after CREATE removes tag on empty snapshot', () {
      final catalog = <String>[];
      const beforePull = <String, Map<String, Map<String, dynamic>>>{};

      final mutations = [
        {
          'entityType': 'tag',
          'entityId': 'tag_work',
          'operation': 'CREATE',
          'payload': {'name': 'Work', 'colorId': 'blue', 'opacity': 1.0},
        },
        {
          'entityType': 'tag',
          'entityId': 'tag_work',
          'operation': 'DELETE',
        },
      ];

      applyTagMutations(beforePull, mutations, catalog: catalog);

      expect(catalog, isEmpty);
    });
  });
}
