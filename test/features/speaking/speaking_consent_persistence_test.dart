// test/features/speaking/speaking_consent_persistence_test.dart
//
// #65 — Consent persistence + audit trail unit tests.
//
// Validates three properties required for COPPA-2026 compliance:
//   (A) First run: stored keys are absent → consent prompt is shown.
//   (B) Stored consent (same policy version): prompt is skipped and the
//       timestamp + version keys are written to SharedPreferences.
//   (C) Changed policy version: stored version no longer matches current →
//       prompt is shown again and fresh consent can be collected.
//
// These tests exercise the PreferencesService + PrefKeys layer directly
// (pure unit tests, no widget pump needed for the core logic), plus a
// widget-level check that _checkStoredConsent fires onConsent when the
// correct keys are pre-seeded in SharedPreferences.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/speaking/speaking_consent_notice.dart';

// ---------------------------------------------------------------------------
// Helper — build a fresh PreferencesService with optional seed data.
// ---------------------------------------------------------------------------
Future<PreferencesService> freshPrefs([
  Map<String, Object> seed = const {},
]) async {
  SharedPreferences.setMockInitialValues(seed);
  PreferencesService.resetInstance();
  return PreferencesService.getInstance();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── Pure storage layer tests ──────────────────────────────────────────────

  group('voice consent — PrefKeys constants', () {
    test('kVoiceConsentPolicyVersion is non-empty', () {
      expect(PrefKeys.kVoiceConsentPolicyVersion, isNotEmpty);
    });

    test('key strings are distinct', () {
      expect(PrefKeys.voiceConsentGrantedAt,
          isNot(equals(PrefKeys.voiceConsentPolicyVersion)));
    });
  });

  group('(A) first run — no stored consent', () {
    tearDown(() => PreferencesService.resetInstance());

    test('voiceConsentGrantedAt is null when never set', () async {
      final prefs = await freshPrefs();
      expect(prefs.getString(PrefKeys.voiceConsentGrantedAt), isNull);
    });

    test('voiceConsentPolicyVersion is null when never set', () async {
      final prefs = await freshPrefs();
      expect(prefs.getString(PrefKeys.voiceConsentPolicyVersion), isNull);
    });

    test('stored version absent → does NOT equal current policy version',
        () async {
      final prefs = await freshPrefs();
      final stored = prefs.getString(PrefKeys.voiceConsentPolicyVersion);
      expect(stored, isNot(equals(PrefKeys.kVoiceConsentPolicyVersion)));
    });
  });

  group('(B) grant consent — timestamp + version are persisted', () {
    tearDown(() => PreferencesService.resetInstance());

    test('after grant: voiceConsentGrantedAt is a non-empty ISO-8601 string',
        () async {
      final prefs = await freshPrefs();
      final before = DateTime.now().toUtc();

      // Simulate what _grantConsent does.
      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(PrefKeys.voiceConsentGrantedAt, now);
      await prefs.setString(PrefKeys.voiceConsentPolicyVersion,
          PrefKeys.kVoiceConsentPolicyVersion);

      final ts = prefs.getString(PrefKeys.voiceConsentGrantedAt);
      expect(ts, isNotNull);
      expect(ts, isNotEmpty);
      // Timestamp should be parseable and not in the future.
      final parsed = DateTime.parse(ts!);
      expect(
          parsed.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
    });

    test('after grant: voiceConsentPolicyVersion matches current', () async {
      final prefs = await freshPrefs();
      await prefs.setString(PrefKeys.voiceConsentPolicyVersion,
          PrefKeys.kVoiceConsentPolicyVersion);

      expect(prefs.getString(PrefKeys.voiceConsentPolicyVersion),
          equals(PrefKeys.kVoiceConsentPolicyVersion));
    });

    test('second-run check: both keys present + version matches → valid',
        () async {
      // Seed the store as if consent was already granted.
      final prefs = await freshPrefs({
        PrefKeys.voiceConsentGrantedAt: '2026-06-11T10:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: PrefKeys.kVoiceConsentPolicyVersion,
      });
      final stored = prefs.getString(PrefKeys.voiceConsentPolicyVersion);
      final ts = prefs.getString(PrefKeys.voiceConsentGrantedAt);
      expect(stored, equals(PrefKeys.kVoiceConsentPolicyVersion));
      expect(ts, isNotNull);
      // The guard logic: both conditions true → skip consent UI.
      final shouldSkip =
          stored == PrefKeys.kVoiceConsentPolicyVersion && ts != null;
      expect(shouldSkip, isTrue);
    });

    // Regression: a returning consented child must actually LAND on the screen
    // onConsent navigates to. The real call site (exam_practice_screen) wires
    // onConsent to Navigator.pushReplacement(SpeakingScreen). A stray
    // maybePop in _checkStoredConsent used to pop that freshly-pushed screen
    // straight back off — silently amputating Speaking for every returning user.
    testWidgets('stored consent → onConsent target survives (not bounced back)',
        (tester) async {
      await freshPrefs({
        PrefKeys.voiceConsentGrantedAt: '2026-06-11T10:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: PrefKeys.kVoiceConsentPolicyVersion,
      });
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => SpeakingConsentNotice(
            eikenGrade: '3',
            onConsent: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('SPEAKING_TARGET')),
              ),
            ),
          ),
        ),
      ));
      // _checkStoredConsent runs post-frame + awaits prefs, then onConsent.
      await tester.pumpAndSettle();
      expect(find.text('SPEAKING_TARGET'), findsOneWidget);
    });
  });

  group('(C) changed policy version — must re-prompt', () {
    tearDown(() => PreferencesService.resetInstance());

    test('stored version "v0-old" does NOT match current → re-prompt',
        () async {
      final prefs = await freshPrefs({
        PrefKeys.voiceConsentGrantedAt: '2025-01-01T00:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: 'v0-old',
      });
      final stored = prefs.getString(PrefKeys.voiceConsentPolicyVersion);
      final ts = prefs.getString(PrefKeys.voiceConsentGrantedAt);
      // Guard: version mismatch → show the consent UI.
      final shouldSkip =
          stored == PrefKeys.kVoiceConsentPolicyVersion && ts != null;
      expect(shouldSkip, isFalse);
    });

    test('ts present but version null → re-prompt', () async {
      final prefs = await freshPrefs({
        PrefKeys.voiceConsentGrantedAt: '2026-06-11T10:00:00.000Z',
      });
      final stored = prefs.getString(PrefKeys.voiceConsentPolicyVersion);
      final ts = prefs.getString(PrefKeys.voiceConsentGrantedAt);
      final shouldSkip =
          stored == PrefKeys.kVoiceConsentPolicyVersion && ts != null;
      expect(shouldSkip, isFalse);
    });
  });

  group('revoke — targeted key removal', () {
    tearDown(() => PreferencesService.resetInstance());

    test('removing both keys clears voice consent', () async {
      final prefs = await freshPrefs({
        PrefKeys.voiceConsentGrantedAt: '2026-06-11T10:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: PrefKeys.kVoiceConsentPolicyVersion,
      });
      // Simulate _revokeVoiceConsent.
      await prefs.remove(PrefKeys.voiceConsentGrantedAt);
      await prefs.remove(PrefKeys.voiceConsentPolicyVersion);

      expect(prefs.getString(PrefKeys.voiceConsentGrantedAt), isNull);
      expect(prefs.getString(PrefKeys.voiceConsentPolicyVersion), isNull);
    });

    test('other prefs survive a targeted revoke', () async {
      final prefs = await freshPrefs({
        PrefKeys.voiceConsentGrantedAt: '2026-06-11T10:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: PrefKeys.kVoiceConsentPolicyVersion,
        PrefKeys.uid: 'user-abc',
      });
      await prefs.remove(PrefKeys.voiceConsentGrantedAt);
      await prefs.remove(PrefKeys.voiceConsentPolicyVersion);

      // Non-consent data untouched.
      expect(prefs.getString(PrefKeys.uid), equals('user-abc'));
    });
  });

  // ── Widget-level: skip test via SpeakingConsentNotice ─────────────────────

  group('(B-widget) second run — SpeakingConsentNotice skips prompt', () {
    tearDown(() => PreferencesService.resetInstance());

    testWidgets(
        'pre-seeded valid consent → onConsent fires without user interaction',
        (tester) async {
      // Seed SharedPreferences with a valid stored consent.
      SharedPreferences.setMockInitialValues({
        PrefKeys.voiceConsentGrantedAt: '2026-06-11T10:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: PrefKeys.kVoiceConsentPolicyVersion,
      });
      PreferencesService.resetInstance();

      bool consented = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SpeakingConsentNotice(
            eikenGrade: '3',
            onConsent: () => consented = true,
          ),
        ),
      );

      // addPostFrameCallback fires after the first frame.
      await tester.pump();
      // Allow the async _checkStoredConsent to complete.
      await tester.pumpAndSettle();

      expect(consented, isTrue,
          reason: 'onConsent must fire when valid stored consent exists '
              'for the current policy version');
    });

    testWidgets('stale policy version → onConsent does NOT fire automatically',
        (tester) async {
      SharedPreferences.setMockInitialValues({
        PrefKeys.voiceConsentGrantedAt: '2025-01-01T00:00:00.000Z',
        PrefKeys.voiceConsentPolicyVersion: 'v0-old',
      });
      PreferencesService.resetInstance();

      bool consented = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SpeakingConsentNotice(
            eikenGrade: '3',
            onConsent: () => consented = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(consented, isFalse,
          reason: 'Stale policy version must not skip the consent prompt');
    });

    testWidgets('no stored consent → onConsent does NOT fire automatically',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.resetInstance();

      bool consented = false;

      await tester.pumpWidget(
        MaterialApp(
          home: SpeakingConsentNotice(
            eikenGrade: '3',
            onConsent: () => consented = true,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(consented, isFalse,
          reason: 'Absent stored consent must show the prompt, not skip it');
    });
  });

  // ── Parental gate — parallel key set ─────────────────────────────────────

  group('parental consent — PrefKeys constants', () {
    test('kParentalConsentPolicyVersion is non-empty', () {
      expect(PrefKeys.kParentalConsentPolicyVersion, isNotEmpty);
    });

    test('parental key strings are distinct from voice key strings', () {
      expect(PrefKeys.parentalConsentGrantedAt,
          isNot(equals(PrefKeys.voiceConsentGrantedAt)));
      expect(PrefKeys.parentalConsentPolicyVersion,
          isNot(equals(PrefKeys.voiceConsentPolicyVersion)));
    });
  });

  group('parental consent — storage round-trip', () {
    tearDown(() => PreferencesService.resetInstance());

    test('after grant: parentalConsentGrantedAt is a valid ISO-8601 string',
        () async {
      final prefs = await freshPrefs();
      final now = DateTime.now().toUtc().toIso8601String();
      await prefs.setString(PrefKeys.parentalConsentGrantedAt, now);
      await prefs.setString(PrefKeys.parentalConsentPolicyVersion,
          PrefKeys.kParentalConsentPolicyVersion);

      final ts = prefs.getString(PrefKeys.parentalConsentGrantedAt);
      expect(ts, isNotNull);
      expect(() => DateTime.parse(ts!), returnsNormally);
    });

    test('policy-version mismatch → re-prompt', () async {
      final prefs = await freshPrefs({
        PrefKeys.parentalConsentGrantedAt: '2025-01-01T00:00:00.000Z',
        PrefKeys.parentalConsentPolicyVersion: 'v0-old',
      });
      final stored = prefs.getString(PrefKeys.parentalConsentPolicyVersion);
      final ts = prefs.getString(PrefKeys.parentalConsentGrantedAt);
      final shouldSkip =
          stored == PrefKeys.kParentalConsentPolicyVersion && ts != null;
      expect(shouldSkip, isFalse);
    });
  });
}
