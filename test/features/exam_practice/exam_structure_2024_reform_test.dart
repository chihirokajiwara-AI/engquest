// test/features/exam_practice/exam_structure_2024_reform_test.dart
//
// Guard test: 2024-reform 英検 exam structure correctness.
//
// PURPOSE: Lock the per-grade 大問 structure so a future config/content edit
// cannot silently diverge from the official post-2024 exam.  This is
// "correctness gating 英検-pass" — a child practising the wrong structure
// (e.g. 3級 writing without the Eメール task, or a stale 準1 listening count)
// will mis-prepare for the real exam.
//
// Three layers are cross-verified here:
//   A. [kEikenExams]   — exam_config sections (what the hub shows)
//   B. [MockExamAssembler.assemble].targetCounts — mock exam target 大問 counts
//   C. [CseEstimator.skillsForGrade] — CSE model skills (what 合格率 weights)
//
// All three must agree with each other AND with the official 2024-reform spec
// (verified eiken.or.jp 2024renewal + 旺文社/eslclub, 2026-06).
//
// KNOWN DEFERRED:
//   • 準1級 大問3 = 7 (✓ fixed in config, locked by readingTotal test)
//   • 準2級 大問3 missing section → filled (✓ locked by pre2 section test)
//   Both were resolved and are now guarded by existing tests in
//   eiken_exam_config_test.dart; this file adds the structural+cross-layer guards.
//
// NO dart:io. No Firebase. No network. Pure-Dart tests (R4).

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/mock_exam.dart';
import 'package:engquest/features/exam_practice/writing_practice_screen.dart';

