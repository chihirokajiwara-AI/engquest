// lib/features/exam_practice/muted_voice_banner.dart
// Shared in-session "sound is off" affordance for audio-dependent exercises.
//
// 英検 listening (practice AND the full mock) is 100% audio — if the child muted
// the Voice channel they'd face a silent, unanswerable section and score a false
// 0, dragging their 合格率 down for the wrong reason. This banner warns them and
// offers a one-tap unmute, right where the audio matters.
//
// Single source of truth so the listening-practice screen and the mock-exam
// screen present an identical affordance (no copy-paste drift).

import 'package:flutter/material.dart';

import '../../core/audio/audio_mute.dart';
import '../quest/ui/dq_ui.dart';

class MutedVoiceBanner extends StatelessWidget {
  /// Called after the Voice channel is un-muted so the host can rebuild (the
  /// banner is shown conditionally on [AudioMute.voiceMuted]).
  final VoidCallback onUnmute;

  const MutedVoiceBanner({super.key, required this.onUnmute});

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
              'おとが オフだよ。リスニングには おとが ひつようです。\n'
              'Sound is off — listening needs audio.',
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
