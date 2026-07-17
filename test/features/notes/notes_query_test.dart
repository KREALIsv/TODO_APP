import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/notes_filter.dart';
import 'package:todos_app/features/notes/domain/notes_query.dart';

void main() {
  final baseTime = DateTime(2026, 7, 16, 12);

  NoteItem item({
    required String id,
    NoteType type = NoteType.note,
    String title = '',
    String body = '',
    bool pinned = false,
    DateTime? updatedAt,
  }) {
    return NoteItem(
      id: id,
      type: type,
      title: title,
      body: body,
      pinned: pinned,
      completed: false,
      createdAt: baseTime,
      updatedAt: updatedAt ?? baseTime,
    );
  }

  final sampleItems = [
    item(id: '1', title: 'Comprar leche', body: 'Supermercado', pinned: true),
    item(
      id: '2',
      title: 'Idea app',
      body: 'Notas con filtros',
      type: NoteType.note,
    ),
    item(
      id: '3',
      title: 'Enviar reporte',
      body: 'Antes del viernes',
      type: NoteType.task,
    ),
    item(id: '4', body: 'Apunte rápido sobre reunión'),
  ];

  group('NotesQuery.apply', () {
    test('returns all items when filter is all and search is empty', () {
      final result = NotesQuery.apply(items: sampleItems);
      expect(result.map((e) => e.id).toList(), ['1', '2', '3', '4']);
    });

    test('filters pinned items', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        filter: NotesFilter.pinned,
      );
      expect(result.map((e) => e.id).toList(), ['1']);
    });

    test('filters notes only', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        filter: NotesFilter.notes,
      );
      expect(result.every((e) => e.type == NoteType.note), isTrue);
      expect(result.map((e) => e.id).toList(), ['1', '2', '4']);
    });

    test('filters tasks only', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        filter: NotesFilter.tasks,
      );
      expect(result.map((e) => e.id).toList(), ['3']);
    });

    test('search matches title case-insensitively', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        searchQuery: 'IDEA',
      );
      expect(result.map((e) => e.id).toList(), ['2']);
    });

    test('search matches body', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        searchQuery: 'viernes',
      );
      expect(result.map((e) => e.id).toList(), ['3']);
    });

    test('combines filter and search', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        filter: NotesFilter.notes,
        searchQuery: 'reunión',
      );
      expect(result.map((e) => e.id).toList(), ['4']);
    });

    test('returns empty when search has no matches', () {
      final result = NotesQuery.apply(
        items: sampleItems,
        searchQuery: 'xyz',
      );
      expect(result, isEmpty);
    });
  });

  group('NotesQuery.useSectionedLayout', () {
    test('true only for all filter with empty search', () {
      expect(
        NotesQuery.useSectionedLayout(
          filter: NotesFilter.all,
          searchQuery: '',
        ),
        isTrue,
      );
      expect(
        NotesQuery.useSectionedLayout(
          filter: NotesFilter.all,
          searchQuery: 'test',
        ),
        isFalse,
      );
      expect(
        NotesQuery.useSectionedLayout(
          filter: NotesFilter.tasks,
          searchQuery: '',
        ),
        isFalse,
      );
    });
  });

  group('NotesQuery.emptyMessage', () {
    test('shows onboarding when app has no items', () {
      expect(
        NotesQuery.emptyMessage(
          filter: NotesFilter.all,
          searchQuery: '',
          hasAnyItems: false,
        ),
        'Tu primera nota está a un tap',
      );
    });

    test('shows search empty when query has no matches', () {
      expect(
        NotesQuery.emptyMessage(
          filter: NotesFilter.all,
          searchQuery: 'foo',
          hasAnyItems: true,
        ),
        'No se encontraron notas',
      );
    });

    test('shows filter-specific message', () {
      expect(
        NotesQuery.emptyMessage(
          filter: NotesFilter.tasks,
          searchQuery: '',
          hasAnyItems: true,
        ),
        'No hay tareas',
      );
    });
  });

  group('NotesQuery section helpers', () {
    test('pinnedFrom and recentFrom split filtered list', () {
      final filtered = NotesQuery.apply(items: sampleItems);
      final pinned = NotesQuery.pinnedFrom(filtered);
      final recent = NotesQuery.recentFrom(filtered);

      expect(pinned.map((e) => e.id).toList(), ['1']);
      expect(recent.map((e) => e.id).toList(), ['2', '3', '4']);
    });
  });
}
