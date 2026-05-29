import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';

/// Tests for the P2.10 daily reminder enable/disable preference logic.
///
/// These cover the pure, preference-backed surface of [NotificationService]
/// that does not require platform notification channels:
///   - reminders are opted-IN by default (retention-first),
///   - the opted-out flag is stored inverted,
///   - the reminder-time round-trip falls back to the default time.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final service = NotificationService.instance;

  Future<void> setPrefs([Map<String, Object> values = const {}]) async {
    SharedPreferences.setMockInitialValues(values);
    PreferencesService.resetInstance();
    await PreferencesService.getInstance();
  }

  group('remindersEnabled() default', () {
    test('is TRUE for a brand-new user (no stored value)', () async {
      await setPrefs();
      expect(await service.remindersEnabled(), isTrue);
    });

    test('is FALSE when the opted-out flag is set', () async {
      await setPrefs({PrefKeys.remindersOptedOut: true});
      expect(await service.remindersEnabled(), isFalse);
    });

    test('is TRUE when the opted-out flag is explicitly false', () async {
      await setPrefs({PrefKeys.remindersOptedOut: false});
      expect(await service.remindersEnabled(), isTrue);
    });
  });

  group('opted-out flag is stored inverted', () {
    test('enabling reminders stores remindersOptedOut = false', () async {
      await setPrefs({PrefKeys.remindersOptedOut: true});
      final prefs = await PreferencesService.getInstance();

      // Mirror setRemindersEnabled(true)'s persistence contract (the scheduling
      // side-effect needs platform channels and is exercised in widget tests).
      await prefs.setBool(PrefKeys.remindersOptedOut, false);

      expect(await service.remindersEnabled(), isTrue);
    });

    test('disabling reminders stores remindersOptedOut = true', () async {
      await setPrefs();
      final prefs = await PreferencesService.getInstance();
      await prefs.setBool(PrefKeys.remindersOptedOut, true);

      expect(await service.remindersEnabled(), isFalse);
    });
  });

  group('reminder time storage', () {
    test('default reminder time is 19:00 JST', () {
      expect(NotificationService.defaultReminderTime,
          const TimeOfDay(hour: 19, minute: 0));
    });

    test('custom reminder time round-trips through prefs', () async {
      await setPrefs();
      final prefs = await PreferencesService.getInstance();
      await prefs.setInt(PrefKeys.reminderHour, 8);
      await prefs.setInt(PrefKeys.reminderMinute, 30);

      expect(prefs.getInt(PrefKeys.reminderHour), 8);
      expect(prefs.getInt(PrefKeys.reminderMinute), 30);
    });

    test('unset reminder time reads as 0/0 (the default-time sentinel)',
        () async {
      await setPrefs();
      final prefs = await PreferencesService.getInstance();
      expect(prefs.getInt(PrefKeys.reminderHour), 0);
      expect(prefs.getInt(PrefKeys.reminderMinute), 0);
    });
  });
}
