import 'package:flutter/material.dart';
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
    debugPrint('[Firebase] Init skipped: $e');
  }

  // 3. Notifications (FCM + local scheduler).
  await NotificationService.instance.init(firebaseAvailable: firebaseAvailable);

  runApp(const EngQuestApp());
}
