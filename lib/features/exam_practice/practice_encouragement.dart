// lib/features/exam_practice/practice_encouragement.dart
// Shared struggling-child support for the practice screens (CEO 1135 / no-scold
// spine). A child who misses several questions in a row gets a gentle,
// 探偵-framed encouragement — NEVER a scold — that points to that screen's own
// support ([message] is screen-specific: the 大問1 「いみを みる」 hint, listening
// 🔊 replay / captions, etc.). Extracted once the pattern reached 3+ screens so
// the banner + threshold live in one place (the 2-copy stage was intentionally
// inline per the project's "no premature abstraction" rule).
//
// The streak counter lives in each screen's State (a single int reset to 0 on
// any correct answer); this file owns only the shared threshold + the banner UI.

import 'package:flutter/material.dart';

import '../quest/ui/dq_ui.dart';
import '../home/streak_service.dart';

/// Consecutive wrong answers before the gentle encouragement appears.
const int kStruggleThreshold = 3;

/// The gentle, non-scolding cold-streak banner. [message] is screen-specific so
/// the nudge matches that screen's available support.
class PracticeEncouragementBanner extends StatelessWidget {
  final String message;
  const PracticeEncouragementBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dqGold.withAlpha(28),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold.withAlpha(110)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🕵️', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: dqText(size: 13).copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

/// Screen-specific encouragement copy. Kept here so all practice screens share
/// the same warm voice while nudging to their own scaffold.
const String kVocabEncourageMsg = 'なんども まちがえても へいき！ めいたんていも、'
    'しっぱいを ヒントに して 事件（じけん）を とくんだ。\n'
    '「いみを みる」を つかうと、もっと わかるよ。';

const String kListeningEncourageMsg = 'なんども まちがえても へいき！ もう一度（いちど） 🔊 きいたり、'
    '字幕（じまく）を ONに すると わかりやすいよ。\n'
    'めいたんていも、くりかえし きいて 事件（じけん）を とくんだ。';

const String kConversationEncourageMsg = 'なんども まちがえても へいき！ 会話（かいわ）の ながれを よむのは'
    'むずかしいよね。めいたんていも、ヒントを あつめて すこしずつ とくんだ。';

const String kReadingEncourageMsg = 'なんども まちがえても へいき！ 本文（ほんぶん）を もう一度（いちど）'
    'よむと、答（こた）えの てがかりが みつかるよ。\n'
    'めいたんていも、てがかりを さがして 事件（じけん）を とくんだ。';

/// Session-end retention hook: surfaces the streak / daily-goal the child JUST
/// earned at the emotional peak (results screen), in スラ's voice, with a
/// forward-looking line — so the engagement spine is felt at the moment that can
/// pull them back tomorrow, not only on the next home visit. Honest + COPPA-safe:
/// it shows the child's OWN real progress (no social, no nag, no dark pattern);
/// the "また あした" line only appears once the goal is genuinely met.
class SessionEndHook extends StatelessWidget {
  final StreakState streak;
  const SessionEndHook({super.key, required this.streak});

  @override
  Widget build(BuildContext context) {
    final s = streak;
    final String line = s.goalMet
        ? '${s.currentStreak}日（にち）れんぞく！ きょうの目標（もくひょう）たっせい！'
        : 'あと ${s.remainingToGoal}問（もん）で きょうの目標（もくひょう）！';
    final String tomorrow =
        s.goalMet ? 'また あした、つづきを しらべよう！' : 'もう少（すこ）し やってみる？';
    return Container(
      key: const ValueKey('session_end_hook'),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dqBox,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFF5DA9E9), width: 2),
      ),
      child: Column(
        children: [
          Text('🔵 スラ',
              style: dqText(
                  size: 12,
                  w: FontWeight.w800,
                  color: const Color(0xFF5DA9E9))),
          const SizedBox(height: 6),
          Text(line,
              textAlign: TextAlign.center,
              style: dqText(size: 15, w: FontWeight.w900, color: dqGold)),
          const SizedBox(height: 4),
          Text(tomorrow,
              textAlign: TextAlign.center,
              style: dqText(size: 12, color: dqInk.withAlpha(200))),
        ],
      ),
    );
  }
}
