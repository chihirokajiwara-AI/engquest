// Exam-surface completeness gate (2026-06-14). Every 一次 section the exam hub
// offers per grade must route to REAL content — never the 準備中 empty state.
// This catches the "config defines a section but no screen serves it" class (the
// 準2級プラス reading + writing gaps fixed this session) across the WHOLE surface,
// and locks it so a future grade/section can never ship as 準備中.
//
// Speaking is the 二次 (interview) — backend-gated and deep-link only, not part of
// the hub's 一次 practice surface — so it is not asserted here.

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/core/data/vocab_repository.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/reading_practice_screen.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/writing_practice_screen.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

void main() {
  kEikenExams.forEach((grade, exam) {
    for (final section in exam.sections) {
      final bool hasContent = switch (section.type) {
        ExamSectionType.vocabGrammar => VocabRepository.hasGrade(grade),
        ExamSectionType.writing => promptsForGrade(grade).isNotEmpty,
        ExamSectionType.conversationComplete =>
          conversationItemsForTest(grade).isNotEmpty,
        ExamSectionType.readingComprehension =>
          readingHasPassagesForTest(grade, section.id),
        ExamSectionType.wordOrdering =>
          wordOrderingChunksForTest(grade).isNotEmpty,
        ExamSectionType.listening =>
          (kListeningItems[grade] ?? const []).isNotEmpty,
        ExamSectionType.speaking => true, // 二次, out of the 一次 hub surface
      };

      test('英検$grade · ${section.id} (${section.type.name}) serves content',
          () {
        expect(hasContent, isTrue,
            reason: '英検$grade ${section.nameJa} (${section.id}) would show '
                '準備中 — its content source is empty');
      });
    }
  });
}
