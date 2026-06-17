// test/features/exam_practice/conversation_practice_test.dart
//
// Content invariant for 英検 大問2 会話文の文空所補充 (task #31). Guards the
// grade-differentiated banks: 5/4/3/準2 each must have real, well-formed items
// (4 distinct non-empty choices, a valid in-range correctIdx). 大問2 会話文空所
// exists ONLY at these grades — 2級/準1級 大問2 is 長文空所, so they are not
// asserted here.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/features/exam_practice/conversation_practice_screen.dart';
import 'package:engquest/features/exam_practice/eiken_exam_config.dart';

void main() {
  // #118: the screen reads the FSRS review store (SharedPreferences) at start;
  // reset it before each test so a prior test's review writes can't reorder items
  // (CI-only flake class — see reading_practice_screen_test).
  setUp(() => SharedPreferences.setMockInitialValues({}));

  const grade5Section = ExamSection(
    id: '5_p2',
    nameJa: '筆記2: 会話文の文空所補充',
    nameEn: 'Conversation Completion',
    type: ExamSectionType.conversationComplete,
    questionCount: 5,
    timeLimitMinutes: 8,
    description: 'テスト用',
  );

  testWidgets('after answering, teaches WHY (大問2 reveal, #7)', (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: ConversationPracticeScreen(
        eikenGrade: '5',
        section: grade5Section,
      ),
    ));
    await tester.pumpAndSettle();

    // The 解説 is a post-answer reveal, not a hint shown up front.
    expect(find.byKey(const ValueKey('conv_explanation')), findsNothing);
    expect(find.text('かいせつ / Why'), findsNothing);

    // Pick the natural reply to "Do you like music?" (wherever it shuffled to).
    await tester.tap(find.text('Yes, I do. I like singing.'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('conv_explanation')), findsOneWidget);
    expect(find.text('かいせつ / Why'), findsOneWidget);
  });

  test('英検5級 conversation items all carry a 解説 (#7 teach-why)', () {
    final items = conversationItemsForTest('5');
    // ≥ one exam's worth (5); depth-expanded to 8 (2026-06-14). The per-item 解説
    // + position-free invariants are enforced in the well-formed loop below.
    expect(items.length, greaterThanOrEqualTo(5));
  });
  // 大問2 会話 choices are shuffled at load (_shuffleConversationChoices), so a
  // 解説 must justify by the answer's CONTENT, never by a choice position — the
  // same defect found in the reading pool (idxN/選択肢/番目). This locks every
  // authored 会話 item to a non-empty, position-free teach-why 解説.
  final positionRef = RegExp(r'idx\s*\d|[0-9０-９]番|選択肢|番目');
  for (final grade in ['5', '4', '3', 'pre2']) {
    test('英検$grade級 会話 items are well-formed 大問2 (4 choices, valid key)', () {
      final items = conversationItemsForTest(grade);
      expect(items.length, greaterThanOrEqualTo(5),
          reason: 'grade $grade has too few conversation items');

      for (final item in items) {
        // Exactly four options, exam-standard.
        expect(item.choices.length, 4, reason: 'grade $grade: ${item.choices}');
        // Correct index points at a real choice.
        expect(item.correctIdx, inInclusiveRange(0, 3),
            reason: 'grade $grade bad correctIdx ${item.correctIdx}');
        // No duplicate or empty options (a dup could create two right answers).
        expect(item.choices.toSet().length, item.choices.length,
            reason: 'duplicate choice in grade $grade: ${item.choices}');
        for (final c in item.choices) {
          expect(c.trim(), isNotEmpty,
              reason: 'empty choice in ${item.choices}');
        }
        // Teach-why 解説: present and position-free (choices shuffle at render).
        expect(item.explanation != null && item.explanation!.trim().isNotEmpty,
            isTrue,
            reason: 'grade $grade: item missing 解説 — the reveal would teach '
                'nothing for ${item.choices}');
        expect(positionRef.hasMatch(item.explanation!), isFalse,
            reason: 'grade $grade: 解説 references a choice position '
                '(choices shuffle): "${item.explanation}"');
      }
    });
  }

  test('準2級プラス serves NO 会話 items (大問2 is 長文空所 there) — #7', () {
    // Regression guard: the catch-all else used to serve 準2-level items to
    // pre2plus mislabelled as 準2級プラス (misinformation). Unauthored grades
    // must return [] so the screen shows an honest 準備中, never wrong content.
    expect(conversationItemsForTest('pre2plus'), isEmpty);
    expect(conversationItemsForTest('2'), isEmpty);
    expect(conversationItemsForTest('pre1'), isEmpty);
    // The authored grades still have their banks.
    expect(conversationItemsForTest('pre2'), isNotEmpty);
  });

  testWidgets('準2級プラス shows honest 準備中, never another grade\'s items (#7)',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: ConversationPracticeScreen(
        eikenGrade: 'pre2plus',
        section: ExamSection(
          id: 'p2p_p2',
          nameJa: '会話',
          nameEn: 'Conversation',
          type: ExamSectionType.conversationComplete,
          questionCount: 0,
          timeLimitMinutes: 0,
          description: 'test',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('準備中'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('3級 and 準2級 have DIFFERENT conversation banks (not the old shared set)',
      () {
    // Regression guard for the defect fixed 2026-06-08: both upper grades used
    // to return the identical generic (too-hard-for-3級) bank.
    final g3 =
        conversationItemsForTest('3').map((i) => i.choices.first).toList();
    final gpre2 =
        conversationItemsForTest('pre2').map((i) => i.choices.first).toList();
    expect(g3, isNot(equals(gpre2)));
  });

  testWidgets('#16 hint: 50/50 lifeline narrows to 2 + 合格率-exclusion notice',
      (tester) async {
    tester.view.physicalSize = const Size(440, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: ConversationPracticeScreen(
        eikenGrade: '5',
        section: grade5Section,
      ),
    ));
    await tester.pumpAndSettle();

    final hintBtn = find.byKey(const ValueKey('conv_hint_button'));
    expect(hintBtn, findsOneWidget);
    expect(find.textContaining('しぼったよ'), findsNothing);

    await tester.tap(hintBtn);
    await tester.pumpAndSettle();

    // Consumed (once per question) + the honesty notice appears.
    expect(find.byKey(const ValueKey('conv_hint_button')), findsNothing);
    expect(find.textContaining('合格率に 入りません'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
