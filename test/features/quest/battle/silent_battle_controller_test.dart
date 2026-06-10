// test/features/quest/battle/silent_battle_controller_test.dart
//
// Unit tests for SilentBattleController + BattleRewards.
//
// Assertions per spec:
//   1. Correct cast drops しずけさ meter.
//   2. On victory, total XP awarded > 0 (PROVES the XP=0 bug is fixed).
//   3. Wrong QUIZ cast costs a heart.
//   4. Wrong TEACH cast does NOT cost a heart (no-scold contract).
//   5. 0 hearts → defeat phase; retreat keeps shards.
//   6. Victory fires reward glue exactly once.

import 'package:engquest/core/fsrs/fsrs_card.dart';
import 'package:engquest/core/fsrs/fsrs_card_repository.dart';
import 'package:engquest/core/gamification/xp_profile.dart';
import 'package:engquest/core/gamification/xp_service.dart';
import 'package:engquest/features/home/streak_service.dart';
import 'package:engquest/features/quest/battle/battle_rewards.dart';
import 'package:engquest/features/quest/battle/silent_battle_controller.dart';
import 'package:engquest/features/quest/quest_data.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Minimal stub fixtures
// ─────────────────────────────────────────────────────────────────────────────

// A quiz step (penalizeWrong = true).
const _quizStep = QuestEncounter(
  npcName: 'テスト NPC',
  npcEmoji: '🤖',
  npcLine: 'What is correct?',
  choices: ['correct', 'wrong', 'also wrong'],
  correctIndex: 0,
  onCorrect: 'よくできました！',
);

// A teach step (penalizeWrong = false).
const _teachStep = TeachWord(
  npcName: 'せんせい',
  npcEmoji: '📖',
  word: 'cat',
  teachJa: 'ねこ',
  options: [
    QuestOption(label: 'cat', isCorrect: true),
    QuestOption(label: 'dog', isCorrect: false),
  ],
  onCorrect: 'せいかい！',
);

// Three quiz steps for multi-step tests.
final _threeQuizSteps = [_quizStep, _quizStep, _quizStep];
final _threeOffsets = [0, 1, 2];

