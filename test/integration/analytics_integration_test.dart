// test/integration/analytics_integration_test.dart
// ENG Quest — Integration: Analytics event firing across a battle session
//
// Verifies that all required analytics events are fired during:
//   1. Session start
//   2. Each card shown
//   3. Each card answered
//   4. Session complete
//   5. A/B group assignment
//
// Uses SpySink (no-op capture) — no Firebase dependency required.
//
// Run: dart test test/integration/analytics_integration_test.dart

import 'package:test/test.dart';
import 'package:engquest/core/analytics/analytics_service.dart';
import 'package:engquest/core/fsrs/fsrs_algorithm.dart';
import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/data/models/vocab_item.dart';

// ---------------------------------------------------------------------------
// SpySink — captures all logged events for assertion
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

  void reset() {
    events.clear();
    userProperties.clear();
    userId = null;
  }

  bool hasEvent(String name) => events.any((e) => e.name == name);

  int countEvent(String name) => events.where((e) => e.name == name).length;

  Map<String, Object>? paramsFor(String name) =>
      events.firstWhere((e) => e.name == name, orElse: () => (name: '', params: null)).params;
}

// ---------------------------------------------------------------------------
// Analytics-instrumented battle session
// Mirrors BattleScreen but with injected AnalyticsService
// ---------------------------------------------------------------------------

class InstrumentedBattleSession {
  final AnalyticsService analytics;
  final FSRSAlgorithm fsrs = FSRSAlgorithm();
  final List<VocabItem> vocab;
  late List<FSRSCard> deck;
  late List<int> queue;
  int queueIdx = 0;
  final DateTime _sessionStart;

  InstrumentedBattleSession(this.vocab, this.analytics)
      : _sessionStart = DateTime.now() {
    deck = vocab.map((v) => FSRSCard(vocabId: v.id)).toList();
    queue = fsrs
        .getDueCards(deck, _sessionStart)
        .map((c) => deck.indexWhere((d) => d.vocabId == c.vocabId))
        .where((i) => i >= 0)
        .toList();
  }

  bool get isComplete => queueIdx >= queue.length;
  VocabItem get currentVocab => vocab[queue[queueIdx]];
  FSRSCard get currentCard => deck[queue[queueIdx]];

  /// Log session start event.
  Future<void> startSession() async {
    await analytics.logEvent(EngQuestEvent.sessionStart, parameters: {
      EngQuestParam.moduleType: 'battle',
      EngQuestParam.wordsPracticed: 0,
    });
  }

  /// Show card and log the event.
  Future<void> showCard() async {
    await analytics.logBattleCardShown(
      wordId: currentVocab.id,
      cefrLevel: currentVocab.cefrLevel,
    );
  }

  /// Grade card, update FSRS state, log the answer event.
  Future<FSRSCard> gradeAndLog(Grade grade, {int latencyMs = 1200}) async {
    final now = DateTime.now();
    final before = currentCard;
    final after = fsrs.schedule(before, grade, now);
    deck[queue[queueIdx]] = after;

    await analytics.logBattleAnswer(
      wordId: before.vocabId,
      grade: grade.index1,
      latencyMs: latencyMs,
    );

    if (after.state == CardState.learning || after.state == CardState.relearning) {
      final insertAt = (queueIdx + 3).clamp(0, queue.length);
      queue.insert(insertAt, queue[queueIdx]);
    }
    queueIdx++;
    return after;
  }

  /// Complete session and log summary.
  Future<void> completeSession(int wordsPracticed, double accuracy) async {
    final durationSec =
        DateTime.now().difference(_sessionStart).inSeconds;
    await analytics.logBattleSessionComplete(
      wordsPracticed: wordsPracticed,
      accuracy: accuracy,
    );
    await analytics.logEvent(EngQuestEvent.sessionEnd, parameters: {
      EngQuestParam.sessionDurationSec: durationSec,
      EngQuestParam.moduleType: 'battle',
    });
  }
}

// ---------------------------------------------------------------------------
// Convenience extension to expose logEvent on AnalyticsService
// ---------------------------------------------------------------------------

