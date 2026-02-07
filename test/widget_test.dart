import 'package:flutter_test/flutter_test.dart';

import 'package:lora_monitor/app.dart';

void main() {
  testWidgets('App renders HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const HeltecApp());

    expect(find.text('Heltec Master'), findsOneWidget);
    expect(find.text('Scan+Connect'), findsOneWidget);
    expect(find.text('Device'), findsOneWidget);
  });
}