SilentBattleController _makeCtrl({
  List<QuestStep>? steps,
  List<int>? offsets,
  int maxHearts = 3,
}) {
  final s = steps ?? [_quizStep];
  final o = offsets ?? List.generate(s.length, (i) => i);
  return SilentBattleController(
    townId: 'town_test',
    steps: s,
    stepOffsets: o,
    maxHearts: maxHearts,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller tests
// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('SilentBattleController — FSM basics', () {
    test('starts in intro phase', () {
      final ctrl = _makeCtrl();
      expect(ctrl.phase, BattlePhase.intro);
    });

    test('startBattle transitions intro → prompt', () {
      final ctrl = _makeCtrl();
      ctrl.startBattle();
      expect(ctrl.phase, BattlePhase.prompt);
    });
  });

  group('SilentBattleController — しずけさ meter', () {
    test('correct cast drops silenceMeter by 1', () {
      final ctrl = _makeCtrl(steps: _threeQuizSteps, offsets: _threeOffsets);
      ctrl.startBattle();
      final before = ctrl.silenceMeter;
      ctrl.castTap(0); // correct (index 0)
      expect(ctrl.silenceMeter, lessThan(before));
    });

    test('silenceMeter reaches 0 on all steps cleared', () {
      final ctrl = _makeCtrl(steps: _threeQuizSteps, offsets: _threeOffsets);
      ctrl.startBattle();
      for (var i = 0; i < _threeQuizSteps.length; i++) {
        ctrl.castTap(0); // correct
        ctrl.advance(); // move to next
      }
      expect(ctrl.phase, BattlePhase.victory);
      expect(ctrl.silenceMeter, 0);
    });
  });

  group('SilentBattleController — こころ hearts (Quiz)', () {
    test('wrong quiz cast costs a heart', () {
      final ctrl = _makeCtrl(maxHearts: 3);
      ctrl.startBattle();
      expect(ctrl.hearts, 3);
      ctrl.castTap(1); // wrong (index 1, correct is 0)
      expect(ctrl.hearts, 2);
    });

    test('three wrong quiz casts → defeat', () {
      final ctrl = _makeCtrl(maxHearts: 3);
      ctrl.startBattle();
      ctrl.castTap(1); // wrong
      ctrl.advance(); // back to prompt
      ctrl.castTap(1); // wrong
      ctrl.advance(); // back to prompt
      ctrl.castTap(1); // wrong → defeat
      expect(ctrl.phase, BattlePhase.defeat);
      expect(ctrl.hearts, 0);
    });
  });

  group('SilentBattleController — no-scold (Teach steps)', () {
    test('wrong teach cast does NOT cost a heart', () {
      final ctrl = _makeCtrl(steps: [_teachStep], offsets: [0]);
      ctrl.startBattle();
      expect(ctrl.hearts, 3);
      final replayKey = ctrl.castTap(1); // wrong option (index 1)
      // No-scold: heart unchanged, phase stays prompt.
      expect(ctrl.hearts, 3);
      expect(ctrl.phase, BattlePhase.prompt);
      // replayKey must be non-null (autoPlayAudio may be null in test stub, but
      // the field is set from step.autoPlayAudio which is null for this stub).
      // The important assertion is hearts unchanged.
      expect(replayKey, isNull); // autoPlayAudio is null on _teachStep stub
    });

    test('wrong teach cast keeps phase in prompt', () {
      final ctrl = _makeCtrl(steps: [_teachStep], offsets: [0]);
      ctrl.startBattle();
      ctrl.castTap(1); // wrong
      expect(ctrl.phase, BattlePhase.prompt);
    });
  });

  group('SilentBattleController — defeat keeps shards', () {
    test('shards accumulated before defeat are preserved', () {
      // Two steps: first correct (earns a shard), second wrong x3 → defeat.
      final ctrl = _makeCtrl(
        steps: [_quizStep, _quizStep],
        offsets: [0, 1],
        maxHearts: 1, // 1 heart: one wrong = defeat
      );
      ctrl.startBattle();
      // Step 0: correct → shard earned.
      ctrl.castTap(0);
      ctrl.advance(); // next step
      // Step 1: wrong → defeat.
      ctrl.castTap(1);
      expect(ctrl.phase, BattlePhase.defeat);
      expect(ctrl.shards, 1); // shard from step 0 is kept
    });

    test('reset after defeat restores hearts and clears results', () {
      final ctrl = _makeCtrl(maxHearts: 1);
      ctrl.startBattle();
      ctrl.castTap(1); // wrong → defeat
      expect(ctrl.phase, BattlePhase.defeat);
      ctrl.reset();
      expect(ctrl.phase, BattlePhase.intro);
      expect(ctrl.hearts, ctrl.maxHeartsValue);
      expect(ctrl.shards, 0);
      expect(ctrl.stepResults, isEmpty);
    });
  });

  group('SilentBattleController — grade derivation', () {
    test('first-try correct → Grade.good', () {
      final ctrl = _makeCtrl();
      ctrl.startBattle();
      ctrl.castTap(0); // correct on first attempt
      expect(ctrl.stepResults.first.grade, Grade.good);
    });

    test('correct after wrong (teach no-scold) → Grade.hard', () {
      // Use a quiz step so wrong tap counts attempts correctly.
      // But for a quiz step, wrong costs a heart. Use 5 hearts to stay alive.
      final ctrl = _makeCtrl(steps: [_quizStep], offsets: [0], maxHearts: 5);
      ctrl.startBattle();
      ctrl.castTap(1); // wrong → costs heart, phase=resolved
      ctrl.advance(); // back to prompt
      ctrl.castTap(0); // correct on second attempt
      expect(ctrl.stepResults.last.grade, Grade.hard);
    });

    test('defeated step gets Grade.again', () {
      final ctrl = _makeCtrl(maxHearts: 1);
      ctrl.startBattle();
      ctrl.castTap(1); // wrong → defeat
      expect(ctrl.stepResults.last.grade, Grade.again);
    });
  });

  group('SilentBattleController — combo', () {
    test('combo increments on first-try correct', () {
      final ctrl = _makeCtrl(steps: _threeQuizSteps, offsets: _threeOffsets);
      ctrl.startBattle();
      ctrl.castTap(0); // correct first try
      expect(ctrl.combo, 1);
      ctrl.advance();
      ctrl.castTap(0);
      expect(ctrl.combo, 2);
    });

    test('combo does not increment on second-try correct', () {
      final ctrl = _makeCtrl(steps: [_quizStep], offsets: [0], maxHearts: 5);
      ctrl.startBattle();
      ctrl.castTap(1); // wrong
      ctrl.advance();
      ctrl.castTap(0); // correct on second try
      expect(ctrl.combo, 0); // no combo for second-try
    });
  });

  group('BattleRewards — XP > 0 on victory (bug fix proof)', () {
    test('victory with Grade.good steps awards XP > 0', () async {
      final results = [
        StepResult(
            stepIndex: 0, grade: Grade.good, cardId: 'town_test__step_0'),
        StepResult(
            stepIndex: 1, grade: Grade.good, cardId: 'town_test__step_1'),
      ];

      final totalXp = BattleRewards.totalXp(results);
      expect(totalXp, greaterThan(0),
          reason: 'Victory with Grade.good must award positive XP');
      // Grade.good = 10 XP × 2 steps = 20.
      expect(totalXp, 20);
    });

    test('victory with mixed grades awards correct XP', () {
      final results = [
        StepResult(stepIndex: 0, grade: Grade.easy, cardId: 'id_0'), // 15
        StepResult(stepIndex: 1, grade: Grade.hard, cardId: 'id_1'), // 5
        StepResult(stepIndex: 2, grade: Grade.again, cardId: 'id_2'), // 0
      ];
      expect(BattleRewards.totalXp(results), 20);
    });

    test('applyRewards calls FSRS.saveCard and StreakService exactly once',
        () async {
      final repo = InMemoryFsrsCardRepository();
      int streakCalls = 0;
      int xpCalls = 0;

      final rewards = BattleRewards(
        repository: repo,
        xpService: _StubXpService(onAward: () => xpCalls++),
        streakService: _StubStreakService(onRecord: () => streakCalls++),
        nowProvider: () => DateTime(2026, 6, 5),
      );

      final results = [
        StepResult(stepIndex: 0, grade: Grade.good, cardId: 'town_x__step_0'),
        StepResult(stepIndex: 1, grade: Grade.good, cardId: 'town_x__step_1'),
      ];

      await rewards.applyRewards(uid: 'test_uid', stepResults: results);

      // 2 cards saved.
      final saved = await repo.loadDeck('test_uid');
      expect(saved.length, 2);

      // Streak recorded exactly once.
      expect(streakCalls, 1);

      // XP awarded twice (once per step).
      expect(xpCalls, 2);
    });
  });

  group('sliceBattles', () {
    test('slices 12 steps into 3 battles of 4', () {
      final steps = List.filled(12, _quizStep);
      final slices = sliceBattles(steps, sliceSize: 4);
      expect(slices.length, 3);
      for (final s in slices) {
        expect(s.steps.length, 4);
      }
    });

    test('slices 5 steps into [4, 1]', () {
      final steps = List.filled(5, _quizStep);
      final slices = sliceBattles(steps, sliceSize: 4);
      expect(slices.length, 2);
      expect(slices[0].steps.length, 4);
      expect(slices[1].steps.length, 1);
    });

    test('offsets are consecutive indices', () {
      final steps = List.filled(6, _quizStep);
      final slices = sliceBattles(steps, sliceSize: 4);
      expect(slices[0].offsets, [0, 1, 2, 3]);
      expect(slices[1].offsets, [4, 5]);
    });
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Stubs
// ─────────────────────────────────────────────────────────────────────────────

// Stub XpService: uses FakeFirebaseFirestore so no real Firebase initialisation
// is required. Overrides awardXp/awardXpBatch to track call counts.
class _StubXpService extends XpService {
  final void Function() onAward;

  _StubXpService({required this.onAward})
      : super(firestore: FakeFirebaseFirestore());

  @override
  Future<XpAwardResult> awardXp(String uid, Grade grade) async {
    onAward();
    return XpAwardResult(
      xpGained: 10,
      before: XpProfile.zero(uid),
      after: XpProfile.zero(uid),
    );
  }

  @override
  Future<XpAwardResult> awardXpBatch(String uid, List<Grade> grades) async {
    for (final g in grades) {
      await awardXp(uid, g);
    }
    return XpAwardResult(
      xpGained: 10,
      before: XpProfile.zero(uid),
      after: XpProfile.zero(uid),
    );
  }
}

class _StubStreakService extends StreakService {
  final void Function() onRecord;
  _StubStreakService({required this.onRecord});

  @override
  Future<StreakState> recordStudySession() async {
    onRecord();
    return const StreakState.zero();
  }
}
