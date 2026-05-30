// test/widget_test.dart
// ENG Quest — Basic app smoke test.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/app.dart';

void main() {
  testWidgets('EngQuestApp renders without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const EngQuestApp());
    // The app should show a loading indicator or onboarding flow.
    // We just verify it doesn't throw during build.
    await tester.pump();
  });
}
