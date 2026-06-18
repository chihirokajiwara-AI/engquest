// test/smoke/preview_routes_offline_test.dart
//
// STRUCTURAL GUARD for the blank-grey-screen defect class (task #24).
//
// On the demo/offline build, Firebase fails to initialize (placeholder keys),
// so FirebaseFirestore.instance / FirebaseAuth.instance THROW. Four core
// screens (battle, worldmap, achievements, parent) constructed Firebase-backed
// services in their State field initializers, so they crashed to a blank grey
// page at mount — before any guard could run. The fix made every .instance
// access lazy + guarded.
//
// This test reproduces the exact offline condition: it pumps EVERY ?preview=
// route WITHOUT initializing Firebase (so .instance throws, same as the demo)
// and fails if the first frame throws. It exists so this whole defect class
// can never regress silently again — a new screen that touches Firebase at
// construction will turn this test red.
//
// Scope note: a single pump() checks the SYNCHRONOUS construction/build crash
// (the blank-grey cause). We do NOT pumpAndSettle — async audio/TTS/network
// plugins are absent in the test VM and would add unrelated noise; the crash
// we guard against is synchronous at mount.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    // Some screens read SharedPreferences in initState; provide an empty store.
    SharedPreferences.setMockInitialValues({});
    // Never hit the network for fonts in tests (deterministic, offline).
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // NOTE: Firebase is deliberately NOT initialized here — that is the whole
  // point. .instance must throw, mirroring the demo/offline build.

  for (final name in kPreviewRouteNames) {
    testWidgets('preview "$name" renders offline without crashing',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(home: previewWidgetForTest(name)),
      );
      // First frame: this is where a Firebase-at-construction crash blanks
      // the screen.
      await tester.pump();
      final exception = tester.takeException();

      // Tear down: dispose the screen (cancels cancellable timers / disposes
      // AnimationControllers), then advance the fake clock to elapse any
      // orphaned one-shot Future.delayed timers (e.g. staggered card
      // entrances) so they don't trip the pending-timer teardown check — that
      // is unrelated to the crash class this test guards.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 3));

      expect(
        exception,
        isNull,
        reason: 'preview "$name" threw on its first frame with Firebase '
            'offline — this is the blank-grey-screen crash class (#24). A '
            'Firebase/Auth .instance access at construction time is the usual '
            'cause; make it lazy + guarded.',
      );
    });
  }

  // Security: the ?preview= harness must be DISABLED in any paid flavor, or a
  // live `?preview=exam3` URL would hand paid 英検 content out for free (the
  // preview routes hardcode paid grades with no isGradeFree check). Lock the
  // invariant so the guard can't be silently removed.
  group('previewNameForFlavor — paywall-bypass guard', () {
    test('paid flavor suppresses every preview name', () {
      for (final name in kPreviewRouteNames) {
        expect(previewNameForFlavor(name, paymentRequired: true), isNull,
            reason: '"$name" must not be honoured in a paid build');
      }
    });

    test('free flavor passes preview names through unchanged', () {
      expect(previewNameForFlavor('exam3', paymentRequired: false), 'exam3');
      expect(previewNameForFlavor(null, paymentRequired: false), isNull);
    });
  });
}
