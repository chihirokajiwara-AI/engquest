// #144 / CEO 1212 — the product ships on mobile + tablet, so every high-traffic
// screen must lay out without overflow at phone portrait, phone landscape (short),
// and tablet (portrait + landscape). This is the size-matrix gate: it pumps each
// screen at the Material-3 window classes and fails on a render overflow. New
// screens with dense Rows/Columns should be added here.

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

// (label, size) — Material 3 window classes + the awkward phone-landscape.
const _sizes = <(String, Size)>[
  ('phone-portrait', Size(360, 780)),
  ('phone-landscape', Size(800, 360)),
  ('tablet-portrait', Size(834, 1112)),
  ('tablet-landscape', Size(1280, 800)),
];

Future<void> _pumpAt(WidgetTester tester, Size size, Widget child) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
}

void main() {
  Map<String, Widget> screens() => {
        'home': KotobaHomeScreen(
            cardRepository: InMemoryFsrsCardRepository(),
            initialEikenLevel: '5'),
        'pass-meter': const PassMeterScreen(),
        'onboarding': OnboardingFlow(onComplete: (_) {}),
        'exam-practice': const ExamPracticeScreen(eikenGrade: '5'),
        'vocab-grammar': VocabGrammarPracticeScreen(
            eikenGrade: '5', section: _sec(ExamSectionType.vocabGrammar)),
        'listening': ListeningPracticeScreen(
            eikenGrade: '5', section: _sec(ExamSectionType.listening)),
        'word-ordering': WordOrderingPracticeScreen(
            eikenGrade: '5', section: _sec(ExamSectionType.wordOrdering)),
        'conversation': ConversationPracticeScreen(
            eikenGrade: '5',
            section: _sec(ExamSectionType.conversationComplete)),
        'mock-exam': const MockExamScreen(eikenGrade: '5'),
        'reading': ReadingPracticeScreen(
            eikenGrade: '5',
            section: _sec(ExamSectionType.readingComprehension)),
        'battle': const BattleScreen(),
      };

  for (final (label, size) in _sizes) {
    screens().forEach((name, _) {
      testWidgets(
          '$name OK @ $label (${size.width.toInt()}x${size.height.toInt()})',
          (tester) async {
        await _pumpAt(tester, size, screens()[name]!);
        expect(tester.takeException(), isNull,
            reason: '$name overflowed at $label — #144 responsive regression');
      });
    });
  }
}
