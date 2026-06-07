// test/features/exam_practice/exam_practice_screen_smoke_test.dart
// R3 smoke test: pump the ExamPracticeScreen hub for several grades and assert
// no render exception. R4: no Firebase / network in build/initState.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:engquest/features/exam_practice/exam_practice_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ExamPracticeScreen — smoke tests (R3)', () {
    for (final grade in ['5', '3', 'pre2plus', 'pre1']) {
      testWidgets('grade $grade — pumps without exception', (tester) async {
        await tester.pumpWidget(MaterialApp(
          home: ExamPracticeScreen(eikenGrade: grade),
        ));
        await tester.pump();
        expect(find.byType(ExamPracticeScreen), findsOneWidget);
        // silent-blank guard: a screen that degrades to an empty Scaffold fails.
        expect(find.byType(Text), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
