import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

void main() {
  group('ParentDashboardScreen', () {
    test('can be instantiated with default constructor', () {
      const screen = ParentDashboardScreen();
      expect(screen, isNotNull);
    });
  });
}
