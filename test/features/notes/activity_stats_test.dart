import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/activity_stats.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/activity_heatmap.dart';
import 'package:todos_app/features/notes/presentation/widgets/activity_strip.dart';
import 'package:todos_app/global/themes/app_colors.dart';

void main() {
  NoteItem note({
    required String id,
    required DateTime createdAt,
    DateTime? updatedAt,
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
    );
  }

  group('activeDaysFrom', () {
    test('unions createdAt and updatedAt date-only', () {
      final items = [
        note(
          id: '1',
          createdAt: DateTime(2026, 7, 10, 9),
          updatedAt: DateTime(2026, 7, 12, 18),
        ),
        note(id: '2', createdAt: DateTime(2026, 7, 12, 8)),
      ];

      final days = activeDaysFrom(items);
      expect(days, {
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 12),
      });
    });
  });

  group('currentStreak', () {
    test('counts consecutive days ending today', () {
      final now = DateTime(2026, 7, 16, 15);
      final days = {
        DateTime(2026, 7, 14),
        DateTime(2026, 7, 15),
        DateTime(2026, 7, 16),
      };
      expect(currentStreak(days, now: now), 3);
    });

    test('gap breaks streak', () {
      final now = DateTime(2026, 7, 16, 15);
      final days = {
        DateTime(2026, 7, 12),
        DateTime(2026, 7, 14),
        DateTime(2026, 7, 16),
      };
      expect(currentStreak(days, now: now), 1);
    });

    test('allows streak to start from yesterday when today empty', () {
      final now = DateTime(2026, 7, 16, 15);
      final days = {
        DateTime(2026, 7, 14),
        DateTime(2026, 7, 15),
      };
      expect(currentStreak(days, now: now), 2);
    });

    test('returns 0 when no recent activity', () {
      final now = DateTime(2026, 7, 16, 15);
      final days = {DateTime(2026, 7, 10)};
      expect(currentStreak(days, now: now), 0);
    });
  });

  group('longestStreak', () {
    test('returns 0 for empty set', () {
      expect(longestStreak({}), 0);
    });

    test('returns longest consecutive run', () {
      final days = {
        DateTime(2026, 7, 1),
        DateTime(2026, 7, 2),
        DateTime(2026, 7, 3),
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 11),
      };
      expect(longestStreak(days), 3);
    });

    test('single day is streak of 1', () {
      expect(longestStreak({DateTime(2026, 7, 10)}), 1);
    });
  });

  group('weekActiveMaskFor', () {
    test('marks monday-first active days in current week', () {
      // Thursday 16 Jul 2026 → week Mon 13 – Sun 19
      final now = DateTime(2026, 7, 16);
      final mask = weekActiveMaskFor(
        {
          DateTime(2026, 7, 13), // Mon
          DateTime(2026, 7, 15), // Wed
          DateTime(2026, 7, 16), // Thu
        },
        now: now,
      );
      expect(mask, [true, false, true, true, false, false, false]);
    });
  });

  group('weekCounts / ActivityStats', () {
    test('cells length is weeks * 7', () {
      final now = DateTime(2026, 7, 16); // Thursday
      final items = [
        note(id: '1', createdAt: DateTime(2026, 7, 16, 10)),
        note(
          id: '2',
          createdAt: DateTime(2026, 7, 14, 10),
          updatedAt: DateTime(2026, 7, 15, 11),
        ),
      ];

      final stats = ActivityStats.fromNotes(items, now: now, weeks: 4);
      expect(stats.cells.length, 28);
      expect(stats.weeks, 4);
      expect(stats.streak, greaterThan(0));
      expect(stats.activeDaysThisWeek, greaterThanOrEqualTo(2));
      expect(stats.activeToday, isTrue);
      expect(stats.weekActiveMask.length, 7);
      expect(stats.bestStreak, greaterThanOrEqualTo(stats.streak));
      expect(stats.activeDayCount, greaterThan(0));
      expect(stats.totalEvents, greaterThan(0));
    });

    test('dayEventCounts increments create and later update', () {
      final items = [
        note(
          id: '1',
          createdAt: DateTime(2026, 7, 10, 9),
          updatedAt: DateTime(2026, 7, 10, 9),
        ),
        note(
          id: '2',
          createdAt: DateTime(2026, 7, 10, 10),
          updatedAt: DateTime(2026, 7, 11, 10),
        ),
      ];

      final counts = dayEventCounts(items);
      expect(counts[DateTime(2026, 7, 10)], 2); // two creates
      expect(counts[DateTime(2026, 7, 11)], 1); // one update
    });

    test('empty stats has zero streak and empty cells', () {
      final stats = ActivityStats.empty(
        weeks: 3,
        now: DateTime(2026, 7, 16),
      );
      expect(stats.streak, 0);
      expect(stats.bestStreak, 0);
      expect(stats.activeDaysThisWeek, 0);
      expect(stats.activeDayCount, 0);
      expect(stats.totalEvents, 0);
      expect(stats.activeToday, isFalse);
      expect(stats.weekActiveMask, everyElement(isFalse));
      expect(stats.cells, everyElement(0));
      expect(stats.cells.length, 21);
      expect(stats.rangeStart, DateTime(2026, 6, 29));
    });

    test('activeToday is false when today has no activity', () {
      final now = DateTime(2026, 7, 16, 15);
      final items = [
        note(id: '1', createdAt: DateTime(2026, 7, 15, 10)),
      ];
      final stats = ActivityStats.fromNotes(items, now: now, weeks: 2);
      expect(stats.activeToday, isFalse);
      expect(stats.streak, 1);
    });
  });

  group('archived and completedAt', () {
    test('archived items are excluded from metrics', () {
      final items = [
        note(id: '1', createdAt: DateTime(2026, 7, 16, 10)),
        NoteItem(
          id: '2',
          type: NoteType.task,
          title: 'Archived',
          body: '',
          pinned: false,
          completed: false,
          createdAt: DateTime(2026, 7, 16, 11),
          updatedAt: DateTime(2026, 7, 16, 11),
          archivedAt: DateTime(2026, 7, 16, 12),
        ),
      ];
      final days = activeDaysFrom(items);
      expect(days, {DateTime(2026, 7, 16)});
      // Only the non-archived create event.
      expect(dayEventCounts(items)[DateTime(2026, 7, 16)], 1);
    });

    test('completedAt counts as activity day', () {
      final items = [
        NoteItem(
          id: '1',
          type: NoteType.task,
          title: 'Task',
          body: '',
          pinned: false,
          completed: true,
          createdAt: DateTime(2026, 7, 14, 10),
          updatedAt: DateTime(2026, 7, 16, 10),
          completedAt: DateTime(2026, 7, 15, 18),
        ),
      ];
      final days = activeDaysFrom(items);
      expect(days, {
        DateTime(2026, 7, 14),
        DateTime(2026, 7, 15),
        DateTime(2026, 7, 16),
      });
    });
  });

  group('contentCounts', () {
    test('counts notes, tasks and pending tasks', () {
      final items = [
        note(id: '1', createdAt: DateTime(2026, 7, 10)),
        NoteItem(
          id: '2',
          type: NoteType.task,
          title: 'Task',
          body: '',
          pinned: false,
          completed: true,
          createdAt: DateTime(2026, 7, 11),
          updatedAt: DateTime(2026, 7, 11),
        ),
        NoteItem(
          id: '3',
          type: NoteType.task,
          title: 'Task 2',
          body: '',
          pinned: false,
          completed: false,
          createdAt: DateTime(2026, 7, 12),
          updatedAt: DateTime(2026, 7, 12),
        ),
      ];

      final counts = contentCounts(items);
      expect(counts.notes, 1);
      expect(counts.tasks, 2);
      expect(counts.pendingTasks, 1);
    });
  });

  group('ActivityHeatmap', () {
    test('empty cells use solid neutral contrast', () {
      expect(
        ActivityHeatmap.colorForCount(0, const ColorScheme.light()),
        AppColors.neutral20,
      );
    });

    test('weeksForMinCell prefers 26 then 18 then smaller', () {
      expect(
        HeatmapLayout.weeksForMinCell(width: 900, gap: 3, minCell: 10),
        26,
      );
      expect(
        HeatmapLayout.weeksForMinCell(width: 320, gap: 3, minCell: 10),
        lessThanOrEqualTo(18),
      );
      final narrow = HeatmapLayout.weeksForMinCell(
        width: 180,
        gap: 3,
        minCell: 10,
      );
      expect(narrow, greaterThanOrEqualTo(1));
      expect(narrow, lessThan(18));
      final layout = HeatmapLayout.forConstraints(
        width: 180,
        weeks: narrow,
        gap: 3,
      );
      expect(layout!.cellSize, greaterThanOrEqualTo(10));
    });
  });

  group('ActivityStrip', () {
    testWidgets('renders empty streak without crashing', (tester) async {
      final stats = ActivityStats.empty(now: DateTime(2026, 7, 16));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 390,
              child: ActivityStrip(stats: stats),
            ),
          ),
        ),
      );

      expect(find.text('0 días'), findsOneWidget);
      expect(find.textContaining('esta semana'), findsOneWidget);
      expect(find.text('L'), findsOneWidget);
      expect(find.text('X'), findsOneWidget);
      expect(find.text('V'), findsOneWidget);
      expect(find.text('Jul'), findsWidgets);
    });

    test('heightForWidth scales with width and keeps square cells', () {
      const weeks = 26;
      final narrow = ActivityStrip.heightForWidth(width: 320, weeks: weeks);
      final wide = ActivityStrip.heightForWidth(width: 420, weeks: weeks);
      expect(wide, greaterThan(narrow));
      expect(narrow, greaterThan(80));
    });
  });
}
