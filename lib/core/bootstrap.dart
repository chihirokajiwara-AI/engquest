// Shared app bootstrap for all entry points (main.dart, main_edilab.dart,
// main_aken.dart). Centralising the init sequence here removes the copy-paste
// drift between the three entrypoints — which had already caused a real bug:
// only main.dart called ReadabilityScale.load(), so the persisted text-size was
// NOT restored on launch in the SHIPPED edilab/aken builds (a WCAG 2.2 SC 1.4.4
// regression). One bootstrap = every flavor does identical, correct init.
//
// Web-safe: no dart:io. Firebase init is guarded; analytics stay OFF until a
// parent consents (COPPA / privacy-by-default).
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:engquest/core/analytics/analytics_service.dart';
import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/core/firebase/firebase_config.dart';
import 'package:engquest/core/notifications/notification_service.dart';
import 'package:engquest/core/sound/sound_service.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/core/ui/readability_scale.dart';
import 'package:engquest/app.dart';

/// Initialise the given [flavor] and run the app. Identical for every entry
/// point so flavor builds can never drift from the generic one again.
Future<void> bootstrapApp(Flavor flavor) async {
  // Flavor must be set BEFORE any widget code runs.
  FlavorConfig.setFlavor(flavor);

  WidgetsFlutterBinding.ensureInitialized();

  // A child must never see Flutter's default error box (a bare grey container in
  // release) if a widget throws during build. Show a calm, child-safe screen
  // instead. Release-only: debug keeps Flutter's detailed red error for devs.
  if (kReleaseMode) {
    ErrorWidget.builder = friendlyErrorWidget;
  }

  // 1. SharedPreferences — pre-warm so the first frame has data.
  await PreferencesService.getInstance();

  // 1b. Apply persisted audio mute settings before the first screen so a
  //     child's mute choice is honoured everywhere.
  await SoundService().loadPreferences();
  await AudioMute.loadVoicePreference();

  // 1c. Restore the persisted readability text-size before first paint (#114).
  //     Previously only main.dart did this — the shipped flavors silently reset
  //     the child's text-size every launch. Now every entry point restores it.
  await ReadabilityScale.load();

  // 2. Firebase initialization — skipped gracefully if placeholder keys.
  bool firebaseAvailable = false;
  try {
    await FirebaseConfig.initialize();
    firebaseAvailable = true;
  } catch (e) {
    if (kDebugMode) debugPrint('[Firebase] Init skipped: $e');
  }

  // 3. COPPA/child-safety + privacy-by-default (#120): all users are children,
  //    so we never collect advertising IDs AND collect NOTHING until a parent
  //    consents. Analytics stays OFF until [analyticsConsentGranted] is true
  //    (set only by the parental consent gate). Default = no consent.
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

  // 4. Analytics — wire Firebase Analytics or no-op fallback (consent-gated).
  AnalyticsService.initialize(
    firebaseAvailable: firebaseAvailable,
    analyticsConsentGranted: analyticsConsent,
  );

  // 5. Notifications (FCM + local scheduler) + the daily review reminder
  //    (opted-in by default, idempotent across launches, no-op if opted out).
  await NotificationService.instance.init(firebaseAvailable: firebaseAvailable);
  await NotificationService.instance.setupReminders();

  runApp(const EngQuestApp());
}