void main() {
  // ── Official 2024-reform reference data ─────────────────────────────────────
  //
  // Source: eiken.or.jp 2024renewal; 旺文社; eslclub.jp; verified 2026-06-19.
  //
  // Per-grade: (reading Q, writing tasks, listening Q)
  // 5級:  R=25  W=0  L=25
  // 4級:  R=35  W=0  L=30
  // 3級:  R=30  W=2  L=30  writing = Eメール + 意見論述
  // 準2:  R=29  W=2  L=30  writing = Eメール + 意見論述
  // 準2+: R=31  W=2  L=30  writing = 要約   + 意見論述  (2025 新設)
  // 2級:  R=31  W=2  L=30  writing = 要約   + 意見論述
  // 準1:  R=31  W=2  L=29  writing = 要約   + 意見論述

  const grades = ['5', '4', '3', 'pre2', 'pre2plus', '2', 'pre1'];

  // Official listening Q count per grade.
  const officialListeningQ = <String, int>{
    '5': 25,
    '4': 30,
    '3': 30,
    'pre2': 30,
    'pre2plus': 30,
    '2': 30,
    'pre1': 29,
  };

  // Official writing task count per grade (0 = no writing section).
  const officialWritingTasks = <String, int>{
    '5': 0,
    '4': 0,
    '3': 2,
    'pre2': 2,
    'pre2plus': 2,
    '2': 2,
    'pre1': 2,
  };

  // Grades whose writing is Eメール + 意見論述 (post-2024 reform: 3級 + 準2級).
  const emailWritingGrades = {'3', 'pre2'};

  // Grades whose writing is 要約 + 意見論述 (post-2024 reform: 準2+, 2, 準1).
  const summaryWritingGrades = {'pre2plus', '2', 'pre1'};

  // ── Layer A: kEikenExams section structure ────────────────────────────────

  group('Layer A — kEikenExams section structure', () {
    test('all 7 grades are present in kEikenExams', () {
      for (final g in grades) {
        expect(kEikenExams.containsKey(g), isTrue,
            reason: 'grade $g missing from kEikenExams');
      }
    });

    group('listening section Q count matches official 2024 reform', () {
      for (final entry in officialListeningQ.entries) {
        final grade = entry.key;
        final expected = entry.value;

        test('英検$grade listening = $expected問', () {
          final def = kEikenExams[grade]!;
          final listeningQ = def.sections
              .where((s) => s.type == ExamSectionType.listening)
              .fold<int>(0, (sum, s) => sum + s.questionCount);
          expect(listeningQ, expected,
              reason: '英検$grade リスニング should be $expected問 '
                  '(post-2024 reform official; 準1 was stale 30→29)');
        });
      }
    });

    // Writing section total tasks per grade — cross-check against config.
    // (Already tested in eiken_exam_config_test.dart but included here for
    // the cross-layer narrative; the two files guard different invariants.)
    group('writing task count from config matches official', () {
      for (final entry in officialWritingTasks.entries) {
        final grade = entry.key;
        final expected = entry.value;

        test('英検$grade writing tasks = $expected', () {
          final def = kEikenExams[grade]!;
          final wCount = def.sections
              .where((s) => s.type == ExamSectionType.writing)
              .fold<int>(0, (sum, s) => sum + s.questionCount);
          expect(wCount, expected,
              reason: '英検$grade writing section total should be $expected問');
        });
      }
    });

    // ── Writing task type composition ──────────────────────────────────────
    //
    // The 2024 reform introduced TWO distinct email formats and added 要約.
    // The config nameJa / description must reflect the correct task types so the
    // exam hub shows the right section label and the writing screen loads the
    // right prompts.  These guards lock the human-meaningful signal (nameJa
    // substring) rather than the raw type enum, catching bad rewords too.

    group('3級 writing sections encode Eメール + 意見論述 (2024 reform)', () {
      test('3級 has a writing section whose name mentions Eメール', () {
        final def = kEikenExams['3']!;
        final writingSections =
            def.sections.where((s) => s.type == ExamSectionType.writing);
        expect(writingSections, isNotEmpty);
        expect(
          writingSections.any((s) => s.nameJa.contains('Eメール')),
          isTrue,
          reason:
              '3級 writing section must mention Eメール (2024 reform; the hub label '
              'is the first thing a learner reads to know what to practise)',
        );
      });

      test('3級 has a writing section whose name mentions 意見論述 or 意見', () {
        final def = kEikenExams['3']!;
        final writingSections =
            def.sections.where((s) => s.type == ExamSectionType.writing);
        expect(
          writingSections
              .any((s) => s.nameJa.contains('意見論述') || s.nameJa.contains('意見')),
          isTrue,
          reason:
              '3級 writing section must mention 意見論述 (post-2024 reform task 2)',
        );
      });
    });

    group('準2級 writing sections encode Eメール + 意見 (2024 reform)', () {
      test('準2級 has a writing section mentioning Eメール', () {
        final def = kEikenExams['pre2']!;
        final writingSections =
            def.sections.where((s) => s.type == ExamSectionType.writing);
        expect(writingSections, isNotEmpty);
        expect(
          writingSections.any((s) => s.nameJa.contains('Eメール')),
          isTrue,
          reason:
              '準2級 writing must mention Eメール (2024 reform; 準2 uses ask-mode '
              'Eメール, different from 3級 answer-mode — label matters)',
        );
      });
    });

    group('2級/準1級/準2級プラス writing sections encode 要約 (2024 reform)', () {
      for (final grade in summaryWritingGrades) {
        test('英検$grade has a writing section mentioning 要約', () {
          final def = kEikenExams[grade]!;
          final writingSections =
              def.sections.where((s) => s.type == ExamSectionType.writing);
          expect(writingSections, isNotEmpty);
          expect(
            writingSections.any((s) => s.nameJa.contains('要約')),
            isTrue,
            reason: '英検$grade writing must mention 要約 (2024 reform added 要約 '
                'task; before reform there was only 意見論述)',
          );
        });
      }
    });

    test('5級 and 4級 have no writing sections', () {
      for (final grade in ['5', '4']) {
        final def = kEikenExams[grade]!;
        final wSections =
            def.sections.where((s) => s.type == ExamSectionType.writing);
        expect(wSections, isEmpty,
            reason: '英検$grade has no writing in 一次 exam (5/4級 writing-free)');
      }
    });
  });

  // ── Layer B: WritingPrompt bank task-type composition ─────────────────────
  //
  // The writing screen loads prompts via [promptsForGrade].  If the prompt bank
  // lacks the right task types for a grade the learner cannot practise the
  // correct format — which directly causes exam mis-preparation.

  group('Layer B — WritingPrompt bank task-type composition', () {
    for (final grade in emailWritingGrades) {
      test('英検$grade prompt bank contains ≥1 email prompt', () {
        final prompts = promptsForGrade(grade);
        expect(
          prompts.any((p) => p.type == WritingTaskType.email),
          isTrue,
          reason: '英検$grade (Eメール+意見論述 grade) must have ≥1 email prompt '
              'in promptsForGrade — learner cannot practise the real format otherwise',
        );
      });

      test('英検$grade prompt bank contains ≥1 opinion prompt', () {
        final prompts = promptsForGrade(grade);
        expect(
          prompts.any((p) => p.type == WritingTaskType.opinion),
          isTrue,
          reason: '英検$grade must have ≥1 意見論述 (opinion) prompt',
        );
      });
    }

    for (final grade in summaryWritingGrades) {
      test('英検$grade prompt bank contains ≥1 要約 (summary) prompt', () {
        final prompts = promptsForGrade(grade);
        expect(
          prompts.any((p) => p.type == WritingTaskType.summary),
          isTrue,
          reason: '英検$grade (要約+意見論述 grade) must have ≥1 summary prompt; '
              'pre2plus was 準備中 until prompts were authored',
        );
      });

      test('英検$grade prompt bank contains ≥1 opinion prompt', () {
        final prompts = promptsForGrade(grade);
        expect(
          prompts.any((p) => p.type == WritingTaskType.opinion),
          isTrue,
          reason: '英検$grade must have ≥1 意見論述 (opinion) prompt',
        );
      });
    }

    // 3級 Eメール = answer-mode; 準2級 Eメール = ask-mode (score-fatal if swapped)
    test('3級 email prompts are all answer-mode (NOT ask-mode)', () {
      final g3Emails =
          promptsForGrade('3').where((p) => p.type == WritingTaskType.email);
      expect(g3Emails, isNotEmpty);
      for (final p in g3Emails) {
        expect(p.emailAsksQuestions, isFalse,
            reason: '${p.id}: 3級 Eメール must ANSWER 2 underlined Qs '
                '(ask-mode is the score-fatal 準2 format)');
      }
    });

    test('準2級 email prompts are all ask-mode (NOT answer-mode)', () {
      final pre2Emails =
          promptsForGrade('pre2').where((p) => p.type == WritingTaskType.email);
      expect(pre2Emails, isNotEmpty);
      for (final p in pre2Emails) {
        expect(p.emailAsksQuestions, isTrue,
            reason: '${p.id}: 準2級 Eメール must ASK 2 questions about the '
                'underlined topic — answer-mode is the 3級 format and is score-fatal');
      }
    });

    test('email-writing grades have NO 要約 prompts', () {
      for (final grade in emailWritingGrades) {
        final prompts = promptsForGrade(grade);
        expect(
          prompts.any((p) => p.type == WritingTaskType.summary),
          isFalse,
          reason: '英検$grade (email+opinion grade) must NOT have 要約 prompts; '
              '要約 belongs only in 準2プラス/2級/準1級',
        );
      }
    });

    test('summary-writing grades have NO email prompts', () {
      for (final grade in summaryWritingGrades) {
        final prompts = promptsForGrade(grade);
        expect(
          prompts.any((p) => p.type == WritingTaskType.email),
          isFalse,
          reason: '英検$grade (要約+opinion grade) must NOT have Eメール prompts; '
              'Eメール belongs only in 3級/準2級',
        );
      }
    });
  });

  // ── Layer C: mock_exam _kTargetCounts vs kEikenExams cross-consistency ────
  //
  // [MockExamAssembler.assemble].targetCounts is built from the private
  // [_kTargetCounts] table.  The exam hub uses [kEikenExams] section counts.
  // These are two INDEPENDENT data sources; a silent divergence means the mock
  // practises a different item mix than the hub advertises.

  group('Layer C — mock targetCounts vs kEikenExams cross-consistency', () {
    // Official reading (all reading-type sections) and listening counts per grade.
    // Must match _kTargetCounts AND kEikenExams simultaneously.
    const readingTypes = {
      ExamSectionType.vocabGrammar,
      ExamSectionType.conversationComplete,
      ExamSectionType.wordOrdering,
      ExamSectionType.readingComprehension,
    };

    for (final grade in grades) {
      test('英検$grade mock.targetCounts[reading] == kEikenExams reading total',
          () {
        final exam = MockExamAssembler.assemble(grade, seed: 0);
        final mockReadingTarget = exam.targetCounts[EikenSkill.reading] ?? 0;

        final def = kEikenExams[grade]!;
        final configReadingTotal = def.sections
            .where((s) => readingTypes.contains(s.type))
            .fold<int>(0, (sum, s) => sum + s.questionCount);

        expect(mockReadingTarget, configReadingTotal,
            reason:
                '英検$grade mock reading target ($mockReadingTarget) diverges '
                'from config reading total ($configReadingTotal); the hub and mock '
                'must agree on 大問1〜4 counts or a child gets contradictory info');
      });

      test('英検$grade mock.targetCounts[listening] == kEikenExams listening Q',
          () {
        final exam = MockExamAssembler.assemble(grade, seed: 0);
        final mockListeningTarget =
            exam.targetCounts[EikenSkill.listening] ?? 0;

        final def = kEikenExams[grade]!;
        final configListeningTotal = def.sections
            .where((s) => s.type == ExamSectionType.listening)
            .fold<int>(0, (sum, s) => sum + s.questionCount);

        expect(mockListeningTarget, configListeningTotal,
            reason: '英検$grade mock listening target ($mockListeningTarget) '
                'diverges from config listening total ($configListeningTotal)');
      });
    }

    for (final entry in officialWritingTasks.entries) {
      final grade = entry.key;
      final expected = entry.value;

      test('英検$grade mock.targetCounts[writing] == $expected (official)', () {
        final exam = MockExamAssembler.assemble(grade, seed: 0);
        final mockWritingTarget = exam.targetCounts[EikenSkill.writing] ?? 0;
        expect(mockWritingTarget, expected,
            reason: '英検$grade mock writing target ($mockWritingTarget) must '
                'equal the official $expected (5/4級=0; 3級〜準1=2)');
      });
    }
  });

  // ── Layer D: CseEstimator skills vs kEikenExams section presence ──────────
  //
  // [CseEstimator.skillsForGrade] determines which skills contribute to 合格率.
  // If a grade has writing sections in kEikenExams but the CSE model omits
  // EikenSkill.writing, writing practice never updates the 合格率 — an invisible
  // corruption.  The reverse (CSE model includes writing, but no config writing
  // section) means the hub shows no writing tile but 合格率 demands it.

  group('Layer D — CseEstimator skills vs kEikenExams section presence', () {
    for (final grade in grades) {
      test('英検$grade CseEstimator skills match kEikenExams writing presence',
          () {
        final cseSkills =
            CseEstimator.skillsForGrade(grade) ?? const <EikenSkill>[];
        final cseHasWriting = cseSkills.contains(EikenSkill.writing);

        final def = kEikenExams[grade]!;
        final configHasWriting =
            def.sections.any((s) => s.type == ExamSectionType.writing);

        expect(cseHasWriting, configHasWriting,
            reason: '英検$grade: CseEstimator.writing=$cseHasWriting but '
                'kEikenExams writing presence=$configHasWriting; '
                'these must agree or 合格率 is broken');
      });

      test('英検$grade CseEstimator always includes reading + listening', () {
        final cseSkills =
            CseEstimator.skillsForGrade(grade) ?? const <EikenSkill>[];
        expect(cseSkills.contains(EikenSkill.reading), isTrue,
            reason: '英検$grade must have reading in CSE model');
        expect(cseSkills.contains(EikenSkill.listening), isTrue,
            reason: '英検$grade must have listening in CSE model');
      });
    }
  });

  // ── Section-ID stability ──────────────────────────────────────────────────
  //
  // Section IDs are referenced by name in reading_practice_screen (e.g.
  // 'pre2_r3' for the 準2 passage-cloze), skill_accuracy_store lookups, and
  // the mock assembler sectionId fields.  A rename silently breaks those
  // references.  Lock the structurally critical IDs.

  group('Section-ID stability for cross-referenced sections', () {
    test('準2級 大問3 passage-cloze section has id = pre2_r3', () {
      final pre2 = kEikenExams['pre2']!;
      // This specific ID is used in reading_practice_screen._pre2FillIn
      // to render the passage-cloze content.
      final section = pre2.sections.where((s) => s.id == 'pre2_r3').toList();
      expect(section, hasLength(1),
          reason: 'pre2_r3 is the ID the reading screen uses to load 準2 大問3; '
              'renaming it silently makes 準2 大問3 unplayable');
      expect(section.first.type, ExamSectionType.readingComprehension);
    });

    test('準1 listening section has id = p1_l', () {
      final pre1 = kEikenExams['pre1']!;
      final section = pre1.sections.where((s) => s.id == 'p1_l').toList();
      expect(section, hasLength(1),
          reason: 'p1_l is the canonical 準1 listening section ID');
    });

    test('3級 writing section has id = 3_w1', () {
      final g3 = kEikenExams['3']!;
      final section = g3.sections.where((s) => s.id == '3_w1').toList();
      expect(section, hasLength(1),
          reason: '3_w1 is referenced as the 3級 writing section in tests + UI');
    });
  });

  // ── Known-open deferred items ─────────────────────────────────────────────
  //
  // These are gaps that are KNOWN and DEFERRED (per CLAUDE.md / memory notes).
  // The tests here document the current state as a regression base; they do NOT
  // demand they be fixed — they merely prevent silent regression *from* whatever
  // state they're in when this test was written.

  group('Deferred items — regression baseline (not correctness gates)', () {
    test(
        '準1 大問3 = 7 questions (2024 reform cut from 10; was the long-open gap)',
        () {
      final pre1 = kEikenExams['pre1']!;
      // This was the "long-open deferred" item mentioned in memory notes.
      // Verified and fixed: 準1 大問3 = 7 (18+6+7 = 31 total reading).
      final r3 = pre1.sections
          .where((s) =>
              s.id == 'p1_r3' && s.type == ExamSectionType.readingComprehension)
          .toList();
      expect(r3, hasLength(1));
      expect(r3.first.questionCount, 7,
          reason: '準1 大問3 内容一致 = 7問 (post-2024 reform, was stale 10; '
              '18+6+7 = 31 reading total, matching _kTargetCounts)');
    });

    test('準2 大問3 = 2 blanks (was the missing section, now present)', () {
      final pre2 = kEikenExams['pre2']!;
      // Was the open "#60 missing section"; added with 2-blank post-reform count.
      final r3 = pre2.sections.where((s) => s.id == 'pre2_r3').toList();
      expect(r3, hasLength(1));
      expect(r3.first.questionCount, 2,
          reason: '準2 大問3 長文語句空所補充 = 2問 (post-reform; 大問3B removed)');
    });
  });
}
