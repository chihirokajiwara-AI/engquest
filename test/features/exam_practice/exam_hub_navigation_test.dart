// test/features/exam_practice/exam_hub_navigation_test.dart
// #39 — interaction/navigation guard for the core 合格 surface (the exam hub).
//
// ExamPracticeScreen lists one tile per 大問 section + a 合格メーター button + a
// フル模試 button. A broken section→screen link (or a crash-on-open) would leave
// a paying child unable to practice that skill — and it's invisible to a
// render-only smoke test. This drives each tile and asserts the right practice
// screen opens without throwing.
//
// Data-driven from kEikenExams so adding a section to a grade is covered
// automatically. Fresh pump per section (no pop/stack juggling); one frame is
// enough to surface a crash-on-open or a wrong destination.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/exam_practice/vocab_grammar_practice_screen.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/reading_practice_screen.dart';
import 'package:engquest/features/exam_practice/writing_practice_screen.dart';
import 'package:engquest/features/exam_practice/listening_practice_screen.dart';
import 'package:engquest/features/speaking/speaking_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';

Type _screenTypeFor(ExamSectionType t) {
  switch (t) {
    case ExamSectionType.vocabGrammar:
      return VocabGrammarPracticeScreen;
    case ExamSectionType.wordOrdering:
      return WordOrderingPracticeScreen;
    case ExamSectionType.conversationComplete:
      return ConversationPracticeScreen;
    case ExamSectionType.readingComprehension:
      return ReadingPracticeScreen;
    case ExamSectionType.writing:
      return WritingPracticeScreen;
    case ExamSectionType.listening:
      return ListeningPracticeScreen;
    case ExamSectionType.speaking:
      return SpeakingScreen;
  }
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SkillAccuracyStore.resetInstance(); // deterministic empty store per test
  });

  const grade = '5';
  final sections = kEikenExams[grade]!.sections;

  // A tall surface so the ListView.builder materialises EVERY section tile
  // (off-screen tiles aren't built, which would hide a broken link).
  Future<void> pumpHub(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
        const MaterialApp(home: ExamPracticeScreen(eikenGrade: grade)));
    await tester.pump();
  }

  group('ExamPracticeScreen — every section tile navigates (#39)', () {
    testWidgets('hub renders a tile for every 大問 section', (tester) async {
      await pumpHub(tester);
      for (final s in sections) {
        expect(find.text(s.nameEn), findsWidgets,
            reason: 'missing hub tile for ${s.nameEn}');
      }
      expect(tester.takeException(), isNull);
    });

    for (final section in sections) {
      testWidgets('tap "${section.nameEn}" → ${section.type.name} screen opens',
          (tester) async {
        await pumpHub(tester);

        final tile = find.text(section.nameEn).first;
        await tester.ensureVisible(tile);
        await tester.pump();
        await tester.tap(tile);
        await tester.pump(); // one frame — surfaces a crash-on-open
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(_screenTypeFor(section.type)), findsOneWidget,
            reason: '${section.nameEn} tile did not open its practice screen');
        expect(tester.takeException(), isNull);
      });
    }

    // The loop above is grade '5' only — explicitly cover 準1 (pre1), whose
    // listening section was entirely MISSING (#75) so no test caught it. Assert
    // the listening tile both EXISTS and opens its screen for the flagship grade.
    testWidgets('準1 (pre1) listening tile exists and opens (#75 regression)',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
          const MaterialApp(home: ExamPracticeScreen(eikenGrade: 'pre1')));
      await tester.pump();

      final pre1 = kEikenExams['pre1']!;
      expect(
        pre1.sections.any((s) => s.type == ExamSectionType.listening),
        isTrue,
        reason: '準1 must have a listening section (#75)',
      );

      final tile = find.text('Listening (Parts 1–3)').first;
      await tester.ensureVisible(tile);
      await tester.pump();
      await tester.tap(tile);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byType(ListeningPracticeScreen), findsOneWidget,
          reason: '準1 listening tile did not open its practice screen');
      expect(tester.takeException(), isNull);
    });

    testWidgets('合格メーター with no practice data → honest "practice first" prompt',
        (tester) async {
      // With empty prefs there is no SkillAccuracyStore data, so the honest
      // behavior is a "practice first" SnackBar — NOT a fabricated 0% meter.
      await pumpHub(tester);
      final btn = find.textContaining('Check Pass Meter');
      await tester.ensureVisible(btn);
      await tester.pump();
      await tester.tap(btn);
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump(); // surface the SnackBar
      expect(find.textContaining('れんしゅう'), findsWidgets);
      expect(find.byType(PassMeterScreen), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });
}