extension AnalyticsServiceTestExt on AnalyticsService {
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) async {
    await sink.logEvent(name, parameters: parameters);
  }
}

// ---------------------------------------------------------------------------
// Test data
// ---------------------------------------------------------------------------

const _testVocab = [
  VocabItem(
    id: 'a001', word: 'cat', reading: 'キャット', jpTranslation: 'ねこ',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],
    exampleSentences: ['I have a cat.'],
  ),
  VocabItem(
    id: 'a002', word: 'dog', reading: 'ドッグ', jpTranslation: 'いぬ',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],
    exampleSentences: ['My dog is big.'],
  ),
  VocabItem(
    id: 'a003', word: 'apple', reading: 'アップル', jpTranslation: 'りんご',
    cefrLevel: 'A1', eikenLevel: '5', pos: ['noun'],
    exampleSentences: ['I eat an apple.'],
  ),
];

// ---------------------------------------------------------------------------
// Integration tests
// ---------------------------------------------------------------------------

void main() {
  late SpySink spy;
  late AnalyticsService analytics;

  setUp(() {
    spy = SpySink();
    analytics = AnalyticsService(sink: spy);
  });

  group('Session lifecycle events', () {
    test('session start event is fired', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      expect(spy.hasEvent(EngQuestEvent.sessionStart), isTrue);
    });

    test('session start event includes module_type=battle', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      final params = spy.paramsFor(EngQuestEvent.sessionStart);
      expect(params?[EngQuestParam.moduleType], equals('battle'));
    });

    test('session end event is fired on complete', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      await session.completeSession(3, 0.9);
      expect(spy.hasEvent(EngQuestEvent.sessionEnd), isTrue);
    });
  });

  group('Card shown events', () {
    test('battleCardShown fired once per card', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      for (var i = 0; i < _testVocab.length; i++) {
        if (session.isComplete) break;
        await session.showCard();
        await session.gradeAndLog(Grade.good);
      }
      expect(spy.countEvent(EngQuestEvent.battleCardShown), equals(_testVocab.length));
    });

    test('battleCardShown includes word_id and cefr_level', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.showCard();
      final params = spy.paramsFor(EngQuestEvent.battleCardShown);
      expect(params?[EngQuestParam.wordId], isNotNull);
      expect(params?[EngQuestParam.cefrLevel], equals('A1'));
    });
  });

  group('Card answer events', () {
    test('battleCardAnswered fired once per grade', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      for (var i = 0; i < _testVocab.length; i++) {
        if (session.isComplete) break;
        await session.showCard();
        await session.gradeAndLog(Grade.good);
      }
      expect(
        spy.countEvent(EngQuestEvent.battleCardAnswered),
        equals(_testVocab.length),
      );
    });

    test('battleCardAnswered includes grade and latency_ms', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.showCard();
      await session.gradeAndLog(Grade.easy, latencyMs: 850);
      final params = spy.paramsFor(EngQuestEvent.battleCardAnswered);
      expect(params?[EngQuestParam.grade], equals(Grade.easy.index1)); // 4
      expect(params?[EngQuestParam.latencyMs], equals(850));
    });

    test('grade values map correctly to 1-4 scale', () async {
      for (final grade in Grade.values) {
        spy.reset();
        final session = InstrumentedBattleSession([_testVocab.first], analytics);
        await session.gradeAndLog(grade);
        final params = spy.paramsFor(EngQuestEvent.battleCardAnswered);
        expect(params?[EngQuestParam.grade], equals(grade.index1));
      }
    });
  });

  group('Session complete event', () {
    test('battleSessionComplete fired with correct wordsPracticed', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      var graded = 0;
      for (var i = 0; i < _testVocab.length; i++) {
        if (session.isComplete) break;
        await session.showCard();
        await session.gradeAndLog(Grade.good);
        graded++;
      }
      await session.completeSession(graded, graded / _testVocab.length);
      expect(spy.hasEvent(EngQuestEvent.battleSessionComplete), isTrue);
      final params = spy.paramsFor(EngQuestEvent.battleSessionComplete);
      expect(params?[EngQuestParam.wordsPracticed], equals(graded));
    });

    test('accuracy parameter is within 0.0–1.0', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.completeSession(3, 0.8);
      final params = spy.paramsFor(EngQuestEvent.battleSessionComplete);
      final accuracy = params?[EngQuestParam.accuracy] as double;
      expect(accuracy, greaterThanOrEqualTo(0.0));
      expect(accuracy, lessThanOrEqualTo(1.0));
    });
  });

  group('A/B group assignment', () {
    test('AB group assignment event is fired', () async {
      await analytics.assignAndLogAbGroup(uid: 'user_001', experimentId: 'anki_vs_engquest');
      expect(spy.hasEvent(EngQuestEvent.abGroupAssigned), isTrue);
    });

    test('assignment returns treatment or control group', () async {
      final assignment = await analytics.assignAndLogAbGroup(
        uid: 'user_001',
        experimentId: 'anki_vs_engquest',
      );
      expect(
        [AbGroup.treatment, AbGroup.control].contains(assignment.group),
        isTrue,
      );
    });

    test('same uid always gets same group (deterministic)', () async {
      final a1 = await analytics.assignAndLogAbGroup(
        uid: 'user_stable', experimentId: 'test_exp');
      spy.reset();
      final a2 = await analytics.assignAndLogAbGroup(
        uid: 'user_stable', experimentId: 'test_exp');
      expect(a1.group, equals(a2.group));
    });

    test('user property is set for the experiment', () async {
      await analytics.assignAndLogAbGroup(
        uid: 'user_prop_test', experimentId: 'anki_vs_engquest');
      expect(spy.userProperties.containsKey('ab_anki_vs_engquest'), isTrue);
    });

    test('A/B split is approximately 50/50 over 100 users', () async {
      var treatmentCount = 0;
      for (var i = 0; i < 100; i++) {
        spy.reset();
        final a = AnalyticsService(sink: spy);
        final result = await a.assignAndLogAbGroup(
          uid: 'user_$i',
          experimentId: 'split_test',
        );
        if (result.group == AbGroup.treatment) treatmentCount++;
      }
      // Expect between 30 and 70 treatment assignments (loose bounds for hash distribution)
      expect(treatmentCount, greaterThanOrEqualTo(30));
      expect(treatmentCount, lessThanOrEqualTo(70));
    });
  });

  group('Full battle session analytics flow', () {
    test('complete session fires all required event types', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);

      // 1. Session start
      await session.startSession();

      // 2. Show + grade each card
      var graded = 0;
      while (!session.isComplete) {
        await session.showCard();
        await session.gradeAndLog(Grade.good, latencyMs: 1000 + graded * 100);
        graded++;
      }

      // 3. Session complete
      await session.completeSession(graded, 1.0);

      // Verify all event types present
      expect(spy.hasEvent(EngQuestEvent.sessionStart), isTrue,
          reason: 'session_start missing');
      expect(spy.hasEvent(EngQuestEvent.battleCardShown), isTrue,
          reason: 'battle_card_shown missing');
      expect(spy.hasEvent(EngQuestEvent.battleCardAnswered), isTrue,
          reason: 'battle_card_answered missing');
      expect(spy.hasEvent(EngQuestEvent.battleSessionComplete), isTrue,
          reason: 'battle_session_complete missing');
      expect(spy.hasEvent(EngQuestEvent.sessionEnd), isTrue,
          reason: 'session_end missing');
    });

    test('event count matches expected for 3-card session', () async {
      final session = InstrumentedBattleSession(_testVocab, analytics);
      await session.startSession();
      while (!session.isComplete) {
        await session.showCard();
        await session.gradeAndLog(Grade.good);
      }
      await session.completeSession(3, 1.0);

      expect(spy.countEvent(EngQuestEvent.sessionStart), equals(1));
      expect(spy.countEvent(EngQuestEvent.battleCardShown), equals(3));
      expect(spy.countEvent(EngQuestEvent.battleCardAnswered), equals(3));
      expect(spy.countEvent(EngQuestEvent.battleSessionComplete), equals(1));
      expect(spy.countEvent(EngQuestEvent.sessionEnd), equals(1));
    });
  });
}
