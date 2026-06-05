// lib/features/quest/battle/silent_battle_controller.dart
//
// PURE DART — no Flutter/dart:io imports. Safe on web.
//
// サイレントバトル FSM: one "villager" = a 3–5 step slice of a QuestTown.
//
// Narrative frame:
//   サイレントが ○○を つつんでいる。ことばを となえて！
//   (The Silence surrounds ○○. Cast the word!)
//
// State machine phases:
//   intro    — battle about to begin (caller can show dialogue)
//   prompt   — waiting for the player to tap an option
//   resolved — option evaluated; caller shows feedback before calling advance()
//   victory  — all steps cleared
//   defeat   — hearts reached 0 (retreat, keep shards)
//
// XP/FSRS grade per step:
//   first-try correct → Grade.good
//   correct after retry → Grade.hard
//   step wrong when hearts run out (defeat with a step unresolved) → Grade.again
//
// No-scold contract:
//   penalizeWrong == false (teach/blend/word/phrase): wrong tap = replay only,
//   never lose a heart. This is load-bearing UX — do NOT relax it.

import 'package:flutter/foundation.dart';

import '../../../core/fsrs/fsrs_card.dart';
import '../quest_data.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public types
// ─────────────────────────────────────────────────────────────────────────────

enum BattlePhase { intro, prompt, resolved, victory, defeat }

/// Outcome of one step after the battle resolves.
class StepResult {
  /// The step index in the battle's [steps] list.
  final int stepIndex;

  /// FSRS grade for this step.
  final Grade grade;

  /// Card id keyed as `townId__step_N` (N = step's index in the full town).
  final String cardId;

