// test/features/exam_practice/record_path_test.dart
//
// HIGH-BLAST-RADIUS guard (completeness critic 2026-06-08): the 大問 practice
// screens feed the headline 合格率 by calling SkillAccuracyStore.record() on
// session completion. A regression in that wiring (wrong skill, wrong grade,
// miscount, or not recording) would SILENTLY corrupt every learner's 合格率
// with nothing to catch it. These tests drive each 合格率-feeding screen to
// completion and assert it recorded the right (grade, skill, correct, total).
//
// Covered here: 大問2 会話 (conversation, incl. a wrong-answer count check) and
// 大問3 語句整序 (word-ordering) — both have deterministic content + a public test
// hook. STILL UNCOVERED (follow-up #37): 大問1 vocab (runtime-randomized, no
// hook), listening (records EikenSkill.listening — copy-paste miswire risk), and
// writing (bespoke binary scoring + apiAvailable gate — the most fragile
// recorder). Those need @visibleForTesting hooks first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';

ExamSection _section(ExamSectionType type) => ExamSection(
      id: 'x',
      nameJa: 'x',
      nameEn: 'x',
      type: type,
      questionCount: 5,
      timeLimitMinutes: 10,
      description: 'test',
    );

Future<SkillAccuracy> _readingFor(String grade) async {
  final store = await SkillAccuracyStore.getInstance();
  return store
      .readAccuracies(grade)
      .firstWhere((a) => a.skill == EikenSkill.reading);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();
  });

  testWidgets('会話 (大問2) records reading accuracy for the right grade',
      (tester) async {
    const grade = '5';
    final items = conversationItemsForTest(grade);
    expect(items, isNotEmpty);

    await tester.pumpWidget(MaterialApp(
      home: ConversationPracticeScreen(
        eikenGrade: grade,
        section: _section(ExamSectionType.conversationComplete),
      ),
    ));
    await tester.pump();

    // Answer every problem CORRECTLY, then advance.
    for (var i = 0; i < items.length; i++) {
      final correctText = items[i].choices[items[i].correctIdx];
      await tester.tap(find.text(correctText));
      await tester.pump();
      await tester.tap(find.text(i < items.length - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    // Let the fire-and-forget record() complete.
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(items.length),
        reason: 'must record total = #problems to reading skill');
    expect(reading.accuracy, equals(1.0),
        reason: 'all-correct → 100% reading accuracy');
    // Grade isolation: a different grade must NOT have been touched.
    final other = await _readingFor('4');
    expect(other.itemsAttempted, equals(0));
  });

  testWidgets('会話: a WRONG answer is recorded as correct<total (not full marks)',
      (tester) async {
    // Closes the all-correct tautology: an all-correct drive can't tell a real
    // counter from one that hard-codes correct=total. Answer exactly one wrong.
    const grade = '5';
    final items = conversationItemsForTest(grade);
    final n = items.length;

    await tester.pumpWidget(MaterialApp(
      home: ConversationPracticeScreen(
        eikenGrade: grade,
        section: _section(ExamSectionType.conversationComplete),
      ),
    ));
    await tester.pump();

    for (var i = 0; i < n; i++) {
      final correctIdx = items[i].correctIdx;
      // Problem 0 → deliberately wrong; the rest correct.
      final pickIdx =
          i == 0 ? (correctIdx + 1) % items[i].choices.length : correctIdx;
      await tester.tap(find.text(items[i].choices[pickIdx]));
      await tester.pump();
      await tester.tap(find.text(i < n - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(n));
    expect(reading.accuracy, closeTo((n - 1) / n, 0.001),
        reason: 'one wrong → correct must be exactly N-1, not full marks');
  });

  testWidgets('語句整序 (大問3) records reading accuracy for the right grade',
      (tester) async {
    const grade = '5';
    final chunkSets = wordOrderingChunksForTest(grade);
    expect(chunkSets, isNotEmpty);

    await tester.pumpWidget(MaterialApp(
      home: WordOrderingPracticeScreen(
        eikenGrade: grade,
        section: _section(ExamSectionType.wordOrdering),
      ),
    ));
    await tester.pump();

    for (var i = 0; i < chunkSets.length; i++) {
      // Place the 5 chunks in the CORRECT order (each chunk is unique per item).
      for (final chunk in chunkSets[i]) {
        await tester.tap(find.text(chunk));
        await tester.pump();
      }
      await tester.tap(find.text('答え合わせ'));
      await tester.pump();
      await tester.tap(
          find.text(i < chunkSets.length - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(chunkSets.length));
    expect(reading.accuracy, equals(1.0));
  });
}
