// Smoke-locks the "casebook" framed widgets (CEO 1904 craft bar): the framed
// panel + framed-preview build without exception and carry their text. After the
// de-Layton re-skin (CEO 1933/1934, #114) these tokens render OUR distinct dark
// navy+gold "ink ledger" — NOT Layton's signature parchment. The test below guards
// the tokens stay DARK so they can't silently revert to the parchment look.
// See docs/governance/LAYTON-QUALITY-REDESIGN-SPEC.md.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  Widget host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

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

  test('casebook tokens are our DARK ink-ledger, not Layton parchment (#114)',
      () {
    // De-Layton (CEO 1933/1934): the page/panel/mat backgrounds must be dark
    // (navy), never a light parchment. Luminance guards against silent reversion.
    expect(pcParchment0.computeLuminance(), lessThan(0.15),
        reason: 'page base must be a dark navy, not parchment');
    expect(pcParchment1.computeLuminance(), lessThan(0.15),
        reason: 'panel fill must be a dark navy, not parchment');
    expect(pcSepiaPanel.computeLuminance(), lessThan(0.15),
        reason: 'raised-card mat must be dark, not sepia parchment');
    // Ink + gold read as light-on-dark (the premium navy+gold identity).
    expect(pcInk.computeLuminance(), greaterThan(0.6),
        reason: 'ink must be a light cream for legibility on navy');
    expect(pcFrameGold.computeLuminance(), greaterThan(0.5),
        reason: 'gilt rule must be a bright gold accent');
  });
}
