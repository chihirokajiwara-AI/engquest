// #114 / WCAG 2.2 SC 1.4.4 — text must resize to 200% (2.0x) without clipping.
// 実測 (never assume), 2026-06-11: swept screens at textScaler 2.0 and hardened the
// culprits. VERIFIED-SAFE & LOCKED below at 2.0x: home (after the daily-goal ring
// got a FittedBox(scaleDown) — it was the 62px culprit), pass-meter, onboarding.
// STILL OVERFLOWING (tracked #114, not yet locked): ExamPracticeScreen (~88px
// horizontal at 2.0x) + the reading/listening/mock screens (untested). The global
// text-scale cap in app.dart stays 1.6x until EVERY high-traffic screen passes 2.0x
// here — then it rises to 2.0 in one honest step. Raising the cap before that would
// clip content (a false WCAG claim); this test is the gate that prevents it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/home/kotoba_home_screen.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/vocab_grammar_practice_screen.dart';
import 'package:engquest/features/exam_practice/listening_practice_screen.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/mock_exam_screen.dart';
import 'package:engquest/features/exam_practice/reading_practice_screen.dart';
import 'package:engquest/features/battle/battle_screen.dart';
import 'package:engquest/features/explore/scene_view.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';

ExamSection _sec(ExamSectionType t) => ExamSection(
    id: '5_x',
    nameJa: 'テスト 大問',
    nameEn: 'Section',
    type: t,
    questionCount: 5,
    timeLimitMinutes: 10,
    description: 'd');

Future<void> _pumpAt2x(WidgetTester tester, double width, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = Size(width, 2200); // tall: vertical content scrolls
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Builder(
      builder: (ctx) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child,
      ),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  // VERIFIED-SAFE at WCAG 200% — locked against regression.
  for (final width in <double>[320, 360, 390]) {
    testWidgets('home OK @ textScaler 2.0, ${width}px (WCAG SC 1.4.4)',
        (tester) async {
      await _pumpAt2x(tester, width,
          KotobaHomeScreen(
              cardRepository: InMemoryFsrsCardRepository(), initialEikenLevel: '5'));
      expect(tester.takeException(), isNull,
          reason: 'home clipped @ 2.0x ${width}px — WCAG SC 1.4.4 regression');
    });
  }

  testWidgets('pass-meter OK @ textScaler 2.0 (WCAG SC 1.4.4)', (tester) async {
    await _pumpAt2x(tester, 360, const PassMeterScreen());
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarding OK @ textScaler 2.0 (WCAG SC 1.4.4)', (tester) async {
    await _pumpAt2x(tester, 360, OnboardingFlow(onComplete: (_) {}));
    expect(tester.takeException(), isNull);
  });

  // Exam hub + sub-screens — all hardened + verified at 2.0x.
  final subScreens = <String, Widget>{
    'exam-practice': const ExamPracticeScreen(eikenGrade: '5'),
    'vocab-grammar': VocabGrammarPracticeScreen(
        eikenGrade: '5', section: _sec(ExamSectionType.vocabGrammar)),
    'listening': ListeningPracticeScreen(
        eikenGrade: '5', section: _sec(ExamSectionType.listening)),
    'word-ordering': WordOrderingPracticeScreen(
        eikenGrade: '5', section: _sec(ExamSectionType.wordOrdering)),
    'conversation': ConversationPracticeScreen(
        eikenGrade: '5', section: _sec(ExamSectionType.conversationComplete)),
    'mock-exam': const MockExamScreen(eikenGrade: '5'),
    'reading': ReadingPracticeScreen(
        eikenGrade: '5', section: _sec(ExamSectionType.readingComprehension)),
    'battle': const BattleScreen(),
    'scene-view': SceneView(scene: kTown5Scene),
  };
  subScreens.forEach((name, w) {
    testWidgets('$name OK @ textScaler 2.0 (WCAG SC 1.4.4)', (tester) async {
      await _pumpAt2x(tester, 360, w);
      expect(tester.takeException(), isNull);
    });
  });
  // All 12 high-traffic screens now pass at 2.0x → app.dart's cap is 2.0 (WCAG
  // SC 1.4.4 met). Any new screen with dense Rows should be added here.
}
