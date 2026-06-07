// test/features/quest/quest_title_screen_smoke_test.dart
// R3 smoke test: pump QuestTitleScreen and assert no render exception.
// R4: pure StatelessWidget — no Firebase / network. Title art loads via
// Image.asset with an errorBuilder, so it renders even if the asset is absent.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/features/quest/quest_title_screen.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('QuestTitleScreen — smoke tests (R3)', () {
    testWidgets('pumps without exception', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: QuestTitleScreen(onStart: () {}),
      ));
      await tester.pump();
      expect(find.byType(QuestTitleScreen), findsOneWidget);
      // silent-blank guard: a screen that degrades to an empty Scaffold fails.
      expect(find.byType(Text), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  });
}
