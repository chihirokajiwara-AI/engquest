// test/app/refresh_restores_home_test.dart
// #53 (CEO P0) — a web refresh restarts the Dart app and resets the in-memory
// `_started` flag, which previously bounced an already-onboarded child back to
// the title screen on every refresh — losing their place. The fix boots
// a returning (onboarded) player straight to the home hub, while a brand-new
// player still meets the 本格 title first.
//
// These tests pin that boot-routing decision. We pump fixed durations (NOT
// pumpAndSettle — the home runs post-frame async that would never settle) and
// only assert on the title command's presence/absence, which is decided
// synchronously by _buildPhase once prefs resolve.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/app.dart';
import 'package:engquest/core/storage/preferences_service.dart';

// The text rendered inside the primary case-file entry tile on the title screen.
// Updated for detective reskin: new JP line is rendered in its own Text widget.
const _titleStart = '捜査（そうさ）を はじめる';

Future<void> _boot(WidgetTester tester) async {
  // A generous portrait-ish surface so the home hub lays out without a
  // test-only RenderFlex overflow (not what this test guards).
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const EngQuestApp());
  await tester.pump(); // resolve _loadPrefs (mock prefs complete synchronously)
  await tester.pump(const Duration(milliseconds: 50));
  await tester
      .pump(const Duration(milliseconds: 600)); // AnimatedSwitcher (450ms)
}

// Tolerate ONLY a layout overflow from the home hub at the test surface; any
// other exception (a real crash) must still fail the test. The home's
// render-without-crash contract is separately guarded by the offline preview
// smoke test.
void _drainOverflowOnly(WidgetTester tester) {
  Object? ex;
  while ((ex = tester.takeException()) != null) {
    if (!ex.toString().toLowerCase().contains('overflow')) {
      fail('unexpected exception booting to home: $ex');
    }
  }
}

Future<void> _drain(WidgetTester tester) async {
  // Unmount and let any post-frame home async drain so no timer is pending at
  // teardown (mirrors the offline preview smoke test).
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 3));
}

void main() {
  // The PreferencesService singleton (and OnboardingStorage's cached handle)
  // would otherwise leak the first test's prefs into the second; reset it so
  // each test boots against its own setMockInitialValues.
  setUp(PreferencesService.resetInstance);

  testWidgets('first-run player meets the title screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _boot(tester);
    expect(find.text(_titleStart), findsOneWidget,
        reason: 'a brand-new user should see the 本格 title first');
  });

  testWidgets(
      'NEW player meets the opening STORY before the onboarding form '
      '(CEO 1363 — hook before configure)', (tester) async {
    // The order must be title → STORY → form → home, NOT the old title → age/
    // level/avatar FORM → story (a dry config gate before the game was ever
    // established — the Day-1 anti-pattern the CEO flagged).
    SharedPreferences.setMockInitialValues({});
    await _boot(tester);
    expect(find.text(_titleStart), findsOneWidget);
    await tester.tap(find.text(_titleStart));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600)); // AnimatedSwitcher
    expect(find.byKey(const ValueKey('phase-prologue')), findsOneWidget,
        reason: 'the opening story must precede the onboarding form');
    expect(find.byKey(const ValueKey('phase-onboarding')), findsNothing,
        reason: 'the dry config form must NOT gate the story');
    await _drain(tester);
    _drainOverflowOnly(tester);
  });

  testWidgets('returning onboarded player skips the title on refresh (#53)',
      (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'prologue_seen': true,
    });
    await _boot(tester);
    _drainOverflowOnly(tester);
    expect(find.text(_titleStart), findsNothing,
        reason: 'a returning onboarded player must NOT be bounced to the title '
            'on web refresh (#53) — they boot back into the home hub');
    await _drain(tester);
    _drainOverflowOnly(tester);
  });

  testWidgets(
      'onboarded-but-prologue-unseen player still meets the title first '
      '(CEO 2233 — no いきなり cold-open without the title)', (tester) async {
    // Edge: onboarding_complete persisted from an earlier session, but
    // prologue_seen is false (e.g. the prologue gate shipped/was reset AFTER the
    // user onboarded). They are pre-story → must meet the 本格 title, NOT be
    // dropped straight onto the cold-open prologue. This is the「いきなりこの画面から
    // 始まる」path: booting to the title is the fix.
    SharedPreferences.setMockInitialValues({
      'onboarding_complete': true,
      'prologue_seen': false,
    });
    await _boot(tester);
    _drainOverflowOnly(tester);
    expect(find.text(_titleStart), findsOneWidget,
        reason: 'a prologue-unseen user is pre-story → title first, not an '
            'abrupt cold-open (CEO 2233)');
    await _drain(tester);
    _drainOverflowOnly(tester);
  });
}
