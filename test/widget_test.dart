import 'package:flutter_test/flutter_test.dart';

import 'package:french_mobiles/main.dart';

void main() {
  testWidgets('Home screen loads with sell action', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Hello, Guest'), findsOneWidget);
    expect(find.text('Sell Phone'), findsOneWidget);
  });
}
