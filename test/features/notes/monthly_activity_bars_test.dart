import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/activity_stats.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  NoteItem note({
    required String id,
    required DateTime createdAt,
    DateTime? updatedAt,
    bool archived = false,
  }) {
    return NoteItem(
      id: id,
      type: NoteType.note,
      title: 'Nota $id',
      body: 'body',
      pinned: false,
      completed: false,
      createdAt: createdAt,
      updatedAt: updatedAt ?? createdAt,
      archivedAt: archived ? createdAt : null,
    );
  }

  group('monthlyEventBars', () {
    test('aggregates event counts into 12 calendar months', () {
      final now = DateTime(2026, 7, 20);
      final items = [
        note(id: '1', createdAt: DateTime(2026, 7, 2)),
        note(id: '2', createdAt: DateTime(2026, 7, 10)),
        note(id: '3', createdAt: DateTime(2026, 6, 5)),
        note(
          id: '4',
          createdAt: DateTime(2026, 5, 1),
          updatedAt: DateTime(2026, 5, 20),
        ),
      ];
      final metrics = activityMetricsFrom(items);
      final bars = monthlyEventBars(
        eventCounts: metrics.eventCounts,
        now: now,
        months: 12,
      );

      expect(bars, hasLength(12));
      expect(bars.last.month, 7);
      expect(bars.last.year, 2026);
      expect(bars.last.label, 'J');
      expect(bars.last.count, 2);

      final june = bars[bars.length - 2];
      expect(june.month, 6);
      expect(june.count, 1);

      final may = bars[bars.length - 3];
      expect(may.month, 5);
      expect(may.count, 2);
    });

    test('ignores archived items via activityMetricsFrom', () {
      final now = DateTime(2026, 7, 20);
      final items = [
        note(id: '1', createdAt: DateTime(2026, 7, 2), archived: true),
        note(id: '2', createdAt: DateTime(2026, 7, 3)),
      ];
      final metrics = activityMetricsFrom(items);
      final bars = monthlyEventBars(
        eventCounts: metrics.eventCounts,
        now: now,
      );

      expect(bars.last.count, 1);
    });

    test('empty counts yield zero bars', () {
      final bars = monthlyEventBars(
        eventCounts: const {},
        now: DateTime(2026, 7, 20),
        months: 6,
      );
      expect(bars, hasLength(6));
      expect(bars.every((b) => b.count == 0), isTrue);
      expect(bars.map((b) => b.label).toList(), ['F', 'M', 'A', 'M', 'J', 'J']);
    });
  });
}
