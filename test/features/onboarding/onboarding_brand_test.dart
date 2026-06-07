// test/features/onboarding/onboarding_brand_test.dart
// Guards the brand (#25, UX-audit P1): the onboarding welcome — the first screen
// after Start — must show the flavor's product name, not the old "ENG Quest"
// dev codename. Plus a repo guard so the stale codename cannot leak back into
// any non-legal UI surface.
//
// Legal screens (privacy / terms / parental consent) legitimately contain the
// registered legal entity name and are CHANGED ONLY WITH CEO/LEGAL APPROVAL, so
// they are excluded from the repo guard (tracked separately for escalation).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:engquest/core/config/flavor_config.dart';
import 'package:engquest/features/onboarding/onboarding_flow.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('Onboarding brand (#25)', () {
    testWidgets('welcome shows the aken product name, not "ENG Quest"',
        (tester) async {
      FlavorConfig.setFlavor(Flavor.aken);
      addTearDown(() => FlavorConfig.setFlavor(Flavor.aken));

      await tester.pumpWidget(MaterialApp(
        home: OnboardingFlow(onComplete: (_) {}),
      ));
      await tester.pump();

      expect(find.textContaining('A-KEN Quest へようこそ'), findsOneWidget);
      expect(find.textContaining('ENG Quest へようこそ'), findsNothing);
    });

    testWidgets('edilab flavor still shows its own name', (tester) async {
      FlavorConfig.setFlavor(Flavor.edilab);
      addTearDown(() => FlavorConfig.setFlavor(Flavor.aken));

      await tester.pumpWidget(MaterialApp(
        home: OnboardingFlow(onComplete: (_) {}),
      ));
      await tester.pump();

      // edilab's appName is intentionally "ENG Quest" — flavor-correct here.
      expect(find.textContaining('ENG Quest へようこそ'), findsOneWidget);
    });
  });

  test('no non-legal lib/ screen hardcodes the "ENG Quest" codename', () {
    final offenders = <String>[];
    final libDir = Directory('lib');
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // Excluded: legal docs (CEO/legal-approval only) + the flavor definition
      // (edilab's appName is legitimately "ENG Quest").
      if (entity.path.contains('/features/legal/')) continue;
      if (entity.path.endsWith('core/config/flavor_config.dart')) continue;
      final text = entity.readAsStringSync();
      for (final line in const LineSplitter().convert(text)) {
        final trimmed = line.trimLeft();
        if (trimmed.startsWith('//')) continue; // ignore comments
        // Both UI forms of the codename: "ENG Quest" (spaced) and "ENGQuest"
        // (PascalCase). Lowercase infra ids (engquest-mvp, engquest/voice,
        // bundle ids) are legitimately different and not matched.
        if (line.contains('ENG Quest') || line.contains('ENGQuest')) {
          offenders.add('${entity.path}: ${line.trim()}');
        }
      }
    }
    expect(offenders, isEmpty,
        reason: 'Old codename "ENG Quest" leaked into non-legal UI '
            '(use FlavorConfig appName):\n${offenders.join('\n')}');
  });
}
