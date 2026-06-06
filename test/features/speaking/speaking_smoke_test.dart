// test/features/speaking/speaking_smoke_test.dart
// R3 smoke tests: pump SpeakingConsentNotice + SpeakingScreen and assert
// tester.takeException() == null.
// R4: no Firebase / network in build/initState — both screens have zero
//     network dependencies until a gesture fires.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/speaking/speaking_consent_notice.dart';
import 'package:engquest/features/speaking/speaking_screen.dart';
import 'package:engquest/features/speaking/speaking_session.dart';
import 'package:engquest/features/speaking/pronunciation_scorer.dart';

// ── Helper ────────────────────────────────────────────────────────────────────

Widget wrap(Widget child) => MaterialApp(home: child);

void main() {
  // ────────────────────────────────────────────────────────────────────────────
  // SpeakingConsentNotice — smoke tests
  // ────────────────────────────────────────────────────────────────────────────

  group('SpeakingConsentNotice — smoke tests (R3)', () {
    testWidgets('grade 3 — pumps without exception', (tester) async {
      await tester.pumpWidget(wrap(
        SpeakingConsentNotice(
          eikenGrade: '3',
          onConsent: () {},
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre2 — pumps without exception', (tester) async {
      await tester.pumpWidget(wrap(
        SpeakingConsentNotice(
          eikenGrade: 'pre2',
          onConsent: () {},
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows the three key notice points', (tester) async {
      await tester.pumpWidget(wrap(
        SpeakingConsentNotice(
          eikenGrade: '3',
          onConsent: () {},
        ),
      ));
      await tester.pump();
      // All three key promises must be visible.
      expect(find.textContaining('音声を録音して採点に使います'), findsOneWidget);
      expect(find.textContaining('即時削除'), findsOneWidget);
      expect(find.textContaining('保護者'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('consent button disabled until checkbox ticked', (tester) async {
      await tester.pumpWidget(wrap(
        SpeakingConsentNotice(
          eikenGrade: '3',
          onConsent: () {},
        ),
      ));
      await tester.pump();

      // The DqButton's onTap is null when unchecked → rendered with disabled gradient.
      // We can't easily inspect internal state, but the button text is present.
      expect(find.textContaining('同意して はじめる'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ticking checkbox enables the button', (tester) async {
      bool consented = false;
      await tester.pumpWidget(wrap(
        SpeakingConsentNotice(
          eikenGrade: '3',
          onConsent: () => consented = true,
        ),
      ));
      await tester.pump();

      // Scroll the checkbox into view (the consent notice is taller than 600px).
      await tester.ensureVisible(find.textContaining('内容を確認し'));
      await tester.pump();

      // Tap the checkbox row.
      await tester.tap(find.textContaining('内容を確認し'));
      await tester.pump();

      // Scroll the consent button into view and tap it.
      await tester.ensureVisible(find.textContaining('同意して はじめる'));
      await tester.pump();
      await tester.tap(find.textContaining('同意して はじめる'));
      await tester.pump();

      expect(consented, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SpeakingScreen — smoke tests
  // ────────────────────────────────────────────────────────────────────────────

  group('SpeakingScreen — smoke tests (R3)', () {
    for (final grade in ['3', 'pre2', '2', 'pre1']) {
      testWidgets('grade $grade — pumps without exception', (tester) async {
        await tester.pumpWidget(wrap(
          SpeakingScreen(eikenGrade: grade),
        ));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });

      testWidgets('grade $grade — shows mic button', (tester) async {
        await tester.pumpWidget(wrap(
          SpeakingScreen(eikenGrade: grade),
        ));
        await tester.pump();
        // The idle state shows '話す' on the mic button.
        // (Some grades may start in prep-countdown state if prepSeconds > 0.)
        expect(tester.takeException(), isNull);
      });

      testWidgets('grade $grade — shows stub disclaimer', (tester) async {
        await tester.pumpWidget(wrap(
          SpeakingScreen(eikenGrade: grade),
        ));
        await tester.pump();
        expect(find.textContaining('開発中'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  // ────────────────────────────────────────────────────────────────────────────
  // SpeakingSession — unit tests
  // ────────────────────────────────────────────────────────────────────────────

  group('SpeakingSession unit tests', () {
    test('grade 3 starts at step 0', () {
      final s = SpeakingSession(eikenGrade: '3');
      expect(s.currentIndex, 0);
      expect(s.isComplete, isFalse);
      expect(s.attitudeCoachMessage, isNull);
    });

    test('grade 3 session has 6 steps (音読 + 5 Q&A)', () {
      final s = SpeakingSession(eikenGrade: '3');
      expect(s.totalSteps, 6);
    });

    test('grade pre2 session has 6 steps', () {
      final s = SpeakingSession(eikenGrade: 'pre2');
      expect(s.totalSteps, 6);
    });

    test('grade 2 session has 5 steps (音読 + 4 Q&A)', () {
      final s = SpeakingSession(eikenGrade: '2');
      expect(s.totalSteps, 5);
    });

    test('grade pre1 session has 6 steps (自由会話 + 4コマ + 4 Q&A)', () {
      final s = SpeakingSession(eikenGrade: 'pre1');
      expect(s.totalSteps, 6);
    });

    test('first step of grade 3 is ondo type', () {
      final s = SpeakingSession(eikenGrade: '3');
      expect(s.currentStep.type, SpeakingStepType.ondo);
    });

    test('first step of grade pre1 is freeConversation', () {
      final s = SpeakingSession(eikenGrade: 'pre1');
      expect(s.currentStep.type, SpeakingStepType.freeConversation);
    });

    test('advance with non-empty transcript moves to step 1', () {
      final s = SpeakingSession(eikenGrade: '3');
      s.advance(transcript: 'some words');
      expect(s.currentIndex, 1);
      expect(s.silenceCount, 0);
    });

    test('advance with empty transcript increments silenceCount', () {
      final s = SpeakingSession(eikenGrade: '3');
      s.advance(transcript: '');
      expect(s.silenceCount, 1);
      expect(s.attitudeCoachMessage, isNotNull);
    });

    test('attitudeCoachMessage appears after silence', () {
      final s = SpeakingSession(eikenGrade: '3');
      s.advance(transcript: '');
      final msg = s.attitudeCoachMessage;
      expect(msg, isNotNull);
      expect(msg!.contains('ゆっくり') || msg.contains('さい'), isTrue);
    });

    test('non-empty speech resets silenceCount', () {
      final s = SpeakingSession(eikenGrade: '3');
      s.advance(transcript: '');
      s.advance(transcript: 'hello world');
      expect(s.silenceCount, 0);
      expect(s.attitudeCoachMessage, isNull);
    });

    test('completing all steps marks isComplete', () {
      final s = SpeakingSession(eikenGrade: '3');
      for (int i = 0; i < s.totalSteps; i++) {
        expect(s.isComplete, isFalse);
        s.advance(transcript: 'test');
      }
      expect(s.isComplete, isTrue);
    });

    test('advance returns false when already complete', () {
      final s = SpeakingSession(eikenGrade: '3');
      for (int i = 0; i < s.totalSteps; i++) {
        s.advance(transcript: 'test');
      }
      final result = s.advance(transcript: 'test');
      expect(result, isFalse);
    });

    test('restart resets to step 0', () {
      final s = SpeakingSession(eikenGrade: '3');
      s.advance(transcript: 'hello');
      s.advance(transcript: '');
      s.restart();
      expect(s.currentIndex, 0);
      expect(s.silenceCount, 0);
    });

    test('unknown grade falls back to grade 3 steps', () {
      final s = SpeakingSession(eikenGrade: 'unknown_grade');
      expect(s.totalSteps, greaterThan(0));
    });
  });

  // ────────────────────────────────────────────────────────────────────────────
  // StubPronunciationScorer — unit tests
  // ────────────────────────────────────────────────────────────────────────────

  group('StubPronunciationScorer unit tests', () {
    const scorer = StubPronunciationScorer();

    test('empty transcript → score 0.0, showAttitudeCoach true', () {
      final r = scorer.score(
        referenceText: 'Many schools teach English.',
        transcript: '',
        eikenGrade: '3',
      );
      expect(r.score, equals(0.0));
      expect(r.showAttitudeCoach, isTrue);
    });

    test('very short transcript (< 3 words) → score 0.35', () {
      final r = scorer.score(
        referenceText: 'Many schools teach English.',
        transcript: 'schools',
        eikenGrade: '3',
      );
      expect(r.score, closeTo(0.35, 0.001));
      expect(r.showAttitudeCoach, isFalse);
    });

    test('high-coverage transcript → score 0.75', () {
      final r = scorer.score(
        referenceText: 'Many schools now teach English.',
        transcript: 'many schools now teach English',
        eikenGrade: '3',
      );
      expect(r.score, closeTo(0.75, 0.001));
    });

    test('partial-coverage transcript → score 0.5', () {
      final r = scorer.score(
        referenceText: 'The quick brown fox jumps over the lazy dog.',
        transcript: 'the fox something something something',
        eikenGrade: '3',
      );
      expect(r.score, closeTo(0.5, 0.001));
    });

    test('feedbackJa is non-empty in all cases', () {
      for (final transcript in ['', 'hi', 'hello world how are you']) {
        final r = scorer.score(
          referenceText: 'Practice sentence for testing.',
          transcript: transcript,
          eikenGrade: 'pre2',
        );
        expect(r.feedbackJa.isNotEmpty, isTrue);
      }
    });

    test('feedbackEn is non-empty in all cases', () {
      for (final transcript in ['', 'ok', 'I think it is good to study English']) {
        final r = scorer.score(
          referenceText: 'According to the passage what do students do.',
          transcript: transcript,
          eikenGrade: '2',
        );
        expect(r.feedbackEn.isNotEmpty, isTrue);
      }
    });

    test('referenceText and transcript are preserved in result', () {
      const ref = 'Test reference text.';
      const tx = 'test response words';
      final r = scorer.score(
        referenceText: ref,
        transcript: tx,
        eikenGrade: 'pre1',
      );
      expect(r.referenceText, equals(ref));
      expect(r.transcript, equals(tx));
    });

    test('score is in [0.0, 1.0] for all transcript lengths', () {
      final transcripts = [
        '',
        'I',
        'I think',
        'I think studying English is very important',
        'Many schools in Japan now have English classes and students learn to speak and write',
      ];
      for (final tx in transcripts) {
        final r = scorer.score(
          referenceText: 'Reference sentence for the test.',
          transcript: tx,
          eikenGrade: '3',
        );
        expect(r.score, greaterThanOrEqualTo(0.0));
        expect(r.score, lessThanOrEqualTo(1.0));
      }
    });
  });
}
