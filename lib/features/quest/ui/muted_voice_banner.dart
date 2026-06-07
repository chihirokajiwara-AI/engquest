// lib/features/quest/ui/muted_voice_banner.dart
// Shared in-session "sound is off" affordance for any audio-dependent exercise.
//
// Lives beside dq_ui (the shared design system) because it is used across
// features: the 英検 listening practice + full mock (exam_practice) AND the
// quest/phonics surfaces (nazo / silent battle / quest), where the child must
// HEAR a phoneme or word to answer. If the Voice channel is muted, those
// exercises are silent and unanswerable — this warns the child and offers a
// one-tap unmute, right where the audio matters. Single source of truth so
// every surface presents an identical affordance (no copy-paste drift).

import 'package:flutter/material.dart';

import '../../../core/audio/audio_mute.dart';
import 'dq_ui.dart';

/// Default message — for the 英検 listening sections (practice + mock).
const String kListeningMutedMessage = 'おとが オフだよ。リスニングには おとが ひつようです。\n'
    'Sound is off — listening needs audio.';

/// Message for the quest/phonics surfaces, where the child listens to a sound
/// or word and chooses the matching answer.
const String kPhonicsMutedMessage = 'おとが オフだよ。おとを きいて こたえてね。\n'
    'Sound is off — turn it on to hear the answer.';

class MutedVoiceBanner extends StatelessWidget {
  /// Called after the Voice channel is un-muted so the host can rebuild (the
  /// banner is shown conditionally on [AudioMute.voiceMuted]).
  final VoidCallback onUnmute;

  /// The bilingual warning line. Defaults to the listening message; quest
  /// surfaces pass [kPhonicsMutedMessage].
  final String message;

  const MutedVoiceBanner({
    super.key,
    required this.onUnmute,
    this.message = kListeningMutedMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dqGoldDeep.withAlpha(40),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: dqGold.withAlpha(150)),
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_off, color: dqGold, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: dqText(size: 11.5, w: FontWeight.w600, color: dqInk)
                  .copyWith(height: 1.4),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              // Update the flag + UI immediately; persist in the background so
              // the banner clears instantly (no await before the host rebuild).
              AudioMute.voiceMuted = false;
              AudioMute.setVoiceMuted(false);
              onUnmute();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [dqGold, dqGoldDeep]),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'おんを オンにする',
                style: dqText(
                    size: 11,
                    w: FontWeight.w800,
                    color: const Color(0xFF2A1C00)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
