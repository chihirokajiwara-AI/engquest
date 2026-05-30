// lib/core/firebase/firebase_config.dart
// ENG Quest — Firebase initialization
//
// Uses per-platform FirebaseOptions from firebase_options.dart.
// Gracefully skips initialization when placeholder keys are detected,
// allowing the app to run in offline/demo mode during development.

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'firebase_options.dart';

class FirebaseConfig {
  static bool _initialized = false;

  /// Whether Firebase was successfully initialized this session.
  static bool get isInitialized => _initialized;

  /// Initialize Firebase with platform-appropriate options.
  ///
  /// Throws if credentials are placeholder values, so callers should
  /// wrap in try/catch and fall back to offline mode.
  static Future<void> initialize() async {
    if (_initialized) return;

    if (!isFirebaseConfigured) {
      throw StateError(
        'Firebase credentials not configured. '
        'Replace placeholder values in firebase_options.dart '
        'with your Firebase project credentials.',
      );
    }

    await Firebase.initializeApp(
      options: currentPlatformFirebaseOptions,
    );

    _initialized = true;
    if (kDebugMode) {
      debugPrint('[FirebaseConfig] initialized for '
          '${kIsWeb ? "web" : defaultTargetPlatform.name}');
    }
  }
}
