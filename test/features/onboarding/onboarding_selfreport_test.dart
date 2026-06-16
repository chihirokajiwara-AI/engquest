// CEO 1841/1843: the English diagnostic felt like it "started at 準2級/3級".
// Root cause was a stale build; current code already opens every child at the
// 5級 floor (placement_engine_test "gentle staircase"). This locks the NEW
// mechanism the CEO asked for: a self-report on the first screen, BEFORE any
// test (自己申告させてから診断), so a true beginner never faces a test that
// feels too hard. The three options are present, screen-reader-labelled, and
// selectable; the seed/skip wiring they drive is covered by the engine's
// selfReportShift tests + the kPreReaderPlacement floor.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';

void main() {
  testWidgets(
      'first screen offers a self-report (はじめて/すこし/とくい) before any test',
      (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(home: OnboardingFlow(onComplete: (_) {})));
    await t.pump(const Duration(milliseconds: 400));

    // All three English-experience options are present and screen-reader named
    // (a low-vision parent answers for a young child).
    expect(find.bySemanticsLabel(RegExp('えいごは はじめて')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('えいごを すこし')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('えいごが とくい')), findsOneWidget);

    h.dispose();
    expect(t.takeException(), isNull);
  });

  testWidgets('tapping a self-report option selects it', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(home: OnboardingFlow(onComplete: (_) {})));
    await t.pump(const Duration(milliseconds: 400));

    // Default is すこし; tap はじめて and confirm it becomes the selected option.
    // (The first screen scrolls on a short viewport — bring the chip on-screen.)
    final firstTime = find.bySemanticsLabel(RegExp('えいごは はじめて'));
    await t.ensureVisible(firstTime);
    await t.pump();
    await t.tap(firstTime);
    await t.pump(const Duration(milliseconds: 200));

    // Read the Semantics widget's own `selected` property (version-stable —
    // avoids the churny SemanticsFlag/flagsCollection APIs).
    final sem = t
        .widgetList<Semantics>(find.byType(Semantics))
        .firstWhere((s) => s.properties.label == 'えいごは はじめて、と こたえる');
    expect(sem.properties.selected, isTrue);

    h.dispose();
    expect(t.takeException(), isNull);
  });
}
