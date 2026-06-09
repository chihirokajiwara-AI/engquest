// test/features/exam_practice/record_path_test.dart
//
// HIGH-BLAST-RADIUS guard (completeness critic 2026-06-08): the 大問 practice
// screens feed the headline 合格率 by calling SkillAccuracyStore.record() on
// session completion. A regression in that wiring (wrong skill, wrong grade,
// miscount, or not recording) would SILENTLY corrupt every learner's 合格率
// with nothing to catch it. These tests drive each 合格率-feeding screen to
// completion and assert it recorded the right (grade, skill, correct, total).
//
// Covered here: 大問2 会話 (conversation, incl. a wrong-answer count check),
// 大問3 語句整序 (word-ordering), and リスニング (listening — verifies it records
// the LISTENING skill, not reading, the audit's top miswire risk). STILL
// UNCOVERED (follow-up #37): 大問1 vocab (runtime-randomized, same reading
// pattern as conversation) and writing (bespoke scoring + apiAvailable gate,
// dormant until the backend #7 ships). Those need @visibleForTesting hooks /
// the backend first.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/word_ordering_practice_screen.dart';
import 'package:engquest/features/exam_practice/listening_practice_screen.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';
import 'package:engquest/features/exam_practice/vocab_grammar_practice_screen.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

ExamSection _section(ExamSectionType type) => ExamSection(
      id: 'x',
      nameJa: 'x',
      nameEn: 'x',
      type: type,
      questionCount: 5,
      timeLimitMinutes: 10,
      description: 'test',
    );

Future<SkillAccuracy> _skillFor(String grade, EikenSkill skill) async {
  final store = await SkillAccuracyStore.getInstance();
  return store.readAccuracies(grade).firstWhere((a) => a.skill == skill);
}

