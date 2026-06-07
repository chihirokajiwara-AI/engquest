// test/features/exam_practice/muted_voice_banner_test.dart
// Guards the in-session muted-voice affordance (#33):
//   1. The shared MutedVoiceBanner widget renders the warning + one-tap unmute,
//      and tapping it actually clears AudioMute.voiceMuted + fires onUnmute.
//   2. The full mock (フル模試) shows the banner on listening items when the Voice
//      channel is muted, and does NOT when it is on. Without this, a muted child
//      faces a silent listening section, scores false 0s, and the 合格率 is
//      understated for the wrong reason.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/core/audio/audio_mute.dart';
import 'package:engquest/features/quest/ui/muted_voice_banner.dart';
import 'package:engquest/features/exam_practice/mock_exam_screen.dart';
import 'package:engquest/features/exam_practice/pass/cse_model.dart';
import 'package:engquest/features/exam_practice/pass/mock_exam.dart';
import 'package:engquest/features/quest/ui/dq_ui.dart';

void main() {
  group('MutedVoiceBanner widget', () {
    testWidgets('renders the warning + unmute, and unmute clears voiceMuted',
        (tester) async {
      AudioMute.voiceMuted = true;
      addTearDown(() => AudioMute.voiceMuted = false);
      var unmuteFired = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: MutedVoiceBanner(onUnmute: () => unmuteFired = true),
        ),
      ));
      await tester.pump();

      expect(find.textContaining('おとが オフ'), findsOneWidget);
      expect(find.textContaining('Sound is off'), findsOneWidget);

      await tester.tap(find.text('おんを オンにする'));
      await tester.pump();

      expect(AudioMute.voiceMuted, isFalse); // unmuted
      expect(unmuteFired, isTrue); // host notified to rebuild
    });
  });

  group('MockExamScreen — muted-voice affordance on listening', () {
    // mcqItems order == on-screen order, so the index of the first listening
    // item is exactly how many "Next" advances reach it.
    int firstListeningIndex() {
      final exam = MockExamAssembler.assemble('5', seed: 1);
      return exam.mcqItems.indexWhere((i) => i.skill == EikenSkill.listening);
    }

    Future<void> advanceTo(WidgetTester tester, int target) async {
      for (var i = 0; i < target; i++) {
        await tester.tap(find.byType(DqChoice).first); // select an answer
        await tester.pump();
        await tester.tap(find.textContaining('つぎへ')); // Next
        await tester.pump();
      }
    }

    testWidgets('shows the banner on a listening item when muted',
        (tester) async {
      AudioMute.voiceMuted = true;
      addTearDown(() => AudioMute.voiceMuted = false);
      final idx = firstListeningIndex();
      expect(idx, greaterThanOrEqualTo(0),
          reason: '5級 seed:1 mock must contain a listening item');

      await tester.pumpWidget(
        const MaterialApp(home: MockExamScreen(eikenGrade: '5', seed: 1)),
      );
      await tester.pump();
      await advanceTo(tester, idx);

      expect(find.byType(MutedVoiceBanner), findsOneWidget);
      await tester.pumpWidget(const SizedBox()); // cancel periodic timer
    });

    testWidgets('does NOT show the banner when Voice is on', (tester) async {
      AudioMute.voiceMuted = false;
      final idx = firstListeningIndex();
      expect(idx, greaterThanOrEqualTo(0)); // never pass vacuously

      await tester.pumpWidget(
        const MaterialApp(home: MockExamScreen(eikenGrade: '5', seed: 1)),
      );
      await tester.pump();
      await advanceTo(tester, idx);

      // On the same listening item, with sound on, there must be no banner.
      expect(find.byType(MutedVoiceBanner), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