  const StepResult({
    required this.stepIndex,
    required this.grade,
    required this.cardId,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Controller
// ─────────────────────────────────────────────────────────────────────────────

class SilentBattleController extends ChangeNotifier {
  // Construction
  final String townId;
  final List<QuestStep> steps; // 3–5 steps for this villager
  final List<int> stepOffsets; // index of each step in the full town encounters

  // Configurable but defaulted
  final int maxHearts;

  SilentBattleController({
    required this.townId,
    required this.steps,
    required this.stepOffsets,
    this.maxHearts = 3,
  })  : assert(steps.isNotEmpty),
        assert(steps.length == stepOffsets.length),
        _hearts = maxHearts;

  // ── FSM state ────────────────────────────────────────────────────────────
  BattlePhase _phase = BattlePhase.intro;
  BattlePhase get phase => _phase;

  int _currentIndex = 0;
  int get currentIndex => _currentIndex;

  QuestStep get currentStep => steps[_currentIndex];

  // Hearts: lose one per penalizeWrong wrong answer.
  int _hearts;
  int get hearts => _hearts;
  int get maxHeartsValue => maxHearts;

  // チャージ (combo multiplier): increments on each first-try correct answer.
  int _combo = 0;
  int get combo => _combo;

  // 声のかけら shards accumulated in this battle.
  int _shards = 0;
  int get shards => _shards;

  // しずけさ meter: starts at steps.length, drops by 1 per cleared step.
  // Semantics: "remaining silence" — reaching 0 = town restored.
  int get silenceMeter => steps.length - _clearedSteps;
  int _clearedSteps = 0;

  /// Number of steps cleared so far. Used by the UI to compute colour-reveal
  /// progress (grey→colour portrait).
  int get clearedSteps => _clearedSteps;

  // Per-step attempt tracking (for grade derivation).
  int _attemptsOnCurrent = 0;

  // Step results collected as we go.
  final List<StepResult> _stepResults = [];
  List<StepResult> get stepResults => List.unmodifiable(_stepResults);

  // Last evaluated option (for UI highlight).
  int? _lastPicked;
  int? get lastPicked => _lastPicked;

  // True when lastPicked was correct.
  bool _lastWasCorrect = false;
  bool get lastWasCorrect => _lastWasCorrect;

  // Audio cue key to replay on wrong teach-step (null = nothing to replay).
  // The UI should call AudioCueService.play(replayAudioKey) after castTap returns.
  String? _replayAudioKey;
  String? get replayAudioKey => _replayAudioKey;

  // ─────────────────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────────────────

  /// Start the battle (transition intro → prompt).
  void startBattle() {
    assert(_phase == BattlePhase.intro);
    _phase = BattlePhase.prompt;
    _attemptsOnCurrent = 0;
    _replayAudioKey = null;
    notifyListeners();
  }

  /// Player taps option [optionIndex].
  ///
  /// Returns the audio asset key the UI should replay if this is a no-scold
  /// wrong tap (teach/blend/word/phrase), or null otherwise.
  ///
  /// Phase transitions:
  ///   correct → resolved (UI shows onCorrect text; call advance() to proceed)
  ///   wrong + penalizeWrong → resolved (hearts may drop → defeat)
  ///   wrong + !penalizeWrong → stays in prompt (UI replays audio, no red)
  String? castTap(int optionIndex) {
    if (_phase != BattlePhase.prompt) return null;

    final step = currentStep;
    final correct = optionIndex == step.correctIndex;
    _lastPicked = optionIndex;
    _attemptsOnCurrent++;

    if (correct) {
      _lastWasCorrect = true;
      _replayAudioKey = null;

      // Grade: first attempt = good, subsequent = hard.
      final grade = _attemptsOnCurrent == 1 ? Grade.good : Grade.hard;
      final cardId = '${townId}__step_${stepOffsets[_currentIndex]}';
      _stepResults.add(StepResult(
        stepIndex: _currentIndex,
        grade: grade,
        cardId: cardId,
      ));

      _clearedSteps++;
      _shards++;
      // Combo only on first-try correct.
      if (_attemptsOnCurrent == 1) _combo++;

      _phase = BattlePhase.resolved;
      notifyListeners();
      return null;
    }

    // Wrong tap —
    if (!step.penalizeWrong) {
      // NO-SCOLD contract: teach/blend/word/phrase → replay audio, stay prompt.
      _lastWasCorrect = false;
      _replayAudioKey = step.autoPlayAudio;
      notifyListeners();
      return _replayAudioKey;
    }

    // Quiz step (penalizeWrong): lose a heart.
    _lastWasCorrect = false;
    _replayAudioKey = null;
    _hearts = (_hearts - 1).clamp(0, maxHearts);

    if (_hearts == 0) {
      // Defeat: record this step as Grade.again.
      final cardId = '${townId}__step_${stepOffsets[_currentIndex]}';
      _stepResults.add(StepResult(
        stepIndex: _currentIndex,
        grade: Grade.again,
        cardId: cardId,
      ));
      _phase = BattlePhase.defeat;
      notifyListeners();
      return null;
    }

    // Hearts remain: show wrong state briefly, stay in prompt.
    _phase = BattlePhase.resolved;
    notifyListeners();
    return null;
  }

  /// After showing the resolved feedback, advance to the next step or end.
  /// Only valid when phase == resolved.
  void advance() {
    assert(_phase == BattlePhase.resolved);

    if (!_lastWasCorrect) {
      // Wrong on a quiz but hearts remain: back to prompt for the same step.
      _phase = BattlePhase.prompt;
      _lastPicked = null;
      notifyListeners();
      return;
    }

    // Correct: move to next step or declare victory.
    final nextIndex = _currentIndex + 1;
    if (nextIndex >= steps.length) {
      _phase = BattlePhase.victory;
      notifyListeners();
      return;
    }

    _currentIndex = nextIndex;
    _attemptsOnCurrent = 0;
    _lastPicked = null;
    _lastWasCorrect = false;
    _replayAudioKey = null;
    _phase = BattlePhase.prompt;
    notifyListeners();
  }

  /// Reset battle to initial state (replay same steps).
  void reset() {
    _phase = BattlePhase.intro;
    _currentIndex = 0;
    _hearts = maxHearts;
    _combo = 0;
    _shards = 0;
    _clearedSteps = 0;
    _attemptsOnCurrent = 0;
    _stepResults.clear();
    _lastPicked = null;
    _lastWasCorrect = false;
    _replayAudioKey = null;
    notifyListeners();
  }

  /// Retreat (defeat path). Shards accumulated so far are kept.
  void retreat() {
    _phase = BattlePhase.defeat;
    notifyListeners();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Battle slicer
// ─────────────────────────────────────────────────────────────────────────────

/// Splits a town's encounter list into consecutive slices of [sliceSize] steps.
/// The last slice may be smaller. Each slice becomes one "villager" battle.
///
/// Returns a list of `(steps, offsets)` pairs — offsets are the indices of each
/// step in the original [encounters] list (used for stable card IDs).
List<({List<QuestStep> steps, List<int> offsets})> sliceBattles(
  List<QuestStep> encounters, {
  int sliceSize = 4,
}) {
  final result = <({List<QuestStep> steps, List<int> offsets})>[];
  var i = 0;
  while (i < encounters.length) {
    final end = (i + sliceSize).clamp(0, encounters.length);
    result.add((
      steps: encounters.sublist(i, end),
      offsets: List.generate(end - i, (j) => i + j),
    ));
    i = end;
  }
  return result;
}