Future<SkillAccuracy> _readingFor(String grade) =>
    _skillFor(grade, EikenSkill.reading);

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

  testWidgets('語句整序: a RULE-HINTED problem is EXCLUDED from 合格率 (#111)',
      (tester) async {
    // CEO 1132 cont.: the opt-in 「ルールをみる」 teaches the grammar rule before
    // answering; a rule-assisted problem must NOT count as unaided reading skill.
    const grade = '5';
    final chunkSets = wordOrderingChunksForTest(grade);
    final n = chunkSets.length;
    expect(n, greaterThanOrEqualTo(2));

    await tester.pumpWidget(MaterialApp(
      home: WordOrderingPracticeScreen(
        eikenGrade: grade,
        section: _section(ExamSectionType.wordOrdering),
      ),
    ));
    await tester.pump();

    for (var i = 0; i < n; i++) {
      if (i == 0) {
        // Reveal the rule on the FIRST problem → marks it assisted.
        await tester.tap(find.byKey(const ValueKey('wo_hint')));
        await tester.pump();
      }
      for (final chunk in chunkSets[i]) {
        await tester.tap(find.text(chunk));
        await tester.pump();
      }
      await tester.tap(find.text('答え合わせ'));
      await tester.pump();
      await tester.tap(find.text(i < n - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(n - 1),
        reason: 'the 1 rule-hinted problem is excluded; only n-1 recorded');
    expect(reading.accuracy, equals(1.0),
        reason: 'every unaided answer correct → 100%');
  });

  testWidgets('リスニング records to the LISTENING skill (not reading) + counts',
      (tester) async {
    // The highest miswire risk (audit): listening must record EikenSkill.listening,
    // NOT reading — a copy-paste to reading would silently corrupt BOTH meters.
    const grade = '5';
    final items = kListeningItems[grade]!;
    final n = items.length;
    expect(n, greaterThan(0));

    await tester.pumpWidget(MaterialApp(
      home: ListeningPracticeScreen(
        eikenGrade: grade,
        section: _section(ExamSectionType.listening),
      ),
    ));
    await tester.pump();

    for (var i = 0; i < n; i++) {
      // Each part begins with a "はじめる / Start" interstitial — dismiss it.
      final start = find.text('はじめる / Start');
      if (start.evaluate().isNotEmpty) {
        await tester.tap(start);
        await tester.pump();
      }
      // Answer: problem 0 deliberately wrong, the rest correct (count guard).
      final correctIdx = items[i].correctIndex;
      final pickIdx =
          i == 0 ? (correctIdx + 1) % items[i].choices.length : correctIdx;
      await tester.tap(find.byType(DqChoice).at(pickIdx));
      await tester.pump();
      await tester.tap(
          find.text(i < n - 1 ? 'つぎへ / Next' : 'けっか / Results'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final listening = await _skillFor(grade, EikenSkill.listening);
    expect(listening.itemsAttempted, equals(n),
        reason: 'must record total = #items to the listening skill');
    expect(listening.accuracy, closeTo((n - 1) / n, 0.001),
        reason: 'one wrong → correct = N-1');
    // SKILL ISOLATION: listening must NOT have touched the reading meter.
    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(0),
        reason: 'listening leaked into reading — the copy-paste miswire bug');
  });

  // ── 大問1 vocab/grammar (#37) ──────────────────────────────────────────────
  // The highest-VOLUME practice section (every grade's biggest part) and thus
  // the biggest lever on each learner's 合格率. Questions are randomised from the
  // vocab DB at runtime, so we read the correct answers via the screen's
  // @visibleForTesting hook and answer deterministically.
  //
  // The screen loads the vocab JSON via rootBundle (real async I/O) in initState
  // — pumpAndSettle (fake-async) starves it while the loading spinner animates,
  // so we let the load complete inside tester.runAsync, then pump to rebuild.

  Future<_VocabState> pumpVocab(WidgetTester tester, String grade) async {
    // Tall surface so the question content + 次の問題へ button are on-screen and
    // tappable (the default 800x600 is too short for the cloze + 4 choices).
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: VocabGrammarPracticeScreen(
        eikenGrade: grade,
        section: _section(ExamSectionType.vocabGrammar),
      ),
    ));
    await tester.pump(); // initState fires _loadQuestions (real async)
    await tester.runAsync(() async {
      // Real event loop turns here: rootBundle.loadString + jsonDecode resolve.
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pump(); // rebuild now that _loading=false & questions are set
    final state = tester.state(find.byType(VocabGrammarPracticeScreen));
    final corrects =
        ((state as dynamic).debugCorrectChoices as List).cast<String>();
    return _VocabState(state, corrects);
  }

  testWidgets('大問1 vocab/grammar records reading accuracy for the right grade',
      (tester) async {
    const grade = '5';
    final v = await pumpVocab(tester, grade);
    expect(v.corrects, isNotEmpty,
        reason: '5級 has 600 eligible words → should generate questions');

    for (var i = 0; i < v.corrects.length; i++) {
      await tester.tap(find.text(v.corrects[i]).first);
      await tester.pump();
      await tester
          .tap(find.text(i < v.corrects.length - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(v.corrects.length),
        reason: 'must record total = #questions to the reading skill');
    expect(reading.accuracy, equals(1.0),
        reason: 'all-correct → 100% reading accuracy');

    // SKILL ISOLATION: 大問1 is a READING 大問 — it must NOT touch listening.
    final listening = await _skillFor(grade, EikenSkill.listening);
    expect(listening.itemsAttempted, equals(0),
        reason: '大問1 vocab must not record to the listening meter');

    // GRADE ISOLATION.
    final other = await _readingFor('4');
    expect(other.itemsAttempted, equals(0));
  });

  testWidgets('大問1: a WRONG answer is recorded as correct<total (not full marks)',
      (tester) async {
    const grade = '5';
    final v = await pumpVocab(tester, grade);
    final n = v.corrects.length;
    expect(n, greaterThanOrEqualTo(2),
        reason: 'need ≥2 questions to make one wrong, rest right');

    for (var i = 0; i < n; i++) {
      if (i == 0) {
        // Deliberately answer the FIRST question wrong.
        final wrong = (v.state as dynamic).debugWrongChoiceFor(0) as String;
        await tester.tap(find.text(wrong).first);
      } else {
        await tester.tap(find.text(v.corrects[i]).first);
      }
      await tester.pump();
      await tester.tap(find.text(i < n - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(n));
    expect(reading.accuracy, closeTo((n - 1) / n, 0.001),
        reason: 'one wrong → correct = N-1, faithfully recorded');
  });

  testWidgets('大問1: a HINTED question is EXCLUDED from 合格率 (honest scaffold)',
      (tester) async {
    // CEO 1132 cont. / #111: the opt-in 「いみを みる」 hint helps a pre-reader, but
    // a meaning-matched answer must NOT count as unaided reading skill. Using the
    // hint on one question must drop it from the recorded (correct,total).
    const grade = '5';
    final v = await pumpVocab(tester, grade);
    final n = v.corrects.length;
    expect(n, greaterThanOrEqualTo(2),
        reason: 'need ≥2 so one hinted + rest unaided is observable');

    for (var i = 0; i < n; i++) {
      if (i == 0) {
        // Reveal the meanings on the FIRST question → marks it assisted.
        await tester.tap(find.byKey(const ValueKey('vg_hint')));
        await tester.pump();
      }
      await tester.tap(find.text(v.corrects[i]).first);
      await tester.pump();
      await tester.tap(find.text(i < n - 1 ? '次の問題へ' : '結果を見る'));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    final reading = await _readingFor(grade);
    expect(reading.itemsAttempted, equals(n - 1),
        reason: 'the 1 hinted question is excluded; only n-1 unaided recorded');
    expect(reading.accuracy, equals(1.0),
        reason: 'every unaided answer was correct → 100% (no dilution)');
  });
}

class _VocabState {
  _VocabState(this.state, this.corrects);
  final dynamic state;
  final List<String> corrects;
}
