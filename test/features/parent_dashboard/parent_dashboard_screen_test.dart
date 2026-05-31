import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

void main() {
  group('ParentDashboardScreen', () {
    test('accepts optional childUid parameter', () {
      // Default constructor — same-device access (childUid resolved internally)
      const screen1 = ParentDashboardScreen();
      expect(screen1.childUid, isNull);

      // With childUid — cross-device parent access
      const screen2 = ParentDashboardScreen(childUid: 'abc123');
      expect(screen2.childUid, 'abc123');
    });
  });
}
