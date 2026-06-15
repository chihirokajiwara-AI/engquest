// #73: the 大問1 cloze blank must render as an underlined fill-in gap, NOT the
// literal "(    )" parens (children misread parens as punctuation and answer the
// format wrong). clozeRich() replaces the whitespace-padded parens with an
// underlined gold gap and preserves the rest of the stem verbatim.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  const style = TextStyle(fontSize: 18);

  String plainTextOf(WidgetTester t) {
    final rt = t.widget<RichText>(find.byType(RichText));
    return (rt.text as TextSpan).toPlainText();
  }

  testWidgets('cloze blank parens are replaced (no literal "(  )" shown)',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: clozeRich('Summer is the (        ) she loves most.', style),
      ),
    ));
    final shown = plainTextOf(tester);
    // The before/after text is preserved...
    expect(shown, contains('Summer is the '));
    expect(shown, contains(' she loves most.'));
    // ...but the literal paren blank is GONE (replaced by the underline gap).
    expect(shown.contains('('), isFalse,
        reason: 'the cloze parens must not render as literal punctuation');
    expect(shown.contains(')'), isFalse);
  });

  testWidgets('a stem with no blank marker degrades to plain text',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: _Probe('She loves summer most.')),
    ));
    expect(find.text('She loves summer most.'), findsOneWidget);
  });
}

class _Probe extends StatelessWidget {
  const _Probe(this.s);
  final String s;
  @override
  Widget build(BuildContext context) =>
      clozeRich(s, const TextStyle(fontSize: 18));
}
