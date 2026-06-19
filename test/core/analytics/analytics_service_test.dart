// test/core/analytics/analytics_service_test.dart
//
// Unit tests for C09 Analytics + A/B Framework
// Run: dart test test/core/analytics/analytics_service_test.dart

import 'package:test/test.dart';
import 'package:engquest/core/analytics/analytics_service.dart';

// ---------------------------------------------------------------------------
// Spy sink — captures all logged events
// ---------------------------------------------------------------------------

class SpySink implements AnalyticsSink {
  final List<({String name, Map<String, Object>? params})> events = [];
  final Map<String, String> userProperties = {};
  String? userId;

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    events.add((name: name, params: parameters));
  }

  @override
  Future<void> setUserId(String uid) async => userId = uid;

  @override
  Future<void> setUserProperty(String name, String value) async =>
      userProperties[name] = value;

  @override
  Future<void> logError(
    Object error,
    StackTrace? stack, {
    String? context,
  }) async {}

  void reset() {
    events.clear();
    userProperties.clear();
    userId = null;
  }
}

void main() {
  late SpySink spy;
  late AnalyticsService svc;

  setUp(() {
    spy = SpySink();
    svc = AnalyticsService(sink: spy);
  });

  // -----------------------------------------------------------------------
  // A/B Framework
  // -----------------------------------------------------------------------
  group('AbFramework', () {
    const ab = AbFramework();
    const exp = '30day_anki_trial';

    test('same uid+experiment always returns same group', () {
      final a1 = ab.assign('user_abc', exp);
      final a2 = ab.assign('user_abc', exp);
      expect(a1.group, equals(a2.group));
      expect(a1.seed, equals(a2.seed));
    });

    test('different uids can land in different groups', () {
      final groups = <AbGroup>{};
      for (var i = 0; i < 100; i++) {
        groups.add(ab.assign('user_$i', exp).group);
      }
      // With 100 users, both groups must appear
      expect(groups, containsAll([AbGroup.treatment, AbGroup.control]));
    });

    test('split is roughly 50/50 over 1000 users', () {
      int treatment = 0;
      for (var i = 0; i < 1000; i++) {
        if (ab.assign('u$i', exp).group == AbGroup.treatment) treatment++;
      }
      // Allow ±10% tolerance
      expect(treatment, greaterThan(400));
      expect(treatment, lessThan(600));
    });

    test('groupName is correct string', () {
      final t =
          AbAssignment(experimentId: exp, group: AbGroup.treatment, seed: 0);
      final c =
          AbAssignment(experimentId: exp, group: AbGroup.control, seed: 1);
      expect(t.groupName, equals('treatment'));
      expect(c.groupName, equals('control'));
    });
  });

  // -----------------------------------------------------------------------
  // AnalyticsService — event emission
  // -----------------------------------------------------------------------
  group('AnalyticsService.logBattleAnswer', () {
    test('emits correct event with all params', () async {
      await svc.logBattleAnswer(wordId: 'eiken5_042', grade: 3, latencyMs: 850);
      expect(spy.events.length, equals(1));
      final e = spy.events.first;
      expect(e.name, equals(EngQuestEvent.battleCardAnswered));
      expect(e.params?[EngQuestParam.wordId], equals('eiken5_042'));
      expect(e.params?[EngQuestParam.grade], equals(3));
      expect(e.params?[EngQuestParam.latencyMs], equals(850));
    });
  });

  group('AnalyticsService.startSession / endSession', () {
    test('startSession sets userId and logs sessionStart', () async {
      await svc.startSession('user_test_01');
      expect(spy.userId, equals('user_test_01'));
      expect(
          spy.events.any((e) => e.name == EngQuestEvent.sessionStart), isTrue);
    });

    test('endSession logs sessionEnd with duration and word count', () async {
      await svc.startSession('user_test_01');
      spy.events.clear();
      await svc.endSession(15);
      expect(spy.events.length, equals(1));
      final e = spy.events.first;
      expect(e.name, equals(EngQuestEvent.sessionEnd));
      expect(e.params?[EngQuestParam.wordsPracticed], equals(15));
      expect(e.params?.containsKey(EngQuestParam.sessionDurationSec), isTrue);
    });
  });

  group('AnalyticsService.assignAndLogAbGroup', () {
    test('logs ab_group_assigned event and sets user property', () async {
      await svc.assignAndLogAbGroup(
          uid: 'user_x', experimentId: '30day_anki_trial');
      expect(spy.events.any((e) => e.name == EngQuestEvent.abGroupAssigned),
          isTrue);
      expect(spy.userProperties.containsKey('ab_30day_anki_trial'), isTrue);
    });

    test('returns consistent assignment across calls', () async {
      final a1 = await svc.assignAndLogAbGroup(
          uid: 'stable_user', experimentId: 'test_exp');
      spy.reset();
      final a2 = await svc.assignAndLogAbGroup(
          uid: 'stable_user', experimentId: 'test_exp');
      expect(a1.group, equals(a2.group));
    });
  });

  group('AnalyticsService.logRetentionTest', () {
    test('emits retention test event with correct params', () async {
      await svc.logRetentionTest(
          uid: 'u1', group: AbGroup.treatment, retentionScore: 0.82);
      final e = spy.events.first;
      expect(e.name, equals(EngQuestEvent.abRetentionTest));
      expect(e.params?[EngQuestParam.retentionScore], equals(0.82));
      expect(e.params?[EngQuestParam.abGroup], equals('treatment'));
    });
  });

  group('AnalyticsService.logVoiceAttempt', () {
    test('emits voice attempt result', () async {
      await svc.logVoiceAttempt(
          wordId: 'eiken5_001', accuracy: 0.91, latencyMs: 1200);
      final e = spy.events.first;
      expect(e.name, equals(EngQuestEvent.voiceAttemptResult));
      expect(e.params?[EngQuestParam.accuracy], equals(0.91));
    });
  });

  group('NoOpAnalytics', () {
    test('never throws', () async {
      final noop = NoOpAnalytics();
      expect(() async => noop.logEvent('any', parameters: {'k': 'v'}),
          returnsNormally);
    });
  });
}
