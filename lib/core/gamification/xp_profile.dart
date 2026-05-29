// lib/core/gamification/xp_profile.dart
// ENG Quest — XP/Level player profile model
//
// Schema (Firestore: users/{uid}/profile):
//   totalXp     : int    — cumulative XP earned across all sessions
//   level       : int    — current level (1–5+; derived from totalXp)
//   lastUpdated : Timestamp — server timestamp on last write
//
// Level thresholds (matching spec P2-7):
//   Lv.1 :     0 XP
//   Lv.2 :   100 XP
//   Lv.3 :   250 XP
//   Lv.4 :   500 XP
//   Lv.5 : 1,000 XP
//   Lv.6 : 2,000 XP  (extended — prevents ceiling after ~2 months)
//   Lv.7 : 4,000 XP
//   Lv.8 : 7,000 XP

/// XP thresholds for each level (index 0 is unused; Lv.1 starts at index 1).
const List<int> kLevelThresholds = [
  0,     // placeholder (index 0)
  0,     // Lv.1 — start
  100,   // Lv.2
  250,   // Lv.3
  500,   // Lv.4
  1000,  // Lv.5
  2000,  // Lv.6
  4000,  // Lv.7
  7000,  // Lv.8 (max displayed; technically uncapped)
];

/// Max level with a defined threshold.
const int kMaxDefinedLevel = 8;

/// Derives current level from totalXp using [kLevelThresholds].
/// Level ≥ [kMaxDefinedLevel] if XP exceeds the highest threshold.
int levelFromXp(int totalXp) {
  int level = 1;
  for (int i = 2; i < kLevelThresholds.length; i++) {
    if (totalXp >= kLevelThresholds[i]) {
      level = i;
    } else {
      break;
    }
  }
  return level;
}

/// XP required to reach the *next* level from current [level].
/// Returns 9999 if already at max defined level.
int xpToNextLevel(int level) {
  if (level >= kMaxDefinedLevel) return 9999;
  return kLevelThresholds[level + 1];
}

/// XP earned within the current level (for the progress bar).
int xpInCurrentLevel(int totalXp) {
  final level = levelFromXp(totalXp);
  final levelStart = kLevelThresholds[level];
  return totalXp - levelStart;
}

/// XP needed to complete the current level (denominator for progress bar).
int xpNeededForLevel(int level) {
  if (level >= kMaxDefinedLevel) return 9999;
  return kLevelThresholds[level + 1] - kLevelThresholds[level];
}

// ── XP per grade ─────────────────────────────────────────────────────────────

/// XP awarded for each FSRS grade (spec P2-7):
///   Again = 0, Hard = 5, Good = 10, Easy = 15
const Map<String, int> kGradeXp = {
  'again': 0,
  'hard':  5,
  'good':  10,
  'easy':  15,
};

// ── XpProfile model ──────────────────────────────────────────────────────────

/// Immutable snapshot of a player's XP/level state.
class XpProfile {
  final String uid;
  final int totalXp;
  final int level;

  const XpProfile({
    required this.uid,
    required this.totalXp,
    required this.level,
  });

  /// Derived: XP earned within current level (progress bar numerator).
  int get currentLevelXp => xpInCurrentLevel(totalXp);

  /// Derived: XP span of current level (progress bar denominator).
  int get levelXpSpan => xpNeededForLevel(level);

  /// Derived: XP to next level (absolute threshold).
  int get nextLevelThreshold => xpToNextLevel(level);

  /// Derived: 0.0–1.0 progress fraction within current level.
  double get levelProgress {
    if (levelXpSpan == 0 || levelXpSpan == 9999) return 0.0;
    return (currentLevelXp / levelXpSpan).clamp(0.0, 1.0);
  }

  factory XpProfile.zero(String uid) =>
      XpProfile(uid: uid, totalXp: 0, level: 1);

  factory XpProfile.fromFirestore(String uid, Map<String, dynamic> data) {
    final totalXp = (data['totalXp'] as num? ?? 0).toInt();
    return XpProfile(
      uid: uid,
      totalXp: totalXp,
      level: levelFromXp(totalXp),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'totalXp': totalXp,
        'level': level,
      };

  XpProfile copyWith({int? totalXp, int? level}) => XpProfile(
        uid: uid,
        totalXp: totalXp ?? this.totalXp,
        level: level ?? this.level,
      );

  @override
  String toString() =>
      'XpProfile(uid=$uid, level=$level, totalXp=$totalXp, progress=${(levelProgress * 100).round()}%)';
}
