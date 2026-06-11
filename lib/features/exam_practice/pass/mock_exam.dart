// lib/features/exam_practice/pass/mock_exam.dart
// A-KEN Quest — Timed 一次 mock exam assembler.
//
// Assembles a mock exam in the REAL 大問 proportions for a given grade,
// draws items from existing pools (vocab/reading/listening/writing), and
// scores the result into CseEstimate via CseEstimator.
//
// 大問 PROPORTIONS (verified eiken.or.jp solutions pages, accessed 2026-06-07):
//   Grade | Reading Q | Writing Q | Listening Q | Total
//   ------|-----------|-----------|-------------|------
//   5級   |    25     |     0     |     25      |  50
//   4級   |    35     |     0     |     30      |  65
//   3級   |    30     |     2     |     30      |  62 (Eメール + 英作文)
//   準2級 |    29     |     2     |     30      |  61 (Eメール + 意見論述)
//   準2級+|    31     |     2     |     30      |  63 (要約 + 意見論述, 2025新設)
//   2級   |    31     |     2     |     30      |  63 (要約 + 意見論述)
//   準1級 |    31     |     2     |     29      |  62 (要約 + 意見論述)
//
// The mock always draws from the EXISTING item pools; it never generates new
// content. When a pool has fewer items than the target count, the mock uses
// all available items (the score is scaled proportionally to keep the per-skill
// accuracy meaningful).
//
// Scoring: each section yields a (correct, total) pair → per-skill accuracy →
// fed into CseEstimator.estimate() → CseEstimate.
//
// Writing accuracy is NOT computed in the mock (the mock has no writing UI). The
// caller passes the learner's accumulated writing accuracy — sourced from
// WritingPracticeScreen's AI-rubric grades via SkillAccuracyStore — into
// [MockExamScorer.score] as [writingAccuracy] + [writingAttempted]. It is an
// HONEST AI-graded signal, never a completion ratio: ungraded/never-practiced
// writing arrives as writingAttempted == 0 → the skill is 未測定 (excluded from
// the provisional 合格率), never counted as a measured 0%.
//
// NO dart:io. No Firebase. No network. Pure-Dart. (R4)

import 'dart:math';

import 'cse_model.dart';
import '../choice_shuffle.dart';
import '../listening_data.dart';
import '../writing_practice_screen.dart';
import 'reading_item_pool.dart';

// ── Item types exposed to the mock engine ────────────────────────────────────

/// A single mock-exam question with a 4-choice MCQ structure.
/// Reading and Listening items are represented in this unified form.
class MockMcqItem {
  final String id;
  final String questionText;

  /// 4 choices (may be empty strings for gap-fill blanks when choice is
  /// implied; the mock engine only scores items that have [choices] + [correctIdx]).
  final List<String> choices;
  final int correctIdx;

  /// Which skill this item contributes to.
  final EikenSkill skill;

  /// Source section id from [ExamSection.id] (for audit tracing).
  final String sectionId;

  const MockMcqItem({
    required this.id,
    required this.questionText,
    required this.choices,
    required this.correctIdx,
    required this.skill,
    required this.sectionId,
  });
}

/// A writing slot in the mock — presence means this writing task was included.
/// Scoring requires external AI grading; [writingAccuracyOverride] in
/// [MockExamScorer] lets the writing screen inject the rubric result.
class MockWritingSlot {
  final String promptId;
  final EikenSkill skill; // always EikenSkill.writing
  final String sectionId;

  const MockWritingSlot({
    required this.promptId,
    required this.skill,
    required this.sectionId,
  });
}

/// A fully assembled mock exam for one grade.
///
/// [mcqItems] — shuffled list of Reading + Listening MCQ items (in exam order:
///   Reading first, then Listening), drawn from existing pools.
/// [writingSlots] — Writing tasks to be completed (0 for 5/4 grades).
/// [grade] — the 英検 grade key.
/// [targetCounts] — the target item counts per skill (may exceed available items).
/// [availableCounts] — the actual item counts per skill (≤ target).
class MockExam {
  final String grade;
  final List<MockMcqItem> mcqItems;
  final List<MockWritingSlot> writingSlots;

  /// Target question count per skill from the official 大問 spec.
  final Map<EikenSkill, int> targetCounts;

  /// Actual question count per skill available in the current pool.
  final Map<EikenSkill, int> availableCounts;

  const MockExam({
    required this.grade,
    required this.mcqItems,
    required this.writingSlots,
    required this.targetCounts,
    required this.availableCounts,
  });

