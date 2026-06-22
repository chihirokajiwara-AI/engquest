import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/exam_practice/reading_practice_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  // #118: the reading screen now reads the FSRS review store (SharedPreferences)
  // at session start to surface previously-missed passages first. Reset that
  // store before EVERY test so review data written by a PRIOR test can't reorder
  // the passages and break the fixed answer-by-text sequence — a CI-only timing
  // flake ('results show pass when >= 60%', 2026-06-17) where the prior test's
  // fire-and-forget recordAnswer had landed before this test read the store.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();
  });

  const grade5Section = ExamSection(
    id: '5_r3',
    nameJa: '筆記3: 長文読解',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 4,
    timeLimitMinutes: 10,
    description: 'テスト用',
  );

  const grade4Section = ExamSection(
    id: '4_r4',
    nameJa: '筆記4: 長文の内容一致選択',
    nameEn: 'Reading 4: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 5,
    timeLimitMinutes: 10,
    description: 'テスト用',
  );

  const grade3Section = ExamSection(
    id: '3_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 10,
    timeLimitMinutes: 15,
    description: 'テスト用',
  );

  const pre2Section = ExamSection(
    id: 'p2_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 7,
    timeLimitMinutes: 20,
    description: 'テスト用',
  );

  const grade2Section = ExamSection(
    id: '2_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 12,
    timeLimitMinutes: 25,
    description: 'テスト用',
  );

  const grade2FillInSection = ExamSection(
    id: '2_r2',
    nameJa: '筆記2: 長文の語句空所補充',
    nameEn: 'Reading 2: Passage Fill-in',
    type: ExamSectionType.readingComprehension,
    questionCount: 6,
    timeLimitMinutes: 15,
    description: 'テスト用',
  );

  const pre1Section = ExamSection(
    id: 'p1_r3',
    nameJa: '筆記3: 長文の内容一致選択',
    nameEn: 'Reading 3: Reading Comprehension',
    type: ExamSectionType.readingComprehension,
    questionCount: 10,
    timeLimitMinutes: 25,
    description: 'テスト用',
  );

  const pre1FillInSection = ExamSection(
    id: 'p1_r2',
    nameJa: '筆記2: 長文の語句空所補充',
    nameEn: 'Reading 2: Passage Fill-in',
    type: ExamSectionType.readingComprehension,
    questionCount: 6,
    timeLimitMinutes: 15,
    description: 'テスト用',
  );

  const pre2PlusFillInSection = ExamSection(
    id: 'p2p_r2',
    nameJa: '筆記2: 長文の語句空所補充',
    nameEn: 'Reading 2: Passage Fill-in',
    type: ExamSectionType.readingComprehension,
    questionCount: 6,
    timeLimitMinutes: 12,
    description: 'テスト用',
  );

  Widget buildScreen(String grade, ExamSection section) {
    return MaterialApp(
      home: ReadingPracticeScreen(
        eikenGrade: grade,
        section: section,
      ),
    );
  }

  // Pump at a realistic tall-phone viewport. The choices live in a scrollable
  // ListView; at the default 800×600 test surface only ~3 of 4 choices are laid
  // out, so when the answer-key-bias shuffle lands the answer in the 4th slot a
  // content finder sees 0 (a real phone is tall and renders all four). A fixed
  // tall view makes the choice tests deterministic and matches real usage.
  Future<void> pumpReading(
      WidgetTester tester, String grade, ExamSection section) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(buildScreen(grade, section));
    await tester.pumpAndSettle();
  }

  // Answer positions are now shuffled per session (positional answer-key-bias
  // fix), so locate a choice by its TEXT regardless of which slot it landed in.
  // A choice renders as "<n>. <answer>", so an anchored regex matches the choice
  // exactly and can never accidentally hit the passage body.
  // The option number now lives in a separate circular disc (unified option
  // component, CEO 2186 craft audit), so the answer text is its own Text widget
  // (was the inline "N. answer"). The number is still exposed via the disc + the
  // choice's Semantics label.
  Finder choice(String answer) => find.byWidgetPredicate(
        (w) => w is Text && w.data == answer,
        description: 'choice "$answer" at any position',
      );

  // Regression: 準2級プラス reading 大問2 was 準備中 standalone (no _getPassages case
  // → empty) even though the content existed in the mock pool. It now serves a
  // real cloze passage; this locks that it is no longer 準備中.
  testWidgets('準2級プラス 大問2 serves a real cloze passage, not 準備中',
      (tester) async {
    await pumpReading(tester, 'pre2plus', pre2PlusFillInSection);
    expect(find.textContaining('The Comeback of the Bicycle'), findsOneWidget,
        reason: 'pre2plus passage cloze must render its passage');
    expect(find.textContaining('準備中'), findsNothing,
        reason: 'pre2plus reading 大問2 is no longer a 準備中 gap');
    expect(tester.takeException(), isNull);
  });

  testWidgets('準2級プラス 大問3 serves a real comprehension passage, not 準備中',
      (tester) async {
    const pre2PlusCompSection = ExamSection(
      id: 'p2p_r3',
      nameJa: '筆記3: 長文の内容一致選択',
      nameEn: 'Reading 3: Reading Comprehension',
      type: ExamSectionType.readingComprehension,
      questionCount: 8,
      timeLimitMinutes: 22,
      description: 'テスト用',
    );
    await pumpReading(tester, 'pre2plus', pre2PlusCompSection);
    expect(find.textContaining('Community Gardens'), findsOneWidget,
        reason: 'pre2plus comprehension must render its first passage');
    expect(find.textContaining('準備中'), findsNothing,
        reason: 'pre2plus reading 大問3 is no longer a 準備中 gap');
    expect(tester.takeException(), isNull);
  });

  Future<void> answer(WidgetTester tester, String correct) async {
    await tester.tap(choice(correct));
    await tester.pumpAndSettle();
    await tester.tap(find.text('次へ'));
    await tester.pumpAndSettle();
  }

  group('ReadingPracticeScreen', () {
    testWidgets('renders passage and question for grade 5', (tester) async {
      await pumpReading(tester, '5', grade5Section);

      // Should show the title '長文読解（ちょうぶんどっかい）'
      expect(find.text('長文読解（ちょうぶんどっかい）'), findsOneWidget);
      // Should show passage type badge
      expect(find.text('NOTICE'), findsOneWidget);
      // Should show first question
      expect(find.text('When is the school festival?'), findsOneWidget);
      // Should show the answer choice (now at a shuffled position)
      expect(choice('On Saturday, November 15'), findsOneWidget);
    });

    testWidgets('selecting an answer highlights correct/wrong', (tester) async {
      await pumpReading(tester, '5', grade5Section);

      // Tap correct answer (wherever it shuffled to)
      await tester.tap(choice('On Saturday, November 15'));
      await tester.pumpAndSettle();

      // Next button should appear
      expect(find.text('次へ'), findsOneWidget);
    });

    testWidgets(
        'answered choice tiles expose せいかい/ふせいかい to screen readers (#92)',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpReading(tester, '5', grade5Section);
      // Pick a WRONG answer so we get both a せいかい (the correct tile) and a
      // ふせいかい (the wrong pick) announced — the a11y answered-state feedback.
      await tester.tap(choice('On Friday, November 14'));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('せいかい')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('ふせいかい')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('after answering, teaches WHY with passage evidence (#5)',
        (tester) async {
      await pumpReading(tester, '5', grade5Section);

      // Before answering there is no explanation — it is a reveal, not a hint.
      expect(find.byKey(const ValueKey('reading_explanation')), findsNothing);
      expect(find.text('かいせつ / Why'), findsNothing);

      // Answer → the 解説 panel must appear and quote the passage evidence
      // (the 英検 reading skill is locating the proof sentence).
      await tester.tap(choice('On Saturday, November 15'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('reading_explanation')), findsOneWidget);
      expect(find.text('かいせつ / Why'), findsOneWidget);
      expect(
          find.textContaining('November 15', findRichText: true), findsWidgets,
          reason: 'explanation should quote the passage evidence');
    });

    testWidgets('advances through questions and shows results', (tester) async {
      await pumpReading(tester, '5', grade5Section);

      // Answer all 6 questions (3 passages × 2 questions). Tap whatever choice
      // is in slot 0 — we only need to advance, not be correct.
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const ValueKey('reading_choice_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('次へ'));
        await tester.pumpAndSettle();
      }

      // Should show results
      expect(find.text('戻る'), findsOneWidget);
    });

    testWidgets(
        'answering faster than humanly readable is EXCLUDED from the '
        'reading 合格率 (#R5 anti-gaming)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      PreferencesService.resetInstance();
      SkillAccuracyStore.resetInstance();
      // Force every instant test-tap to be "too fast to have read".
      ReadingPracticeScreen.minReadTime = const Duration(hours: 1);
      addTearDown(
          () => ReadingPracticeScreen.minReadTime = const Duration(seconds: 2));

      await pumpReading(tester, '5', grade5Section);
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.byKey(const ValueKey('reading_choice_0')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('次へ'));
        await tester.pumpAndSettle();
      }
      expect(find.text('戻る'), findsOneWidget, reason: 'reached results');

      final store = await SkillAccuracyStore.getInstance();
      final reading = store
          .readAccuracies('5')
          .where((a) => a.skill == EikenSkill.reading)
          .fold<int>(0, (s, a) => s + a.itemsAttempted);
      expect(reading, equals(0),
          reason: 'un-read (too-fast) answers must not feed the reading 合格率');
    });

    testWidgets('grade 4 shows correct number of passages', (tester) async {
      await pumpReading(tester, '4', grade4Section);

      // Grade 4 should show article type first
      expect(find.text('ARTICLE'), findsOneWidget);
      expect(find.text('Summer Camp'), findsOneWidget);
    });

    testWidgets('grade 3 has at least 10 questions total', (tester) async {
      await pumpReading(tester, '3', grade3Section);

      // Grade 3 should show notice type first
      expect(find.text('NOTICE'), findsOneWidget);
      // Progress should show /10
      expect(find.textContaining('/10'), findsOneWidget);
    });

    testWidgets('pre-2 comprehension shows its total question count',
        (tester) async {
      await pumpReading(tester, 'pre2', pre2Section);

      // 3 passages × their questions = 11 total (depth expansion 2026-06-14).
      expect(find.textContaining('/11'), findsOneWidget);
    });

    testWidgets('grade 2 comprehension has 12 questions', (tester) async {
      await pumpReading(tester, '2', grade2Section);

      // Progress should show /12
      expect(find.textContaining('/12'), findsOneWidget);
    });

    testWidgets('grade 2 fill-in shows correct title', (tester) async {
      await pumpReading(tester, '2', grade2FillInSection);

      // Should show fill-in specific title
      expect(find.text('長文語句空所補充（ちょうぶんごくくうしょほじゅう）'), findsOneWidget);
      // Progress should show /6
      expect(find.textContaining('/6'), findsOneWidget);
    });

    testWidgets('pre-1 comprehension shows its total question count',
        (tester) async {
      await pumpReading(tester, 'pre1', pre1Section);

      // 3 passages = 14 questions (depth expansion 2026-06-14).
      expect(find.textContaining('/14'), findsOneWidget);
    });

    testWidgets('pre-1 fill-in shows correct title and count', (tester) async {
      await pumpReading(tester, 'pre1', pre1FillInSection);

      expect(find.text('長文語句空所補充（ちょうぶんごくくうしょほじゅう）'), findsOneWidget);
      expect(find.textContaining('/6'), findsOneWidget);
    });

    // Happy-path partial-credit regression (#reading-accuracy-guard):
    // completing a reading session with exactly ONE wrong answer must record
    // (correct = N-1, total = N) into SkillAccuracyStore for EikenSkill.reading.
    //
    // N is derived the same way the existing 'advances through 6 questions' test
    // does: grade 5 has 3 passages × 2 questions each = 6 (the progress counter
    // '1/6' visible on screen confirms this at runtime).  An off-by-one,
    // double-record, or hint-branch regression would silently corrupt every
    // child's displayed reading pass-rate with no CI gate — this test closes
    // that gap.
    //
    // minReadTime gate: set to Duration.zero (same as the 100%-pass test below)
    // so every instant test-tap counts as a MEASURED answer.  Without this the
    // too-fast exclusion path fires and _measuredTotal stays 0, which causes
    // _recordSessionResult to return early without writing anything to the store.
    testWidgets(
        'partial-credit: 1 wrong answer records (correct=N-1, total=N) '
        'into SkillAccuracyStore for EikenSkill.reading', (tester) async {
      ReadingPracticeScreen.minReadTime = Duration.zero;
      addTearDown(
          () => ReadingPracticeScreen.minReadTime = const Duration(seconds: 2));

      await pumpReading(tester, '5', grade5Section);

      // Derive N from the on-screen progress counter the same way the existing
      // 'advances through 6 questions' and 'results show pass when >= 60%'
      // tests rely on it: grade 5 passages = 3 passages × 2 questions = 6.
      // Confirmed by finding '1/6' in the progress bar on the first question.
      expect(find.textContaining('/6'), findsOneWidget,
          reason: 'grade 5 must have 6 total questions (3 passages × 2)');
      const int n = 6;

      // Answer Q1 WRONG (a wrong choice text that is never the answer key).
      // Q1 answer key = 'On Saturday, November 15'; pick a wrong distractor.
      await tester.tap(choice('On Friday, November 14'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('次へ'));
      await tester.pumpAndSettle();

      // Answer Q2–Q6 all CORRECT by their text (positions are shuffled).
      await answer(tester, 'Sell rice balls');
      await answer(tester, 'A cat');
      await answer(tester, "On Yuki's bed");
      await answer(tester, 'A rabbit.');
      await answer(tester, 'Carrots and lettuce.');

      // Session should be done.
      expect(find.text('戻る'), findsOneWidget, reason: 'reached results screen');

      // _recordSessionResult is fire-and-forget (unawaited); pump to let the
      // async store.record() Future complete before we inspect the store.
      await tester.pump(const Duration(milliseconds: 50));

      final store = await SkillAccuracyStore.getInstance();
      final accuracies = store.readAccuracies('5');
      final readingAcc =
          accuracies.firstWhere((a) => a.skill == EikenSkill.reading);

      expect(readingAcc.itemsAttempted, equals(n),
          reason: 'total must equal N ($n) — every measured question counted');
      expect(
        (readingAcc.accuracy * n).round(),
        equals(n - 1),
        reason: 'correct must equal N-1 (${n - 1}) — exactly one wrong answer',
      );
    });

    testWidgets('results show pass when >= 60%', (tester) async {
      // The pass verdict is computed on the MEASURED signal (the items that fed
      // 合格率), not the all-items tally (R2-F7). Instant test taps would be
      // "too fast to have read" and thus unmeasured → practice-only, no pass.
      // Make every answer count as a real read so the ≥60% pass path is exercised.
      ReadingPracticeScreen.minReadTime = Duration.zero;
      addTearDown(
          () => ReadingPracticeScreen.minReadTime = const Duration(seconds: 2));
      await pumpReading(tester, '5', grade5Section);

      // Answer all 6 correctly by their TEXT (positions are now shuffled).
      await answer(tester, 'On Saturday, November 15');
      await answer(tester, 'Sell rice balls');
      await answer(tester, 'A cat');
      await answer(tester, "On Yuki's bed");
      await answer(tester, 'A rabbit.');
      await answer(tester, 'Carrots and lettuce.');

      // Should show pass result
      expect(find.text('合格（ごうかく）ライン到達（とうたつ）！'), findsOneWidget);
      expect(find.text('6 / 6 正解 (100%)'), findsOneWidget);
    });
  });

  group('#16 hint scaffold — 50/50 lifeline', () {
    testWidgets('hint button narrows to 2 + shows the 合格率-exclusion notice',
        (tester) async {
      await pumpReading(tester, '5', grade5Section);

      // Before answering, the lifeline is offered and the honesty notice is not
      // yet shown.
      final hintBtn = find.byKey(const ValueKey('reading_hint_button'));
      expect(hintBtn, findsOneWidget);
      expect(find.textContaining('しぼったよ'), findsNothing);

      await tester.tap(hintBtn);
      await tester.pumpAndSettle();

      // After using it: the button is consumed (once per question) and the
      // 合格率-exclusion notice appears.
      expect(find.byKey(const ValueKey('reading_hint_button')), findsNothing);
      expect(find.textContaining('合格率に 入りません'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  // Teach-why completeness gate (flaw-hunt 2026-06-14): reading was the only
  // major question type WITHOUT an explanation-coverage test (listening,
  // conversation, word-ordering all have one). Every comprehension question must
  // teach WHY — the explanation is revealed on answer to quote the passage
  // evidence. Covers default passages (any non-fill-in sectionId → grade
  // passages) AND the upper-grade 長文空所補充 fill-in sections; empty
  // (grade,section) combos contribute nothing, so this only asserts that
  // questions which EXIST teach why.
  group('reading explanation coverage (every question teaches why)', () {
    const surfaces = <List<String>>[
      ['5', 'r'], ['4', 'r'], ['3', 'r'], ['pre2', 'r'],
      ['pre2plus', 'r'], ['2', 'r'], ['pre1', 'r'], // default passages
      ['pre2plus', 'p2p_r2'], ['2', '2_r2'], ['pre1', 'p1_r2'], // fill-in
    ];
    for (final s in surfaces) {
      final grade = s[0];
      final section = s[1];
      test('every reading question in $grade/$section has an explanation', () {
        final expl = readingExplanationsForTest(grade, section);
        for (var i = 0; i < expl.length; i++) {
          final e = expl[i];
          expect(e != null && e.trim().isNotEmpty, isTrue,
              reason:
                  'reading $grade/$section Q#$i has no explanation — a wrong '
                  'answer would teach the child nothing');
        }
      });
    }
  });
}
