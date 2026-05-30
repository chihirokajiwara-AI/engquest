// lib/core/firebase/firebase_options.dart
// ENG Quest — Per-platform Firebase configuration
//
// This file provides FirebaseOptions for web, iOS, and Android.
// Replace placeholder values with actual Firebase project credentials
// from the Firebase Console (https://console.firebase.google.com).
//
// For production:
//   1. Create a Firebase project (e.g. "engquest-mvp")
//   2. Register web, iOS, and Android apps
//   3. Copy the generated config values here
//   4. For Android: also place google-services.json in android/app/
//   5. For iOS: also place GoogleService-Info.plist in ios/Runner/

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Returns the correct [FirebaseOptions] for the current platform.
///
/// Throws [UnsupportedError] if the platform is not configured.
FirebaseOptions get currentPlatformFirebaseOptions {
  if (kIsWeb) {
    return webFirebaseOptions;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
      return androidFirebaseOptions;
    case TargetPlatform.iOS:
      return iosFirebaseOptions;
    default:
      throw UnsupportedError(
        'FirebaseOptions not configured for ${defaultTargetPlatform.name}. '
        'Only web, iOS, and Android are supported.',
      );
  }
}

/// Whether Firebase credentials are configured (not placeholder values).
///
/// Returns false when using placeholder API keys, so the app can
/// gracefully skip Firebase initialization during development.
bool get isFirebaseConfigured {
  try {
    final opts = currentPlatformFirebaseOptions;
    return !opts.apiKey.startsWith('REPLACE_');
  } catch (_) {
    return false;
  }
}

// ---------------------------------------------------------------------------
// Web
// ---------------------------------------------------------------------------
const FirebaseOptions webFirebaseOptions = FirebaseOptions(
  apiKey: 'REPLACE_WITH_WEB_API_KEY',
  appId: 'REPLACE_WITH_WEB_APP_ID',
  messagingSenderId: 'REPLACE_WITH_SENDER_ID',
  projectId: 'engquest-mvp',
  authDomain: 'engquest-mvp.firebaseapp.com',
  storageBucket: 'engquest-mvp.appspot.com',
);

// ---------------------------------------------------------------------------
// Android
// ---------------------------------------------------------------------------
const FirebaseOptions androidFirebaseOptions = FirebaseOptions(
  apiKey: 'REPLACE_WITH_ANDROID_API_KEY',
  appId: 'REPLACE_WITH_ANDROID_APP_ID',
  messagingSenderId: 'REPLACE_WITH_SENDER_ID',
  projectId: 'engquest-mvp',
  storageBucket: 'engquest-mvp.appspot.com',
);

// ---------------------------------------------------------------------------
// iOS
// ---------------------------------------------------------------------------
const FirebaseOptions iosFirebaseOptions = FirebaseOptions(
  apiKey: 'REPLACE_WITH_IOS_API_KEY',
  appId: 'REPLACE_WITH_IOS_APP_ID',
  messagingSenderId: 'REPLACE_WITH_SENDER_ID',
  projectId: 'engquest-mvp',
  storageBucket: 'engquest-mvp.appspot.com',
  iosBundleId: 'com.edilab.engquest',
);
