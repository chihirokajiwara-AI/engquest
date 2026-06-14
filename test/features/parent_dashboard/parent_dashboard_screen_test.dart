import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:engquest/core/analytics/progress_service.dart';
import 'package:engquest/core/models/progress_data.dart';
import 'package:engquest/features/parent_dashboard/parent_dashboard_screen.dart';

/// Records which uid the dashboard asked progress for (no Firestore).
class _RecordingProgressService extends ProgressService {
  String? lastUid;
  @override
  Future<LearningProgress> getProgress(String uid) async {
    lastUid = uid;
    return LearningProgress(
      uid: uid,
      currentStreak: 0,
      totalWordsMastered: 0,
      totalWordsPracticed: 0,
      masteryPercent: 0,
      last7Days: const [],
    );
  }
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
  });
}
