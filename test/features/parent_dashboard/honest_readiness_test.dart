// Parent dashboard readiness must reflect the HONEST per-skill 合格率 (cse_model),
// NOT vocabulary flashcard mastery (#128). A child with high vocab mastery but no
// 英検 practice must NOT be shown as "on pace to pass" to a paying parent.

import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({'onboarding_start_level': '5'});
    PreferencesService.resetInstance();
    SkillAccuracyStore.resetInstance();
  });

  test('readiness is 未測定 (0 items) with no 英検 practice — vocab mastery is '
      'NOT an input (#128)', () async {
    final est = await loadParentReadiness();
    expect(est, isNotNull, reason: '5級 has a CSE spec');
    expect(est!.totalItemsAttempted, 0,
        reason: 'no exam practice → nothing measured, no matter how many '
            'flashcards were mastered');
  });

  test('readiness reflects recorded per-skill 合格率, not vocabulary (#128)',
      () async {
    final store = await SkillAccuracyStore.getInstance();
    await store.record(
        grade: '5', skill: EikenSkill.reading, correct: 9, total: 10);

    final est = await loadParentReadiness();
    expect(est, isNotNull);
    expect(est!.itemsAttempted[EikenSkill.reading], 10,
        reason: 'reading items the parent number is built on');
    expect(est.totalItemsAttempted, greaterThan(0));
    expect(est.unmeasuredSkills.contains(EikenSkill.reading), isFalse,
        reason: 'reading now has data, so it is no longer 未測定');
  });
}
