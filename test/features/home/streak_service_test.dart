// test/features/home/streak_service_test.dart
// Unit tests for StreakService streak logic.
//
// Uses SharedPreferences.setMockInitialValues so PreferencesService resolves.
// Each test resets the singleton so they are fully isolated.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/home/streak_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
  });

  test('First session sets streak to 1', () async {
    final service = StreakService();
    final state = await service.recordStudySession();
    expect(state.currentStreak, 1);
    expect(state.todayCount, 1);
  });

  test('Two sessions on same day do not double-count streak', () async {
    final service = StreakService();
    await service.recordStudySession();
    final state = await service.recordStudySession();
    // Streak stays 1, but todayCount increments.
    expect(state.currentStreak, 1);
    expect(state.todayCount, 2);
  });

  test('StreakState.studiedOn returns false for unset bits', () {
    const state = StreakState(
      currentStreak: 1,
      weeklyBits: 0,
      todayCount: 0,
    );
    for (int i = 0; i < 7; i++) {
      expect(state.studiedOn(i), isFalse);
    }
  });

  test('StreakState.studiedOn returns true for set bits', () {
    // Bits 0 (Mon) and 4 (Fri) set.
    const bits = (1 << 0) | (1 << 4);
    const state = StreakState(
      currentStreak: 2,
      weeklyBits: bits,
      todayCount: 1,
    );
    expect(state.studiedOn(0), isTrue); // Monday
    expect(state.studiedOn(4), isTrue); // Friday
    expect(state.studiedOn(1), isFalse); // Tuesday
    expect(state.studiedOn(3), isFalse); // Thursday
  });

  test('load() returns zero state when no data stored', () async {
    final service = StreakService();
    final state = await service.load();
    expect(state.currentStreak, 0);
    expect(state.weeklyBits, 0);
    expect(state.todayCount, 0);
  });

  test('recordStudySession sets today weekday bit', () async {
    final service = StreakService();
    final state = await service.recordStudySession();
    final todayBit = DateTime.now().weekday - 1;
    expect(state.studiedOn(todayBit), isTrue);
  });

  test('load() returns previously recorded state', () async {
    final service = StreakService();
    await service.recordStudySession();
    // Create a fresh service instance (same prefs backing store).
    final service2 = StreakService();
    final state = await service2.load();
    expect(state.currentStreak, 1);
    expect(state.todayCount, 1);
  });
}
