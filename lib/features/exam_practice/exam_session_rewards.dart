// lib/features/exam_practice/exam_session_rewards.dart
// ENG Quest — end-of-exam-session achievement detection.
//
// Why this exists: AchievementService.checkAndUpdate used to be called ONLY
// from the vocab battle, so a child who reaches a streak / level milestone
// during 英検 exam practice — the primary 英検-prep path — unlocked nothing at
// that moment (it was only noticed lazily the next time they opened the
// achievements screen, with no celebration). This fire-and-forget helper runs
// the check at the end of every exam-practice session with the stats that
// surface genuinely advances (current streak + current level); the unlock is
// then broadcast via AchievementService.unlockEvents and celebrated app-wide by
// AchievementUnlockHost (app.dart).
//
// Mastery / practice counts are battle/FSRS-domain and passed as 0 here —
// checkAndUpdate's progress is monotonic, so a 0 never regresses a stored value
// nor falsely unlocks those categories. Lives in the feature layer (not core) so
// it can depend on StreakService without pulling Firebase into core.
import '../../core/firebase/auth_service.dart';
import '../../core/gamification/achievement_service.dart';
import '../../core/gamification/xp_service.dart';
import '../home/streak_service.dart';

/// Detects (and broadcasts) any achievement unlocked by this session's streak
/// or level. Fire-and-forget; all errors (offline / Firebase down) are swallowed
/// so it never blocks or crashes the exam flow.
void recordExamAchievements() {
  () async {
    try {
      final uid = await AuthService().resolveUid();
      final streak = (await StreakService().load()).currentStreak;
      final level = (await XpService().init(uid)).level;
      await AchievementService().checkAndUpdate(
        uid: uid,
        totalMastered: 0, // battle/FSRS-domain; monotonic → never regresses
        currentStreak: streak,
        totalPracticed: 0, // battle-domain; monotonic → never regresses
        level: level,
      );
    } catch (_) {
      // Non-fatal: achievements re-check next session / on the achievements screen.
    }
  }();
}
