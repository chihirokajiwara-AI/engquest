// test/core/firebase/firebase_config_test.dart
// Tests for Firebase initialization logic.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/firebase/firebase_config.dart';

void main() {
  group('FirebaseConfig', () {
    test('isInitialized is false before initialization', () {
      expect(FirebaseConfig.isInitialized, isFalse);
    });

    test('initialize throws when credentials are placeholder', () async {
      // With placeholder keys, initialization should throw a StateError
      // so the app can fall back to offline mode gracefully.
      expect(
        () => FirebaseConfig.initialize(),
        throwsA(isA<StateError>()),
      );
    });

    test('isInitialized remains false after failed initialization', () {
      expect(FirebaseConfig.isInitialized, isFalse);
    });
  });
}
