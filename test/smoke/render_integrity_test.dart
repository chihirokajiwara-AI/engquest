// test/smoke/render_integrity_test.dart
// #40 — render integrity: a data-backed screen must RESOLVE its loading state to
// real content, never sit on a perpetual spinner. The R3 smoke tests only pump
// one frame (so a never-resolving load passes as "the spinner frame"); this test
// advances past the async load and asserts no CircularProgressIndicator remains.
//
// This caught a real defect: the `battle` preview used the default
// FirestoreFsrsCardRepository, whose deck load never resolves without Firebase →
// a perpetual loading spinner offline. Fixed by injecting an in-memory repo in
// the preview (app.dart) + guarding getDueCards (battle_screen.dart).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/app.dart';

// Offline-renderable, data-backed screens that have a loading phase and MUST
// resolve to content (no Firebase, no network).
const _dataScreens = <String>[
  'kotobahome',
  'settings',
  'achievements',
  'questmap',
  'parentlogin',
  'battle',
  'parent', // parent dashboard — must show a graceful state offline, not a
  //           raw "Bad state: Firebase Auth unavailable" exception.
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  for (final name in _dataScreens) {
    testWidgets('"$name" resolves its loading state (no perpetual spinner)',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(home: previewWidgetForTest(name)));
      await tester.pump();
      // POLL until the loading state resolves. Each step advances BOTH real async
      // (runAsync — in-memory repo / asset futures) AND fake time (pump(Duration)
      // — internal Timer/Future.delayed in the load chain). A single fixed window
      // flaked (~40%) when a screen's load (e.g. battle's FSRS getDueCards) ran
      // long; polling breaks the instant the spinner clears and tolerates timing.
      for (var i = 0; i < 16; i++) {
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 200));
        });
        await tester.pump(const Duration(milliseconds: 200));
        if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
      }

      expect(
        find.byType(CircularProgressIndicator),
        findsNothing,
        reason: '"$name" is stuck on a loading spinner — its async load never '
            'resolved (a child would see an infinite spinner).',
      );

      // No raw exception string must leak to the user (paying parents must never
      // see "Bad state:" / "Exception:" — show a graceful state instead).
      for (final marker in const ['Bad state:', 'Exception:', 'Error: ']) {
        expect(find.textContaining(marker), findsNothing,
            reason: '"$name" leaked a raw exception ("$marker…") to the UI.');
      }

      // Drain post-frame timers so teardown is clean.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 2));
    });
  }
}
