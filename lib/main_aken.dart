// Entry point for the [Flavor.aken] commercial build ("A-KEN Quest").
//
// Run with:
//   flutter run  -t lib/main_aken.dart
//   flutter build web -t lib/main_aken.dart
//
// Stripe billing is stubbed — integrate the real SDK when ready.
import 'package:firebase_analytics/firebase_analytics.dart';
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
  // Set flavor BEFORE any widget code runs.
  FlavorConfig.setFlavor(Flavor.aken);

  WidgetsFlutterBinding.ensureInitialized();

  await PreferencesService.getInstance();
  await SoundService().loadPreferences();
  await AudioMute.loadVoicePreference();

  bool firebaseAvailable = false;
  try {
    await FirebaseConfig.initialize();
    firebaseAvailable = true;
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] Init skipped: $e');
  }

  // COPPA/child-safety + privacy-by-default (#120): all users are children, so
  // we never collect advertising IDs AND we collect NOTHING until a parent
  // consents. Analytics stays OFF until [analyticsConsentGranted] is true (set
  // only by the parental consent gate). Default = no consent = no collection.
  final analyticsConsent = (await PreferencesService.getInstance())
      .getBool(PrefKeys.analyticsConsentGranted);
  if (firebaseAvailable) {
    try {
      await FirebaseAnalytics.instance
          .setAnalyticsCollectionEnabled(analyticsConsent);
      await FirebaseAnalytics.instance.setConsent(
        adStorageConsentGranted: false,
        adPersonalizationSignalsConsentGranted: false,
        adUserDataConsentGranted: false,
        analyticsStorageConsentGranted: analyticsConsent,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Analytics] Child config error: $e');
    }
  }

  AnalyticsService.initialize(
    firebaseAvailable: firebaseAvailable,
    analyticsConsentGranted: analyticsConsent,
  );

  await NotificationService.instance.init(firebaseAvailable: firebaseAvailable);
  await NotificationService.instance.setupReminders();

  runApp(const EngQuestApp());
}