  /// True when available items equal the target counts (a "full" mock).
  bool get isFullMock => availableCounts.entries
      .every((e) => e.value >= (targetCounts[e.key] ?? 0));
}

// ── Grade targets (大問 proportions) ─────────────────────────────────────────

/// Official 大問 question counts per skill for each grade (一次試験).
/// Source: EIKEN-MASTERY-AND-GAPS-2026-06-06.json (verified 2026-06-06).
const Map<String, Map<EikenSkill, int>> _kTargetCounts = {
  '5': {
    EikenSkill.reading: 25,
    EikenSkill.listening: 25,
  },
  '4': {
    EikenSkill.reading: 35,
    EikenSkill.listening: 30,
  },
  // Counts CORRECTED 2026-06-07 (verified eiken.or.jp solutions pages, post-2024
  // reform): 3級 writing 1→2 (added Eメール); 準2級 reading 32→29; 準1級 reading
  // 41→31 and listening 30→29.
  '3': {
    EikenSkill.reading: 30,
    EikenSkill.writing: 2,
    EikenSkill.listening: 30,
  },
  'pre2': {
    EikenSkill.reading: 29,
    EikenSkill.writing: 2,
    EikenSkill.listening: 30,
  },
  // 準2級プラス (2025): R31 (大問1=17,2=6,3=8) / W2 (要約+意見) / L30 (15+15).
  'pre2plus': {
    EikenSkill.reading: 31,
    EikenSkill.writing: 2,
    EikenSkill.listening: 30,
  },
  '2': {
    EikenSkill.reading: 31,
    EikenSkill.writing: 2,
    EikenSkill.listening: 30,
  },
  'pre1': {
    EikenSkill.reading: 31,
    EikenSkill.writing: 2,
    EikenSkill.listening: 29,
  },
};

// ── MockExamAssembler ─────────────────────────────────────────────────────────

/// Assembles a mock exam from existing item pools for a given grade.
///
/// Calls into the existing pool accessor functions:
///   [listeningItemsFor] (listening_data.dart) — grade/part → [ListeningItem]
///   [promptsForGrade]   (writing_practice_screen.dart) — grade → [WritingPrompt]
///   [readingItemsFor]   (reading_practice_screen.dart) — grade → [MockMcqItem]
///
/// The assembler is stateless; create a new instance per mock attempt.
class MockExamAssembler {
  MockExamAssembler._();

  /// Assembles a mock exam for [grade] with items drawn from existing pools.
  /// [seed] controls shuffling; use a fixed value for reproducible tests.
  static MockExam assemble(String grade, {int? seed}) {
    final rng = seed != null ? Random(seed) : Random();

    final targets = _kTargetCounts[grade] ?? {};
    final mcqItems = <MockMcqItem>[];
    final writingSlots = <MockWritingSlot>[];
    final available = <EikenSkill, int>{};

    // ── Reading ───────────────────────────────────────────────────────────────
    final readingTarget = targets[EikenSkill.reading] ?? 0;
    if (readingTarget > 0) {
      final rawItems = _readingMcqItems(grade);
      final drawn = _drawItems(rawItems, readingTarget, rng);
      mcqItems.addAll(drawn);
      available[EikenSkill.reading] = drawn.length;
    }

    // ── Listening ─────────────────────────────────────────────────────────────
    final listeningTarget = targets[EikenSkill.listening] ?? 0;
    if (listeningTarget > 0) {
      final rawItems = _listeningMcqItems(grade, rng);
      final drawn = _drawItems(rawItems, listeningTarget, rng);
      mcqItems.addAll(drawn);
      available[EikenSkill.listening] = drawn.length;
    }

    // ── Writing ───────────────────────────────────────────────────────────────
    final writingTarget = targets[EikenSkill.writing] ?? 0;
    if (writingTarget > 0) {
      final prompts = promptsForGrade(grade);
      final shuffled = List<WritingPrompt>.from(prompts)..shuffle(rng);
      final count = min(writingTarget, shuffled.length);
      for (var i = 0; i < count; i++) {
        writingSlots.add(MockWritingSlot(
          promptId: shuffled[i].id,
          skill: EikenSkill.writing,
          sectionId: '${grade}_w${i + 1}',
        ));
      }
      available[EikenSkill.writing] = count;
    }

    return MockExam(
      grade: grade,
      mcqItems: mcqItems,
      writingSlots: writingSlots,
      targetCounts: targets,
      availableCounts: available,
    );
  }

  // ── Pool accessors ──────────────────────────────────────────────────────────

