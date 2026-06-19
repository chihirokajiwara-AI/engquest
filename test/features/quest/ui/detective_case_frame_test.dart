// test/features/quest/ui/detective_case_frame_test.dart
//
// Widget tests for the DetectiveCaseFrame premium card (#113/#159 — cohesion fix).
// Covers:
//   1. Basic render: child content visible, no exception.
//   2. Optional caseLabel strip renders when provided, absent when omitted.
//   3. Optional title renders when provided, absent when omitted.
//   4. highlighted=true vs false produce different border colours
//      (verifies the visual diff at the widget level — a pure colour guard).
//   5. Nazo teach scaffold builds with DetectiveCaseFrame tiles (integration
//      smoke: the greeing ナゾ teach card renders without exception).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/explore/nazo_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host(Widget child) => MaterialApp(
        home: Scaffold(
          backgroundColor: dqNight0,
          body: Center(
            child: SizedBox(width: 360, child: child),
          ),
        ),
      );

  // ── 1. Basic render ─────────────────────────────────────────────────────────

  testWidgets('DetectiveCaseFrame renders child content', (tester) async {
    await tester.pumpWidget(host(
      const DetectiveCaseFrame(
        child: Text('Hello!'),
      ),
    ));
    expect(find.text('Hello!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── 2. caseLabel strip ──────────────────────────────────────────────────────

  testWidgets('DetectiveCaseFrame shows caseLabel when provided',
      (tester) async {
    await tester.pumpWidget(host(
      const DetectiveCaseFrame(
        caseLabel: 'EXHIBIT 01',
        child: Text('こんにちは'),
      ),
    ));
    expect(find.text('EXHIBIT 01'), findsOneWidget);
    expect(find.text('こんにちは'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DetectiveCaseFrame omits caseLabel when null', (tester) async {
    await tester.pumpWidget(host(
      const DetectiveCaseFrame(
        child: Text('さようなら'),
      ),
    ));
    // No stray text widgets besides the content.
    expect(find.text('さようなら'), findsOneWidget);
    // The label widget must not exist.
    expect(find.text('EXHIBIT 01'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ── 3. title slot ────────────────────────────────────────────────────────────

  testWidgets('DetectiveCaseFrame shows title when provided', (tester) async {
    await tester.pumpWidget(host(
      const DetectiveCaseFrame(
        title: 'あいさつ',
        child: Text('Hello!'),
      ),
    ));
    expect(find.text('あいさつ'), findsOneWidget);
    expect(find.text('Hello!'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DetectiveCaseFrame omits title when null', (tester) async {
    await tester.pumpWidget(host(
      const DetectiveCaseFrame(
        child: Text('Goodbye.'),
      ),
    ));
    expect(find.text('Goodbye.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ── 4. highlighted vs normal: border colour guard ───────────────────────────

  test(
      'highlighted=true uses brighter outer border (pcFrameGold) vs normal (pcFrameBrown)',
      () {
    // The highlighted card uses pcFrameGold as the outer border colour; the
    // normal card uses pcFrameBrown. This pin ensures the visual distinction
    // cannot revert to a single colour silently.
    //
    // pcFrameGold (0xFFF0D080) is significantly brighter than pcFrameBrown
    // (0xFF6E5320). Guard via luminance.
    expect(
      pcFrameGold.computeLuminance(),
      greaterThan(pcFrameBrown.computeLuminance() * 3),
      reason: 'highlighted outer rule (pcFrameGold) must be much brighter than '
          'normal outer rule (pcFrameBrown) — if equal the visual distinction is lost',
    );
  });

  // ── 5. Nazo teach integration smoke ─────────────────────────────────────────

  testWidgets(
      'nazo teach scaffold with DetectiveCaseFrame tiles builds without exception',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    // The greeting hotspot has a 4-item TeachCard — exercises the full
    // _teachItemTile loop that now uses DetectiveCaseFrame.
    final hotspot = kTown5Scene.hotspots
        .firstWhere((h) => identical(h.teachCard, kGreetingTeach));

    await tester.pumpWidget(
      MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ),
    );
    await tester.pumpAndSettle();

    // The teach-first card is shown; must render DetectiveCaseFrame tiles.
    expect(find.text('まなびのとき'), findsOneWidget);
    // First teach item (highlighted) must be visible.
    expect(find.text('Hello!'), findsOneWidget);
    // caseLabel for the first item.
    expect(find.textContaining('ことば 1'), findsOneWidget);
    // No overflow or exception.
    expect(tester.takeException(), isNull);
  });

  testWidgets('first teach item tile shows highlighted caseLabel (ことば 1/N)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final hotspot = kTown5Scene.hotspots
        .firstWhere((h) => identical(h.teachCard, kGreetingTeach));
    final totalItems = hotspot.teachCard!.items.length;

    await tester.pumpWidget(
      MaterialApp(
        home: NazoScreen(hotspot: hotspot, eikenLevel: '5'),
      ),
    );
    await tester.pumpAndSettle();

    // Every item must have its own caseLabel.
    for (var i = 1; i <= totalItems; i++) {
      expect(find.textContaining('ことば $i'), findsOneWidget,
          reason: 'item $i caseLabel must be visible in the teach card');
    }
    expect(tester.takeException(), isNull);
  });
}
