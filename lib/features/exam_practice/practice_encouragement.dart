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
const String kVocabEncourageMsg =
    'なんども まちがえても へいき！ めいたんていも、'
    'しっぱいを ヒントに して 事件（じけん）を とくんだ。\n'
    '「いみを みる」を つかうと、もっと わかるよ。';

const String kListeningEncourageMsg =
    'なんども まちがえても へいき！ もう一度（いちど） 🔊 きいたり、'
    '字幕（じまく）を ONに すると わかりやすいよ。\n'
    'めいたんていも、くりかえし きいて 事件（じけん）を とくんだ。';

const String kConversationEncourageMsg =
    'なんども まちがえても へいき！ 会話（かいわ）の ながれを よむのは'
    'むずかしいよね。めいたんていも、ヒントを あつめて すこしずつ とくんだ。';

const String kReadingEncourageMsg =
    'なんども まちがえても へいき！ 本文（ほんぶん）を もう一度（いちど）'
    'よむと、答（こた）えの てがかりが みつかるよ。\n'
    'めいたんていも、てがかりを さがして 事件（じけん）を とくんだ。';
