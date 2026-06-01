import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../storage/preferences_service.dart';

// ---------------------------------------------------------------------------
// NotificationService — Web-safe stub
// ---------------------------------------------------------------------------
// Push notifications and local scheduled reminders are not supported on web.
// This file preserves the full public API surface as no-ops so that callers
// (main.dart, settings screens) compile without changes.
// On mobile builds, platform-specific notification support can be re-enabled
// via conditional imports in the future.
// ---------------------------------------------------------------------------

/// Called when a FCM message arrives while the app is in the background.
/// No-op on web.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(dynamic message) async {
  if (kDebugMode) debugPrint('[FCM] Background handler called (no-op on web)');
}

/// Manages push notifications (FCM) and local scheduled reminders.
///
/// On web, all methods are safe no-ops.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Default reminder: 19:00 JST
  static const TimeOfDay defaultReminderTime = TimeOfDay(hour: 19, minute: 0);

  /// Initialise the service. No-op on web.
  Future<void> init({bool firebaseAvailable = false}) async {
    if (kDebugMode) {
      debugPrint('[NotificationService] Web stub — notifications disabled.');
    }
  }

  /// Requests notification permission. Always returns false on web.
  Future<bool> requestPermission() async => false;

  /// Returns the FCM registration token. Always null on web.
  Future<String?> getFcmToken() async => null;

  /// Whether daily review reminders are enabled.
  ///
  /// Preference-backed (SharedPreferences is web-safe). The flag is stored
  /// inverted as [PrefKeys.remindersOptedOut], so a brand-new user with no
  /// stored value is opted-IN by default (retention-first). Only the
  /// scheduling side-effect needs platform channels; reading the preference
  /// works on every platform.
  Future<bool> remindersEnabled() async {
    final prefs = await PreferencesService.getInstance();
    return !prefs.getBool(PrefKeys.remindersOptedOut);
  }

  /// Persists the user's reminder on/off choice (stored inverted).
  ///
  /// The (re)scheduling side-effect requires platform notification channels
  /// and remains a no-op on web; the preference itself always persists.
  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setBool(PrefKeys.remindersOptedOut, !enabled);
  }

  /// Persists a custom reminder time. No-op on web.
  Future<void> setReminderTime(TimeOfDay time) async {}

  /// Setup reminders on app start. No-op on web.
  Future<bool> setupReminders() async => false;

  /// Schedules (or re-schedules) the daily review reminder. No-op on web.
  Future<void> scheduleDailyReminder([
    TimeOfDay time = defaultReminderTime,
  ]) async {}

  /// Cancels all scheduled local notifications. No-op on web.
  Future<void> cancelAll() async {}
}
