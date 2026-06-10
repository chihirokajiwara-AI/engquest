// End-to-end verification of THE core value chain, driven through the real app
// widget tree + real stores (not per-piece mocks): a child practises → the result
// lands in SkillAccuracyStore → the pass-meter the child opens shows the HONEST
// 合格率 reflecting it (or, with no practice, an honest "do practice first", never a
// fake meter). This is the closest-to-real signal obtainable PRE-LAUNCH (CEO 1185/
// 1187): drive the real flow now, not a persona. Stitches record_path (#37),
// cse_model (#113) and the exam-hub pass-meter button (#68) into one user journey.

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/exam_practice_screen.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/pass_meter_screen.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();
  });

  Future<void> tapPassMeter(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      const MaterialApp(home: ExamPracticeScreen(eikenGrade: '5')),
    );
    await tester.pump();
    final btn = find.textContaining('Check Pass Meter');
    await tester.ensureVisible(btn);
    await tester.tap(btn);
    // Flush the async store read inside _openLivePassMeter (real I/O).
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  testWidgets('no practice yet → honest "do practice first", NOT a fake meter',
      (tester) async {
    await tapPassMeter(tester);
    expect(find.byType(PassMeterScreen), findsNothing,
        reason: 'with zero data the meter must NOT open with fabricated numbers');
    expect(find.textContaining('まずれんしゅう'), findsOneWidget,
        reason: 'honest empty state nudges practice instead of faking a 合格率');
  });

  testWidgets('after a real practice result, the pass-meter shows the honest 合格率',
      (tester) async {
    // Simulate the child having practised reading (the record_path that real
    // practice screens write).
    final store = await SkillAccuracyStore.getInstance();
    await store.record(
        grade: '5', skill: EikenSkill.reading, correct: 8, total: 10);

    await tapPassMeter(tester);

    expect(find.byType(PassMeterScreen), findsOneWidget,
        reason: 'practice exists → the live meter opens with the REAL estimate');
    expect(find.textContaining('%'), findsWidgets,
        reason: 'the readiness % must render');
    // The estimate the screen was built on reflects the practice: reading is
    // measured (not 未測定), listening is honestly still 未測定.
    final est = CseEstimator.estimate(
      grade: '5',
      accuracies: store.readAccuracies('5'),
    )!;
    expect(est.unmeasuredSkills.contains(EikenSkill.reading), isFalse);
    expect(est.itemsAttempted[EikenSkill.reading], 10);
  });
}
