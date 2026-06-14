import 'package:flutter_test/flutter_test.dart';

import 'package:reading_pace_app/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const ReadingPaceApp());

    expect(find.text('Page Run'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Mileage'), findsOneWidget);
    expect(find.text('Record'), findsOneWidget);
  });
}
