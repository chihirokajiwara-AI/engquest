// Task #26 — the listening session-end "review these" list. ListeningReviewPanel
// is a pure widget (missed items + an onReplay callback), so this asserts the
// real behaviour without driving the whole audio screen: one row per missed
// item, the 🔊 replay fires with the correct audioKey, and 解説 shows only when
// the item has one.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/features/exam_practice/listening_data.dart';
import 'package:engquest/features/exam_practice/listening_practice_screen.dart';

ListeningItem _item({
  required String audioKey,
  required String question,
  String? explanation,
}) =>
    ListeningItem(
      part: 1,
      grade: '5',
      audioKey: audioKey,
      transcripts: const ['Hello.'],
      questionType: ListeningQuestionType.responseSelect,
      question: question,
      choices: const ['a', 'b', 'c'],
      correctIndex: 0,
      explanation: explanation,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  ));
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('ListeningReviewPanel', () {
    testWidgets('renders one row per missed item with its question',
        (tester) async {
      await _pump(
        tester,
        ListeningReviewPanel(
          missed: [
            _item(audioKey: 'k1.mp3', question: 'What time is it?'),
            _item(audioKey: 'k2.mp3', question: 'Where is the cat?'),
          ],
          onReplay: (_) {},
        ),
      );
      expect(
          find.byKey(const ValueKey('listening_review_panel')), findsOneWidget);
      expect(find.text('What time is it?'), findsOneWidget);
      expect(find.text('Where is the cat?'), findsOneWidget);
      // One 🔊 replay control per missed item.
      expect(find.text('🔊'), findsNWidgets(2));
    });

    testWidgets('🔊 replay fires onReplay with that item\'s audioKey',
        (tester) async {
      final tapped = <String>[];
      await _pump(
        tester,
        ListeningReviewPanel(
          missed: [
            _item(audioKey: 'first.mp3', question: 'Q1'),
            _item(audioKey: 'second.mp3', question: 'Q2'),
          ],
          onReplay: tapped.add,
        ),
      );
      await tester.tap(find.text('🔊').at(1));
      await tester.pump();
      expect(tapped, ['second.mp3']);
    });

    testWidgets('shows 解説 when present, omits it when null', (tester) async {
      await _pump(
        tester,
        ListeningReviewPanel(
          missed: [
            _item(
              audioKey: 'k1.mp3',
              question: 'Q with reason',
              explanation: 'time を きく What time の こたえだから。',
            ),
            _item(audioKey: 'k2.mp3', question: 'Q without reason'),
          ],
          onReplay: (_) {},
        ),
      );
      expect(find.text('time を きく What time の こたえだから。'), findsOneWidget);
      // The reason-less item still renders its question (graceful).
      expect(find.text('Q without reason'), findsOneWidget);
    });

    testWidgets('replay target meets the 44px child-friendly hit size',
        (tester) async {
      await _pump(
        tester,
        ListeningReviewPanel(
          missed: [_item(audioKey: 'k.mp3', question: 'Q')],
          onReplay: (_) {},
        ),
      );
      final size = tester.getSize(
        find.ancestor(
          of: find.text('🔊'),
          matching: find.byType(InkWell),
        ),
      );
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
    });
  });
}
