// lib/core/gamification/achievement.dart
// ENG Quest — Achievement / Badge definitions (T06)
//
// Defines achievement types and their unlock criteria.
// Each achievement has a unique id, display info, and a numeric target.
// Progress is tracked as an integer (e.g. words mastered, streak days).

import 'package:flutter/material.dart';

/// Categories of achievements.
enum AchievementCategory {
  mastery,   // word mastery milestones
  streak,    // consecutive day streaks
  practice,  // total practice sessions / words practiced
  level,     // XP level milestones
}

/// Static definition of an achievement badge.
class AchievementDef {
  final String id;
  final String titleJa;
  final String titleEn;
  final String descriptionJa;
  final IconData icon;
  final AchievementCategory category;
  /// The numeric target to unlock (e.g. 10 words, 7 days).
  final int target;
  /// Gradient colors for the badge card.
  final List<Color> gradient;

  const AchievementDef({
    required this.id,
    required this.titleJa,
    required this.titleEn,
    required this.descriptionJa,
    required this.icon,
    required this.category,
    required this.target,
    required this.gradient,
  });
}

/// Runtime state of a player's achievement.
class AchievementState {
  final String achievementId;
  final int progress;
  final bool unlocked;
  final DateTime? unlockedAt;

  const AchievementState({
    required this.achievementId,
    required this.progress,
    required this.unlocked,
    this.unlockedAt,
  });

  AchievementState copyWith({
    int? progress,
    bool? unlocked,
    DateTime? unlockedAt,
  }) =>
      AchievementState(
        achievementId: achievementId,
        progress: progress ?? this.progress,
        unlocked: unlocked ?? this.unlocked,
        unlockedAt: unlockedAt ?? this.unlockedAt,
      );

  Map<String, dynamic> toFirestore() => {
        'progress': progress,
        'unlocked': unlocked,
        if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
      };

  factory AchievementState.fromFirestore(
      String id, Map<String, dynamic> data) {
    DateTime? parsedDate;
    final raw = data['unlockedAt'];
    if (raw is String) {
      parsedDate = DateTime.tryParse(raw);
    }
    return AchievementState(
      achievementId: id,
      progress: (data['progress'] as num? ?? 0).toInt(),
      unlocked: data['unlocked'] as bool? ?? false,
      unlockedAt: parsedDate,
    );
  }

  factory AchievementState.empty(String id) => AchievementState(
        achievementId: id,
        progress: 0,
        unlocked: false,
      );
}

// ── Achievement catalog ───────────────────────────────────────────────────────

/// All achievements in the game, ordered by category and difficulty.
const List<AchievementDef> kAchievements = [
  // ── Mastery ──
  AchievementDef(
    id: 'mastery_10',
    titleJa: 'ことばの冒険者',
    titleEn: 'Word Explorer',
    descriptionJa: '10個の単語をマスターしよう',
    icon: Icons.auto_stories,
    category: AchievementCategory.mastery,
    target: 10,
    gradient: [Color(0xFF43A047), Color(0xFF2E7D32)],
  ),
  AchievementDef(
    id: 'mastery_50',
    titleJa: 'ことばの騎士',
    titleEn: 'Word Knight',
    descriptionJa: '50個の単語をマスターしよう',
    icon: Icons.shield,
    category: AchievementCategory.mastery,
    target: 50,
    gradient: [Color(0xFF1E88E5), Color(0xFF1565C0)],
  ),
  AchievementDef(
    id: 'mastery_100',
    titleJa: 'ことばの魔法使い',
    titleEn: 'Word Wizard',
    descriptionJa: '100個の単語をマスターしよう',
    icon: Icons.auto_fix_high,
    category: AchievementCategory.mastery,
    target: 100,
    gradient: [Color(0xFF8E24AA), Color(0xFF6A1B9A)],
  ),
  AchievementDef(
    id: 'mastery_200',
    titleJa: 'ことばの王さま',
    titleEn: 'Word King',
    descriptionJa: '200個の単語をマスターしよう',
    icon: Icons.workspace_premium,
    category: AchievementCategory.mastery,
    target: 200,
    gradient: [Color(0xFFFF8F00), Color(0xFFE65100)],
  ),

  // ── Streak ──
  AchievementDef(
    id: 'streak_3',
    titleJa: 'まいにちの炎',
    titleEn: 'Daily Flame',
    descriptionJa: '3日連続で練習しよう',
    icon: Icons.local_fire_department,
    category: AchievementCategory.streak,
    target: 3,
    gradient: [Color(0xFFFF7043), Color(0xFFE64A19)],
  ),
  AchievementDef(
    id: 'streak_7',
    titleJa: '一週間の戦士',
    titleEn: 'Week Warrior',
    descriptionJa: '7日連続で練習しよう',
    icon: Icons.whatshot,
    category: AchievementCategory.streak,
    target: 7,
    gradient: [Color(0xFFFF5722), Color(0xFFBF360C)],
  ),
  AchievementDef(
    id: 'streak_10',
    titleJa: '炎のチャンピオン',
    titleEn: 'Flame Champion',
    descriptionJa: '10日連続で練習しよう',
    icon: Icons.emoji_events,
    category: AchievementCategory.streak,
    target: 10,
    gradient: [Color(0xFFD50000), Color(0xFF9B0000)],
  ),

  // ── Practice ──
  AchievementDef(
    id: 'practice_50',
    titleJa: 'はじめの一歩',
    titleEn: 'First Steps',
    descriptionJa: '50回カードを練習しよう',
    icon: Icons.directions_walk,
    category: AchievementCategory.practice,
    target: 50,
    gradient: [Color(0xFF26A69A), Color(0xFF00796B)],
  ),
  AchievementDef(
    id: 'practice_200',
    titleJa: 'たゆまぬ努力',
    titleEn: 'Tireless Effort',
    descriptionJa: '200回カードを練習しよう',
    icon: Icons.fitness_center,
    category: AchievementCategory.practice,
    target: 200,
    gradient: [Color(0xFF5C6BC0), Color(0xFF3949AB)],
  ),
  AchievementDef(
    id: 'practice_500',
    titleJa: '練習の達人',
    titleEn: 'Practice Master',
    descriptionJa: '500回カードを練習しよう',
    icon: Icons.military_tech,
    category: AchievementCategory.practice,
    target: 500,
    gradient: [Color(0xFFAB47BC), Color(0xFF7B1FA2)],
  ),

  // ── Level ──
  AchievementDef(
    id: 'level_3',
    titleJa: 'レベル3到達',
    titleEn: 'Level 3',
    descriptionJa: 'レベル3に到達しよう',
    icon: Icons.trending_up,
    category: AchievementCategory.level,
    target: 3,
    gradient: [Color(0xFF66BB6A), Color(0xFF388E3C)],
  ),
  AchievementDef(
    id: 'level_5',
    titleJa: 'レベル5到達',
    titleEn: 'Level 5',
    descriptionJa: 'レベル5に到達しよう',
    icon: Icons.star,
    category: AchievementCategory.level,
    target: 5,
    gradient: [Color(0xFFFFA726), Color(0xFFF57C00)],
  ),
];

/// Lookup a definition by id.
AchievementDef? achievementDefById(String id) {
  for (final def in kAchievements) {
    if (def.id == id) return def;
  }
  return null;
}
