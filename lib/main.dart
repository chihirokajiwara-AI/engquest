import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:engquest/core/analytics/analytics_service.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/core/firebase/firebase_config.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/core/sound/sound_service.dart';
import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/app.dart';

void main() async {
  // Default to edilab flavor when running the generic entry point.
  // Use lib/main_edilab.dart or lib/main_aken.dart for explicit flavor builds.
  FlavorConfig.setFlavor(Flavor.edilab);

  WidgetsFlutterBinding.ensureInitialized();

  // 1. SharedPreferences — pre-warm so the first frame has data.
  await PreferencesService.getInstance();

  // 1b. Apply persisted audio mute settings before the first screen (prologue,
  //     deep-links, Battle) so a child's mute choice is honoured everywhere.
  await SoundService().loadPreferences();
  await AudioMute.loadVoicePreference();

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
