import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:engquest/core/storage/preferences_service.dart';

// ---------------------------------------------------------------------------
// Background FCM handler (top-level, required by firebase_messaging)
// ---------------------------------------------------------------------------

/// Called when a FCM message arrives while the app is in the background.
/// Must be a top-level function (not a class method).
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // NOTE: Firebase.initializeApp() is NOT needed here — the plugin handles it.
  debugPrint('[FCM] Background message: ${message.messageId}');
}

// ---------------------------------------------------------------------------
// NotificationService
// ---------------------------------------------------------------------------

/// Manages push notifications (FCM) and local scheduled reminders.
///
/// Designed to degrade gracefully when Firebase is not yet configured
/// (placeholder API keys) — all calls become no-ops and log a warning.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  // Channel IDs
  static const _channelId = 'engquest_daily_review';
  static const _channelName = '毎日の復習リマインダー';
  static const _channelDesc = 'ENG Quest の毎日の学習リマインダーです。';
  static const _notificationId = 1001;

  // Default reminder: 19:00 JST
  static const TimeOfDay defaultReminderTime = TimeOfDay(hour: 19, minute: 0);

  // Reminder body text (matches spec)
  static const String _reminderBody = '今日の復習 5枚が待っています！⚔️';
  static const String _reminderTitle = 'ENG Quest';

  late final FlutterLocalNotificationsPlugin _localNotifications;
  bool _initialised = false;
  bool _firebaseAvailable = false;
  String? _fcmToken;

  // ── Public initialisation ─────────────────────────────────────────────────

  /// Initialise the service.  Call this once from [main] after
  /// [FirebaseConfig.initialize()] (or after the try/catch that skips it).
  ///
  /// [firebaseAvailable] should be `false` when Firebase is using placeholder
  /// keys so the service safely becomes a no-op for FCM calls.
  Future<void> init({bool firebaseAvailable = false}) async {
    _firebaseAvailable = firebaseAvailable;

    // Initialise timezone data for scheduled notifications.
    tz_data.initializeTimeZones();

    // Set up local notifications plugin.
    _localNotifications = FlutterLocalNotificationsPlugin();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false, // we request manually via requestPermission()
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel.
    await _createAndroidChannel();

    // Wire up FCM handlers (no-op if not available).
    if (_firebaseAvailable) {
      await _setupFcm();
    } else {
      debugPrint('[NotificationService] Firebase not configured — FCM disabled.');
    }

    _initialised = true;
  }

  // ── Permission ────────────────────────────────────────────────────────────

  /// Requests notification permission (required on iOS 14+, Android 13+).
  /// Returns true if granted.
  Future<bool> requestPermission() async {
    if (!_initialised) {
      debugPrint('[NotificationService] Not initialised — call init() first.');
      return false;
    }

    // iOS permission via FCM (covers both alert + badge + sound).
    if (_firebaseAvailable && (Platform.isIOS || Platform.isMacOS)) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      final granted = settings.authorizationStatus ==
              AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional;
      debugPrint('[NotificationService] iOS FCM permission: '
          '${settings.authorizationStatus}');
      return granted;
    }

    // Android 13+ permission (via local notifications plugin).
    if (Platform.isAndroid) {
      final android = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission() ?? false;
      debugPrint('[NotificationService] Android permission granted: $granted');
      return granted;
    }

    return true; // Other platforms: assume granted.
  }

  // ── FCM token ────────────────────────────────────────────────────────────

  /// Returns the FCM registration token for backend targeting.
  /// Returns null if Firebase is not configured or token fetch failed.
  Future<String?> getFcmToken() async {
    if (!_firebaseAvailable) return null;
    try {
      _fcmToken ??= await FirebaseMessaging.instance.getToken();
      return _fcmToken;
    } catch (e) {
      debugPrint('[NotificationService] FCM token fetch failed: $e');
      return null;
    }
  }

  // ── Reminder enable/disable preferences (P2.10) ───────────────────────────

  /// Whether daily review reminders are enabled (default: true / opted-in).
  ///
  /// Backed by [PrefKeys.remindersOptedOut] (stored inverted so a brand-new
  /// user with no stored value is opted **in** — retention-first default).
  Future<bool> remindersEnabled() async {
    final prefs = await PreferencesService.getInstance();
    return !prefs.getBool(PrefKeys.remindersOptedOut);
  }

  /// Persists the user's reminder on/off choice and (re)schedules or cancels
  /// the local notification accordingly. Call from a settings toggle.
  Future<void> setRemindersEnabled(bool enabled) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setBool(PrefKeys.remindersOptedOut, !enabled);
    if (enabled) {
      await scheduleDailyReminder(await _storedReminderTime());
    } else {
      await _localNotifications.cancel(_notificationId);
      debugPrint('[NotificationService] Daily reminder disabled by user.');
    }
  }

  /// Persists a custom reminder [time] and re-schedules if reminders are on.
  Future<void> setReminderTime(TimeOfDay time) async {
    final prefs = await PreferencesService.getInstance();
    await prefs.setInt(PrefKeys.reminderHour, time.hour);
    await prefs.setInt(PrefKeys.reminderMinute, time.minute);
    if (await remindersEnabled()) {
      await scheduleDailyReminder(time);
    }
  }

  /// Reads the stored reminder time, falling back to [defaultReminderTime].
  Future<TimeOfDay> _storedReminderTime() async {
    final prefs = await PreferencesService.getInstance();
    final hour = prefs.getInt(PrefKeys.reminderHour);
    final minute = prefs.getInt(PrefKeys.reminderMinute);
    // getInt returns 0 when unset; 0:00 is not a sensible reminder default,
    // so treat an unset hour as "use the default time".
    if (hour == 0 && minute == 0) return defaultReminderTime;
    return TimeOfDay(hour: hour, minute: minute);
  }

  /// One-shot startup orchestration: request permission (first run) and
  /// schedule the daily reminder if the user has not opted out.
  ///
  /// Safe to call on every app start — [scheduleDailyReminder] replaces any
  /// existing schedule so this is idempotent. No-ops if reminders are disabled.
  ///
  /// Returns `true` if a reminder is now scheduled.
  Future<bool> setupReminders() async {
    if (!_initialised) {
      debugPrint('[NotificationService] Not initialised — call init() first.');
      return false;
    }

    if (!await remindersEnabled()) {
      debugPrint('[NotificationService] Reminders opted out — skipping.');
      await _localNotifications.cancel(_notificationId);
      return false;
    }

    // Request permission (idempotent — OS only prompts once).
    final granted = await requestPermission();
    if (!granted) {
      debugPrint('[NotificationService] Permission denied — reminder not set.');
      return false;
    }

    await scheduleDailyReminder(await _storedReminderTime());
    return true;
  }

  // ── Scheduled daily reminder ──────────────────────────────────────────────

  /// Schedules (or re-schedules) the daily review reminder at [time].
  ///
  /// Defaults to [defaultReminderTime] (19:00 JST).  Calling this replaces
  /// any previously scheduled reminder with the same [_notificationId].
  Future<void> scheduleDailyReminder([
    TimeOfDay time = defaultReminderTime,
  ]) async {
    if (!_initialised) {
      debugPrint('[NotificationService] Not initialised — call init() first.');
      return;
    }

    // Cancel existing before re-scheduling.
    await _localNotifications.cancel(_notificationId);

    final scheduledTime = _nextInstanceOf(time);

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.zonedSchedule(
      _notificationId,
      _reminderTitle,
      _reminderBody,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // repeat daily
    );

    debugPrint('[NotificationService] Daily reminder scheduled at '
        '${time.hour.toString().padLeft(2, "0")}:'
        '${time.minute.toString().padLeft(2, "0")} JST '
        '(next: $scheduledTime)');
  }

  // ── Cancel ───────────────────────────────────────────────────────────────

  /// Cancels all scheduled local notifications (for settings screen).
  Future<void> cancelAll() async {
    if (!_initialised) return;
    await _localNotifications.cancelAll();
    debugPrint('[NotificationService] All notifications cancelled.');
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _setupFcm() async {
    // Register background handler.
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Foreground presentation on iOS.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground message handler.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      _showForegroundNotification(message);
    });

    // Opened-from-notification handler.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Message opened app: ${message.notification?.title}');
      // TODO: Navigate to review screen when app is opened via notification.
    });

    // Pre-fetch token.
    _fcmToken = await getFcmToken();
    debugPrint('[FCM] Token: $_fcmToken');
  }

  Future<void> _createAndroidChannel() async {
    final android = _localNotifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.high,
      ),
    );
  }

  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('[NotificationService] Tapped: ${response.payload}');
    // TODO: Navigate to daily review screen.
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? _reminderTitle,
      notification.body ?? _reminderBody,
      details,
    );
  }

  /// Returns the next [TZDateTime] that matches the given [TimeOfDay] in JST.
  tz.TZDateTime _nextInstanceOf(TimeOfDay time) {
    final jst = tz.getLocation('Asia/Tokyo');
    final now = tz.TZDateTime.now(jst);
    var scheduled = tz.TZDateTime(
      jst,
      now.year,
      now.month,
      now.day,
      time.hour,
      time.minute,
    );
    // If the time has already passed today, schedule for tomorrow.
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
