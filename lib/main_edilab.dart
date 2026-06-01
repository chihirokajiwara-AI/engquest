// Entry point for the [Flavor.edilab] build.
//
// Run with:
//   flutter run  -t lib/main_edilab.dart
//   flutter build web -t lib/main_edilab.dart
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:engquest/core/analytics/analytics_service.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/core/firebase/firebase_config.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/app.dart';

void main() async {
  // Set flavor BEFORE any widget code runs.
  FlavorConfig.setFlavor(Flavor.edilab);

  WidgetsFlutterBinding.ensureInitialized();

  await PreferencesService.getInstance();

  bool firebaseAvailable = false;
  try {
    await FirebaseConfig.initialize();
    firebaseAvailable = true;
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] Init skipped: $e');
  }

  // COPPA/child-safety: disable AAID collection and ad-related analytics.
  // All users are children (ages 4-18); we never collect advertising IDs.
  if (firebaseAvailable) {
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(true);
      await FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        adUserDataConsentGranted: false,
        analyticsStorageConsentGranted: true,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] Child config error: $e');
    }
  }

  AnalyticsService.initialize(firebaseAvailable: firebaseAvailable);

  await NotificationService.instance.init(firebaseAvailable: firebaseAvailable);
  await NotificationService.instance.setupReminders();

  runApp(const EngQuestApp());
}
