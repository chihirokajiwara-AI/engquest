import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/firebase/auth_service.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/core/storage/preferences_service.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/skill_accuracy_store.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

/// Records which uid the dashboard asked progress for (no Firestore).
class _RecordingProgressService extends ProgressService {
  String? lastUid;
  final List<DailyProgress> days;
  final int streak;
  _RecordingProgressService({this.days = const [], this.streak = 0});
  @override
  Future<LearningProgress> getProgress(String uid) async {
    lastUid = uid;
    return LearningProgress(
      uid: uid,
      currentStreak: streak,
      totalWordsMastered: 0,
      totalWordsPracticed: 0,
      masteryPercent: 0,
      last7Days: days,
    );
  }
}

/// #181 test seam: a uid without hitting Firebase, so the data-dependent tabs
/// render under flutter_test instead of the offline error state.
class _FakeAuth extends AuthService {
  @override
  Future<String> getOrCreateUid() async => 'test-uid';
}

void main() {
  group('ParentDashboardScreen', () {
    test('can be instantiated with default constructor', () {
      const screen = ParentDashboardScreen();
      expect(screen, isNotNull);
      expect(screen.childUid, isNull);
    });

    test('carries the linked childUid', () {
      const screen = ParentDashboardScreen(childUid: 'child-abc');
      expect(screen.childUid, 'child-abc');
    });

    // The fatal parent-value bug (2026-06-14): the link-code flow fetched the
    // child's uid then dropped it, so a remote parent saw their OWN (empty) data.
    // Lock that the dashboard now reads the LINKED CHILD's uid when given one.
    testWidgets('linked-parent view reads the CHILD uid, not the device uid',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final fake = _RecordingProgressService();
      await tester.pumpWidget(MaterialApp(
        home: ParentDashboardScreen(
          childUid: 'child-xyz',
          progressService: fake,
        ),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(fake.lastUid, 'child-xyz',
          reason: 'the dashboard must scope its progress read to the linked '
              'child, not this parent device');
    });

    // Honesty (Task#31): the read is child-scoped, but goal/reminder settings are
    // device-local — a REMOTE parent must be told their edits don't reach the
    // child, and must NOT be told that on the on-device path.
    testWidgets('linked view: settings tab shows the device-local warning',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: ParentDashboardScreen(
          childUid: 'child-xyz',
          progressService: _RecordingProgressService(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
      expect(find.textContaining('とどきません'), findsOneWidget,
          reason: 'a remote parent must be told their goal/reminder edits are '
              'device-local and do not reach the child');
    });

    testWidgets('on-device view: NO device-local warning (it would be wrong)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: ParentDashboardScreen(
          progressService: _RecordingProgressService(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('設定'));
      await tester.pumpAndSettle();
      expect(find.textContaining('とどきません'), findsNothing,
          reason: 'on the child device the settings DO apply — no warning');
    });

    // Honesty (#156): the 英検準備度 readiness card reads DEVICE-LOCAL exam data.
    // On a linked-parent device that's the parent's (or none), not the child's —
    // so the linked view must NOT show a readiness % (it would label the parent's
    // own data as the child's 合格率); it shows an honest "view on your child's
    // device" note instead. The suppressed path loads no store, so this is robust.
    testWidgets('linked view: readiness card shows the honest device note',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: ParentDashboardScreen(
          childUid: 'child-xyz',
          progressService: _RecordingProgressService(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('ごらんいただけます'), findsOneWidget,
          reason: 'a remote parent must not be shown device-local data as the '
              'child 合格率 — show the honest note instead');
    });

    // Honesty (#179): with only ONE skill measured, the readiness % is built on a
    // partial sample, so the card marks it 暫定 (provisional). The provisional
    // computation is driven by est.unmeasuredSkills — locked at the data layer by
    // honest_readiness_test ('reading now has data, so it is no longer 未測定',
    // i.e. listening remains unmeasured). loadParentReadiness with reading-only
    // grade-5 data yields readinessPct=50 + unmeasuredSkills={listening}; the card
    // maps that non-empty set → 暫定 label + prominent 未測定 box. (A full-widget
    // assertion is impractical here: the card lazy-builds below the fold in the
    // rich on-device dashboard, so it is not in the default pumped subtree.)
    // #177 + #181: with the AuthService seam the data-dependent 記録 tab renders,
    // so we can assert the weekly summary card is actually present (not just that
    // its data computes). Leads the tab with a legible 今週のまとめ / This Week.
    testWidgets('records tab shows the 今週のまとめ weekly summary card (#177)',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(MaterialApp(
        home: ParentDashboardScreen(
          progressService: _RecordingProgressService(
            days: [
              DailyProgress(
                  date: DateTime(2026, 6, 18),
                  wordsPracticed: 12,
                  sessionMinutes: 8,
                  averageScore: 2.0),
            ],
            streak: 3,
          ),
          authService: _FakeAuth(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('記録'));
      await tester.pumpAndSettle();
      // DqPanel uppercases the English half ("THIS WEEK"); 「まとめ」 is unique to
      // the summary-card title (the takeaway line uses 今週 but not まとめ).
      expect(find.textContaining('まとめ'), findsOneWidget,
          reason: 'the records tab must lead with a legible weekly summary');
    });

    // #179 + #181: the home tab's readiness card now renders, so assert the
    // provisional 暫定 state shows when a skill is unmeasured (reading-only data).
    testWidgets('home readiness card marks partial data 暫定 (#179)',
        (tester) async {
      SharedPreferences.setMockInitialValues({'onboarding_start_level': '5'});
      PreferencesService.resetInstance();
      SkillAccuracyStore.resetInstance();
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
          grade: '5', skill: EikenSkill.reading, correct: 8, total: 10);

      await tester.pumpWidget(MaterialApp(
        home: ParentDashboardScreen(
          progressService: _RecordingProgressService(),
          authService: _FakeAuth(),
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.textContaining('暫定', skipOffstage: false), findsOneWidget,
          reason: 'a % built on one skill must be flagged provisional, not a '
              'confident gold headline');
    });

    test('loadParentReadiness flags partial data as provisional (#179)',
        () async {
      SharedPreferences.setMockInitialValues({'onboarding_start_level': '5'});
      PreferencesService.resetInstance();
      SkillAccuracyStore.resetInstance();
      final store = await SkillAccuracyStore.getInstance();
      await store.record(
          grade: '5', skill: EikenSkill.reading, correct: 8, total: 10);

      final est = await loadParentReadiness();
      expect(est, isNotNull);
      expect(est!.unmeasuredSkills, isNotEmpty,
          reason: 'listening untested → card must render the 暫定 provisional '
              'state, not a confident gold %');
      expect(est.unmeasuredSkills.contains(EikenSkill.listening), isTrue);
    });
  });
}
