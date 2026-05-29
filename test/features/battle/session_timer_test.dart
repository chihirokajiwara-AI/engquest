// test/features/battle/session_timer_test.dart
// Tests for the session timer logic (P0.1) in BattleScreen.
//
// BattleScreen.elapsedMinutes(start, end) computes real study time from the
// captured session-start timestamp. Rules:
//   - null start            → 1 (defensive fallback)
//   - non-positive duration → 1 (clock skew / instant complete)
//   - otherwise             → round to nearest minute, floor of 1
//
// This replaces the old hard-coded `minutes: 1` so the parent dashboard
// study-time analytics reflect real session length.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/battle/battle_screen.dart';

void main() {
  group('BattleScreen.elapsedMinutes', () {
    final start = DateTime(2026, 5, 29, 10, 0, 0);

    test('null start returns 1 (defensive fallback)', () {
      expect(BattleScreen.elapsedMinutes(null, start), 1);
    });

    test('zero duration returns 1 (floor)', () {
      expect(BattleScreen.elapsedMinutes(start, start), 1);
    });

    test('negative duration (clock skew) returns 1', () {
      final earlier = start.subtract(const Duration(seconds: 30));
      expect(BattleScreen.elapsedMinutes(start, earlier), 1);
    });

    test('29 seconds rounds down to floor of 1', () {
      final end = start.add(const Duration(seconds: 29));
      expect(BattleScreen.elapsedMinutes(start, end), 1);
    });

    test('exactly 1 minute returns 1', () {
      final end = start.add(const Duration(minutes: 1));
      expect(BattleScreen.elapsedMinutes(start, end), 1);
    });

    test('1 min 31 sec rounds up to 2', () {
      final end = start.add(const Duration(minutes: 1, seconds: 31));
      expect(BattleScreen.elapsedMinutes(start, end), 2);
    });

    test('1 min 29 sec rounds down to 1', () {
      final end = start.add(const Duration(minutes: 1, seconds: 29));
      expect(BattleScreen.elapsedMinutes(start, end), 1);
    });

    test('exactly 5 minutes returns 5', () {
      final end = start.add(const Duration(minutes: 5));
      expect(BattleScreen.elapsedMinutes(start, end), 5);
    });

    test('realistic 7 min 12 sec session returns 7', () {
      final end = start.add(const Duration(minutes: 7, seconds: 12));
      expect(BattleScreen.elapsedMinutes(start, end), 7);
    });

    test('realistic 12 min 45 sec session rounds to 13', () {
      final end = start.add(const Duration(minutes: 12, seconds: 45));
      expect(BattleScreen.elapsedMinutes(start, end), 13);
    });
  });
}
