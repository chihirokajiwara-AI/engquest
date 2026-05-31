import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:engquest/core/analytics/analytics_service.dart';
import 'package:engquest/core/firebase/firebase_config.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. SharedPreferences — pre-warm so the first frame has data.
  await PreferencesService.getInstance();

  // 2. Firebase initialization — skipped gracefully if placeholder keys.
  bool firebaseAvailable = false;
  try {
    await FirebaseConfig.initialize();
    firebaseAvailable = true;
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] Init skipped: $e');
  }

  // 3. Analytics — wire Firebase Analytics or no-op fallback.
  AnalyticsService.initialize(firebaseAvailable: firebaseAvailable);

  // 4. Notifications (FCM + local scheduler).
  await NotificationService.instance.init(firebaseAvailable: firebaseAvailable);

  // 4b. Schedule the daily review reminder (P2.10) — opted-in by default,
  //     idempotent across launches, no-op if the user has opted out.
  await NotificationService.instance.setupReminders();

  runApp(const EngQuestApp());
}
