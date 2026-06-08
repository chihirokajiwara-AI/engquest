// test/features/exam_practice/listening_screen_smoke_test.dart
// R3 smoke test: pump ListeningPracticeScreen and assert no render exception.
// R4: No Firebase, no network, no AudioCueService calls during build/initState.
//
// AudioCueService creates an AudioPlayer in initState, but audioplayers is
// test-safe (no native binary invoked on flutter_test host). All actual
// play() calls are user-gesture-gated and never invoked during pump().

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/listening_practice_screen.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/core/audio/audio_mute.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

ExamSection _listeningSection(String id, String nameJa, int q, int mins) =>
    ExamSection(
      id: id,
      nameJa: nameJa,
      nameEn: 'Listening',
      type: ExamSectionType.listening,
      questionCount: q,
      timeLimitMinutes: mins,
      description: 'Smoke test',
    );

Widget _wrap(Widget child) => MaterialApp(home: child);

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  group('ListeningPracticeScreen — muted guard', () {
    testWidgets('shows a "sound off" banner + unmute when Voice is muted',
        (tester) async {
      AudioMute.voiceMuted = true;
      addTearDown(() => AudioMute.voiceMuted = false);
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      // A listening exercise must not silently strand a muted child.
      expect(find.textContaining('おとが オフ'), findsOneWidget);
      expect(find.text('おんを オンにする'), findsOneWidget);
      // Tapping unmute clears the banner.
      await tester.tap(find.text('おんを オンにする'));
      await tester.pump();
      expect(AudioMute.voiceMuted, isFalse);
      expect(find.textContaining('おとが オフ'), findsNothing);
    });

    testWidgets('no banner when not muted', (tester) async {
      AudioMute.voiceMuted = false;
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      expect(find.textContaining('おとが オフ'), findsNothing);
    });
  });

  group('ListeningPracticeScreen — smoke tests (R3)', () {
    testWidgets('grade 5 — pumps without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 — shows part header on first load', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      // Part header for 第1部 should be visible before any interaction.
      expect(find.text('第1部'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 — part header Start button navigates to item', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      // Tap the はじめる button to dismiss the part header
      await tester.tap(find.textContaining('はじめる'));
      await tester.pump();
      // After dismissal, item view shows: 🔊 replay button + a question
      expect(find.text('🔊 もう いちど きく'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 — shows 🔊 replay button in item view', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      await tester.tap(find.textContaining('はじめる'));
      await tester.pump();
      expect(find.text('🔊 もう いちど きく'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 — shows progress counter after part header', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      await tester.tap(find.textContaining('はじめる'));
      await tester.pump();
      // Progress shows e.g. "1 / 12"
      expect(find.textContaining('/'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 — answer tap reveals つぎへ button', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      // Dismiss part header
      await tester.tap(find.textContaining('はじめる'));
      await tester.pump();
      // Tap the first choice option
      final choiceFinder = find.textContaining('1.  ').first;
      await tester.tap(choiceFinder);
      await tester.pump();
      // Next button should now be visible
      expect(find.textContaining('つぎへ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 5 — answering reveals the スクリプト transcript (#4)',
        (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      await tester.tap(find.textContaining('はじめる'));
      await tester.pump();
      // Before answering there is no transcript (it is a post-answer reveal).
      expect(find.byKey(const ValueKey('listening_transcript')), findsNothing);
      // Answer → the スクリプト of what was said must appear so a child who
      // misheard can read it (the listening learning loop).
      await tester.tap(find.textContaining('1.  ').first);
      await tester.pump();
      expect(
          find.byKey(const ValueKey('listening_transcript')), findsOneWidget);
      expect(find.text('スクリプト / Script'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 4 — pumps without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '4',
          section: _listeningSection('4_l', 'リスニング 4級', 30, 30),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 3 — pumps without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '3',
          section: _listeningSection('3_l', 'リスニング 3級', 30, 25),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre2 — pumps without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: 'pre2',
          section: _listeningSection('p2_l', 'リスニング 準2級', 30, 25),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade 2 — pumps without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '2',
          section: _listeningSection('2_l', 'リスニング 2級', 30, 25),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('grade pre1 — pumps without exception (#75)', (tester) async {
      // 準1 listening was unreachable before #75 (no section in the exam config).
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: 'pre1',
          section: _listeningSection('p1_l', 'リスニング 準1級', 29, 30),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('unknown grade — shows empty state without exception', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: 'unknown',
          section: _listeningSection('x_l', 'リスニング', 30, 30),
        ),
      ));
      await tester.pump();
      // A grade with no seed items → empty state. (All real grades 5..pre1 are
      // now seeded; 'unknown' exercises the fallback.)
      expect(find.textContaining('準備中'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('back arrow present in header', (tester) async {
      await tester.pumpWidget(_wrap(
        ListeningPracticeScreen(
          eikenGrade: '5',
          section: _listeningSection('5_l', 'リスニング 5級', 25, 20),
        ),
      ));
      await tester.pump();
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // ── Data integrity tests ────────────────────────────────────────────────────

  group('ListeningItem data integrity (R1)', () {
    test('all items have exactly 4 choices', () {
      for (final entry in kListeningItems.entries) {
        for (final item in entry.value) {
          expect(
            item.choices.length,
            equals(4),
            reason: '${entry.key} ${item.audioKey} must have exactly 4 choices',
          );
        }
      }
    });

    test('all items have a valid correctIndex (0–3)', () {
      for (final entry in kListeningItems.entries) {
        for (final item in entry.value) {
          expect(
            item.correctIndex,
            inInclusiveRange(0, 3),
            reason: '${entry.key} ${item.audioKey} correctIndex out of range',
          );
        }
      }
    });

    test('no duplicate choices within any item', () {
      for (final entry in kListeningItems.entries) {
        for (final item in entry.value) {
          final unique = item.choices.toSet();
          expect(
            unique.length,
            equals(item.choices.length),
            reason: '${entry.key} ${item.audioKey} has duplicate choices',
          );
        }
      }
    });

    test('no mixed-language options (R1 — all English)', () {
      // Japanese character range detection
      final japaneseRe = RegExp(r'[぀-ヿ一-鿿]');
      for (final entry in kListeningItems.entries) {
        for (final item in entry.value) {
          for (final choice in item.choices) {
            expect(
              japaneseRe.hasMatch(choice),
              isFalse,
              reason:
                  '${entry.key} ${item.audioKey} choice "$choice" contains Japanese characters',
            );
          }
        }
      }
    });

    test('all items have at least one transcript line', () {
      for (final entry in kListeningItems.entries) {
        for (final item in entry.value) {
          expect(
            item.transcripts.isNotEmpty,
            isTrue,
            reason: '${entry.key} ${item.audioKey} has no transcript',
          );
        }
      }
    });

    test('all items have non-empty audioKey', () {
      for (final entry in kListeningItems.entries) {
        for (final item in entry.value) {
          expect(
            item.audioKey.isNotEmpty,
            isTrue,
            reason: '${entry.key} item has empty audioKey',
          );
        }
      }
    });

    test('grades 5, 4 and pre1 have items in all 3 parts', () {
      for (final grade in ['5', '4', 'pre1']) {
        for (final part in [1, 2, 3]) {
          final items = listeningItemsFor(grade, part);
          expect(
            items.isNotEmpty,
            isTrue,
            reason: '英検$grade 級 第$part 部 has no items',
          );
        }
      }
    });

    test('grades pre2, pre2plus and 2 have items in parts 1 and 2', () {
      for (final grade in ['pre2', 'pre2plus', '2']) {
        for (final part in [1, 2]) {
          final items = listeningItemsFor(grade, part);
          expect(
            items.isNotEmpty,
            isTrue,
            reason: '英検$grade 第$part 部 has no items',
          );
        }
      }
    });

    test('grade 3 has items in all 3 parts', () {
      for (final part in [1, 2, 3]) {
        final items = listeningItemsFor('3', part);
        expect(
          items.isNotEmpty,
          isTrue,
          reason: '英検3級 第$part 部 has no items',
        );
      }
    });
  });
}
