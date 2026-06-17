// Smoke-locks the Phase-1 Layton "casebook" widgets (CEO 1904 redesign): the warm
// parchment panel + framed-preview build without exception and carry their text.
// These are additive (the dark app is untouched); they get wired in the flagged
// ナゾ re-skin (Phase 2). See docs/governance/LAYTON-QUALITY-REDESIGN-SPEC.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host(Widget child) => MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('DqParchPanel builds with a speaker tab + child', (tester) async {
    await tester.pumpWidget(host(
      const DqParchPanel(speaker: 'ランプ', child: Text('かまどの ひ')),
    ));
    expect(find.text('ランプ'), findsOneWidget);
    expect(find.text('かまどの ひ'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DqFramedPreview builds with art + caption', (tester) async {
    await tester.pumpWidget(host(
      SizedBox(
        width: 240,
        child: DqFramedPreview(
          caption: 'はいち',
          child: Container(color: pcSepiaPanel),
        ),
      ),
    ));
    expect(find.text('はいち'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('warm tokens are distinct from navy (additive, not a replacement)', () {
    expect(pcParchment0, isNot(dqNight0));
    expect(pcInk, isNot(dqInk));
  });
}
