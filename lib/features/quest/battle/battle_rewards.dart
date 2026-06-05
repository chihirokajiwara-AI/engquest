// lib/features/quest/battle/battle_rewards.dart
//
// Applies XP, FSRS, and streak rewards after a victorious battle.
//
// Pattern mirrors battle_screen.dart's _gradeCard / _recordSessionToFirestore
// exactly — lifted here so the Quest loop gets the SAME wiring.
//
// Inject dependencies for testability; production callers use default singletons.

import '../../../core/fsrs/fsrs_algorithm.dart';
import '../../../core/fsrs/fsrs_card.dart';
import '../../../core/fsrs/fsrs_card_repository.dart';
import '../../../core/gamification/xp_service.dart';
import '../../../features/home/streak_service.dart';
import 'silent_battle_controller.dart';

class BattleRewards {
  final FsrsCardRepository repository;
  final XpService xpService;
  final StreakService streakService;
  final FSRSAlgorithm fsrs;
  final DateTime Function() nowProvider;

  BattleRewards({
    required this.repository,
    required this.xpService,
    required this.streakService,
    FSRSAlgorithm? fsrsAlgorithm,
    DateTime Function()? nowProvider,
  })  : fsrs = fsrsAlgorithm ?? FSRSAlgorithm(),
        nowProvider = nowProvider ?? DateTime.now;

  /// Apply all rewards for a victorious battle.
  ///
  /// [uid] — the player's uid (may be 'offline_user' if Firebase unavailable).
  /// [stepResults] — from [SilentBattleController.stepResults].
  ///
  /// Fires FSRS.schedule → repository.saveCard for each step, awards XP per
  /// grade, and records one streak session. Fire-and-forget errors are swallowed
  /// (offline Firestore cache handles sync).
  Future<void> applyRewards({
    required String uid,
    required List<StepResult> stepResults,
  }) async {
    if (stepResults.isEmpty) return;

    final now = nowProvider();
    final grades = stepResults.map((r) => r.grade).toList();

    // 1. XP — award per grade (mirrors battle_screen._gradeCard pattern).
    try {
      await xpService.awardXpBatch(uid, grades);
    } catch (_) {
      // Non-fatal: offline writes queued by Firestore SDK.
    }

    // 2. FSRS — schedule and persist one card per step result.
    for (final result in stepResults) {
      final card = FSRSCard(vocabId: result.cardId);
      final updated = fsrs.schedule(card, result.grade, now);
      try {
        await repository.saveCard(uid, updated);
      } catch (_) {
        // Non-fatal: Firestore offline cache.
      }
    }

    // 3. Streak — record one study session (regardless of step count).
    try {
      await streakService.recordStudySession();
    } catch (_) {
      // Non-fatal: SharedPreferences failure is rare.
    }
  }

  /// Compute the total XP that will be awarded for [stepResults].
  /// Exposed for display in the victory screen before [applyRewards] is called.
  static int totalXp(List<StepResult> stepResults) {
    const xpMap = {'again': 0, 'hard': 5, 'good': 10, 'easy': 15};
    return stepResults.fold(
        0, (sum, r) => sum + (xpMap[r.grade.name.toLowerCase()] ?? 0));
  }
}
