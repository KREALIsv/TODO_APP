import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/theme/theme.dart';
import 'package:todos_app/features/notes/presentation/widgets/activity_month_calendar.dart';

void main() {
  testWidgets('shows title, month navigation and weekday headers', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ActivityMonthCalendar(
              eventCounts: const {},
              now: DateTime(2026, 7, 28),
              selectedDay: DateTime(2026, 7, 28),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Calendario de actividad'), findsOneWidget);
    expect(find.text('Julio 2026'), findsOneWidget);
    expect(find.text('LUN'), findsOneWidget);
    expect(find.text('DOM'), findsOneWidget);
    expect(find.text('Menos'), findsOneWidget);
    expect(find.text('Más'), findsOneWidget);
    expect(find.text('28'), findsWidgets);
  });

  testWidgets('month chevrons change visible month', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 520));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ActivityMonthCalendar(
              eventCounts: const {},
              now: DateTime(2026, 7, 28),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Julio 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Mes siguiente'));
    await tester.pumpAndSettle();

    expect(find.text('Agosto 2026'), findsOneWidget);
    expect(find.text('Julio 2026'), findsNothing);
  });
}
