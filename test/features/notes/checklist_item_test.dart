import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/checklist_item.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  group('ChecklistItem', () {
    test('round-trips through toMap/fromMap', () {
      const item = ChecklistItem(
        id: 'a',
        title: 'Comprar leche',
        completed: true,
        sortOrder: 2,
      );

      final restored = ChecklistItem.fromMap(item.toMap());
      expect(restored.id, 'a');
      expect(restored.title, 'Comprar leche');
      expect(restored.completed, isTrue);
      expect(restored.sortOrder, 2);
    });
  });

  group('NoteItem checklist', () {
    test('serializes checklist fields', () {
      final note = NoteItem(
        id: '1',
        type: NoteType.task,
        title: 'Tarea',
        body: '',
        pinned: false,
        completed: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        checklistTitle: 'Checklist',
        checklistItems: const [
          ChecklistItem(id: 's1', title: 'Paso 1', completed: false),
          ChecklistItem(id: 's2', title: 'Paso 2', completed: true),
        ],
      );

      final map = note.toMap();
      expect(map['checklistTitle'], 'Checklist');
      expect(map['checklistItems'], isA<List>());
      expect((map['checklistItems'] as List).length, 2);

      final restored = NoteItem.fromMap(map);
      expect(restored.checklistTitle, 'Checklist');
      expect(restored.checklistItems.length, 2);
      expect(restored.checklistCompletedCount, 1);
      expect(restored.hasChecklist, isTrue);
    });

    test('fromMap tolerates missing checklist fields', () {
      final note = NoteItem.fromMap({
        'id': '1',
        'type': 'task',
        'title': 'Tarea',
        'body': '',
        'pinned': false,
        'completed': false,
        'createdAt': '2026-07-01T00:00:00.000',
        'updatedAt': '2026-07-01T00:00:00.000',
      });

      expect(note.checklistTitle, isNull);
      expect(note.checklistItems, isEmpty);
      expect(note.hasChecklist, isFalse);
    });

    test('copyWith can clear checklist title', () {
      final note = NoteItem(
        id: '1',
        type: NoteType.task,
        title: 'Tarea',
        body: '',
        pinned: false,
        completed: false,
        createdAt: DateTime(2026, 7, 1),
        updatedAt: DateTime(2026, 7, 1),
        checklistTitle: 'Checklist',
        checklistItems: const [
          ChecklistItem(id: 's1', title: 'Paso 1'),
        ],
      );

      final cleared = note.copyWith(checklistTitle: null, checklistItems: const []);
      expect(cleared.checklistTitle, isNull);
      expect(cleared.checklistItems, isEmpty);
    });
  });
}
