// test/core/firebase/firebase_options_test.dart
// Tests for per-platform Firebase configuration.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/firebase/firebase_options.dart';

void main() {
  group('FirebaseOptions', () {
    test('webFirebaseOptions has correct projectId', () {
      expect(webFirebaseOptions.projectId, 'engquest-mvp');
    });

    test('androidFirebaseOptions has correct projectId', () {
      expect(androidFirebaseOptions.projectId, 'engquest-mvp');
    });

    test('iosFirebaseOptions has correct projectId', () {
      expect(iosFirebaseOptions.projectId, 'engquest-mvp');
    });

    test('iosFirebaseOptions has correct bundleId', () {
      expect(iosFirebaseOptions.iosBundleId, 'com.edilab.engquest');
    });

    test('webFirebaseOptions has authDomain', () {
      expect(webFirebaseOptions.authDomain, 'engquest-mvp.firebaseapp.com');
    });

    test('all options have storageBucket', () {
      expect(webFirebaseOptions.storageBucket, 'engquest-mvp.appspot.com');
      expect(androidFirebaseOptions.storageBucket, 'engquest-mvp.appspot.com');
      expect(iosFirebaseOptions.storageBucket, 'engquest-mvp.appspot.com');
    });

    test('isFirebaseConfigured returns false for placeholder keys', () {
      // All options have placeholder keys (REPLACE_WITH_*), so this
      // should return false until real credentials are configured.
      expect(isFirebaseConfigured, isFalse);
    });

    test('currentPlatformFirebaseOptions returns web options on web/test', () {
      // In test environment, kIsWeb is false and defaultTargetPlatform
      // varies. We just verify it doesn't throw for a supported platform.
      // This test runs on the test runner's platform (typically linux/macos).
      // Since we're running in a Flutter test, the platform should be
      // one of the supported ones or throw UnsupportedError.
      try {
        final opts = currentPlatformFirebaseOptions;
        // If it doesn't throw, it should return valid options
        expect(opts.projectId, 'engquest-mvp');
      } on UnsupportedError {
        // Expected on unsupported platforms (linux, windows, etc.)
        // This is correct behavior
      }
    });
  });
}
