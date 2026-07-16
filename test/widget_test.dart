import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/app/app.dart';

void main() {
  testWidgets('App loads home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const TodosApp());

    expect(find.text('Todos'), findsOneWidget);
    expect(find.text('Headline'), findsOneWidget);
  });
}