  /// Pull all listening items for a grade from [kListeningItems] and convert
  /// to [MockMcqItem].
  static List<MockMcqItem> _listeningMcqItems(String grade, Random rng) {
    final items = kListeningItems[grade] ?? [];
    return items.where((it) => it.choices.length == 4).map((it) {
      // Shuffle each item's choices — the authored listening keys cluster at
      // position 2 (40%) with position 4 almost unused (3%), so an always-tap-1
      // child scores ~40% on listening with no comprehension, inflating the CSE
      // 合格率. Choices are on-screen text (not spoken in the audio), so moving
      // them is safe. Mirrors reading/conversation (#79). See [shuffledChoiceSet].
      final s = shuffledChoiceSet(it.choices, it.correctIndex, rng);
      return MockMcqItem(
        id: it.audioKey,
        questionText: it.question,
        choices: s.choices,
        correctIdx: s.correctIdx,
        skill: EikenSkill.listening,
        sectionId: '${grade}_l',
      );
    }).toList();
  }

  /// Pull reading comprehension items from [readingItemsFor] and convert.
  static List<MockMcqItem> _readingMcqItems(String grade) {
    return readingItemsFor(grade);
  }

  // ── Draw helper ─────────────────────────────────────────────────────────────

  /// Randomly draw up to [count] items from [pool] (without replacement).
  static List<T> _drawItems<T>(List<T> pool, int count, Random rng) {
    if (pool.isEmpty) return [];
    final shuffled = List<T>.from(pool)..shuffle(rng);
    return shuffled.take(min(count, shuffled.length)).toList();
  }
}

// ── MockExamScorer ────────────────────────────────────────────────────────────

/// Scores a completed mock exam into a [CseEstimate].
///
/// [answers] maps MockMcqItem.id → learner's chosen answer index (0–3).
/// Items without an answer are scored as incorrect (unattempted).
///
/// Writing accuracy is 0.0 by default (writing requires AI grading).
/// Pass [writingAccuracy] (0.0–1.0) to inject an AI-graded writing score.
class MockExamScorer {
  MockExamScorer._();

  static CseEstimate? score({
    required MockExam exam,
    required Map<String, int> answers,
    double writingAccuracy = 0.0,
    int writingAttempted = 0,
    bool listeningCaptioned = false,
  }) {
    // Tally correct/attempted per skill for MCQ items.
    final correct = <EikenSkill, int>{};
    final attempted = <EikenSkill, int>{};

    for (final item in exam.mcqItems) {
      attempted[item.skill] = (attempted[item.skill] ?? 0) + 1;
      final chosen = answers[item.id];
      if (chosen != null && chosen == item.correctIdx) {
        correct[item.skill] = (correct[item.skill] ?? 0) + 1;
      }
    }

    // Build SkillAccuracy list.
    final accuracies = <SkillAccuracy>[];

    for (final skill in [EikenSkill.reading, EikenSkill.listening]) {
      // A deaf/HoH child who turned CAPTIONS on READ the transcript instead of
      // hearing it (#125 parity): that measures reading-of-script, not by-ear
      // listening, so captioned listening is honestly 未測定 — excluded from the
      // 合格率 exactly as the live listening screen excludes it. The child still
      // completes the mock; their readiness reflects the skills actually measured.
      final captioned = skill == EikenSkill.listening && listeningCaptioned;
      final att = captioned ? 0 : (attempted[skill] ?? 0);
      final cor = captioned ? 0 : (correct[skill] ?? 0);
      accuracies.add(SkillAccuracy(
        skill: skill,
        accuracy: att > 0 ? cor / att : 0.0,
        itemsAttempted: att,
      ));
    }

    // Writing skill. The mock has no writing UI, so its score comes from the
    // learner's PRIOR writing-practice data ([writingAttempted] from the store).
    // If they've never practiced writing, itemsAttempted == 0 → writing is
    // 未測定 and excluded from the provisional 合格率 (NOT counted as a measured
    // 0%, which used to drag every 3級+ learner's meter down a whole skill).
    final gradeHasWriting =
        (CseEstimator.skillsForGrade(exam.grade) ?? const [])
            .contains(EikenSkill.writing);
    if (gradeHasWriting) {
      accuracies.add(SkillAccuracy(
        skill: EikenSkill.writing,
        accuracy: writingAttempted > 0 ? writingAccuracy : 0.0,
        itemsAttempted: writingAttempted,
      ));
    }

    return CseEstimator.estimate(grade: exam.grade, accuracies: accuracies);
  }
}
