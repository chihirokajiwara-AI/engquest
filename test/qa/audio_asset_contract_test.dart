// test/qa/audio_asset_contract_test.dart
// #44 — Audio-asset contract guard (quest + scene + listening audio).
//
// Walks the ACTUAL data structures (not a text scan, so it catches dynamically
// built keys like audio/listening/<id> that the R2 python gate can't see) and
// asserts every referenced audio clip either exists on disk OR is registered in
// assets/ALLOWED_MISSING.txt.
//
// Why this matters: a missing clip is silent at runtime (AudioCueService
// swallows the error), so a 英検 item or a 5級 phonics step becomes a silent
// dead end → confusion / an unanswerable item that drags down 合格率. This guard
// fails the gate on such a gap.
//
// SCOPE — environment-aware for the .gitignored generated-audio classes:
//
//   • audio/phonics/  — the 英検5級『言葉を失った村』FRONT DOOR (the first sounds a
//     child ever hears). It is .gitignored generated audio, so it is absent in a
//     clean CI checkout. We therefore verify it WHENEVER the directory is
//     materialised locally (this loop's working tree, where the clips are
//     present) and skip it ONLY when empty (clean CI) to stay green. This closes
//     a real hole: previously the whole phonics class was excluded, so a
//     missing/typo'd front-door blend would ship SILENT. The 6 founder-pending
//     pure phonemes (phoneme_s/a/t/c/o/g — #45, can't be cleanly TTS'd) are
//     tracked via assets/ALLOWED_MISSING.txt and WARN rather than fail.
//
//   • audio/quiz/ and audio/eiken* — keys are dynamically hashed/regenerated at
//     scale (Kokoro) and the regenerate-in-CI-vs-commit choice is the pending
//     T35 architecture decision (the CEO's, not ours). These stay excluded here;
//     covered by the R2 gate (check_asset_contract.py), #45, and T35.
//
// Net: green in BOTH the working tree and a clean CI checkout, while actually
// guarding the front-door phonics clips locally.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

// Generated classes that stay excluded regardless of environment (dynamic keys,
// broad regeneration) — covered by R2 / #45 / the pending T35 decision.
const _alwaysExcludedPrefixes = <String>[
  'audio/quiz/',
  'audio/eiken',
];

// The phonics class is generated + .gitignored, but it is the 5級 front door, so
// it is verified whenever it is materialised locally (see header).
const _phonicsPrefix = 'audio/phonics/';

bool _alwaysExcluded(String key) =>
    _alwaysExcludedPrefixes.any((p) => key.startsWith(p));

// "Materialised" = the phonics dir holds at least one real clip (not just the
// .gitkeep placeholder). Empty (clean CI checkout) → we skip the class.
bool _phonicsMaterialised() {
  final d = Directory('assets/audio/phonics');
  if (!d.existsSync()) return false;
  return d.listSync().any((e) =>
      e is File && (e.path.endsWith('.mp3') || e.path.endsWith('.wav')));
}

void main() {
  Set<String> loadAllowedMissing() {
    final f = File('assets/ALLOWED_MISSING.txt');
    final allowed = <String>{};
    if (!f.existsSync()) return allowed;
    for (final line in f.readAsLinesSync()) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      allowed.add(t.split('|').first.trim());
    }
    return allowed;
  }

  /// Every audio key referenced by the quest + scene + listening data.
  Set<String> collectAudioKeys() {
    final keys = <String>{};
    void addStep(QuestStep step) {
      final a = step.autoPlayAudio;
      if (a != null && a.isNotEmpty) keys.add(a);
      for (final o in step.options) {
        final oa = o.audioAsset;
        if (oa != null && oa.isNotEmpty) keys.add(oa);
      }
    }

    for (final town in kQuestTowns) {
      town.encounters.forEach(addStep);
    }
    for (final scene in kScenesByGrade.values) {
      for (final h in scene.hotspots) {
        final s = h.step;
        if (s != null) addStep(s);
      }
    }
    for (final items in kListeningItems.values) {
      for (final it in items) {
        keys.add('audio/listening/${it.audioKey}');
      }
    }
    return keys;
  }

  test('every referenced audio key has a backing asset or is ALLOWED', () {
    final allowed = loadAllowedMissing();
    final all = collectAudioKeys();
    expect(all, isNotEmpty, reason: 'sanity: should find audio keys');
    expect(all.any((k) => k.startsWith('audio/listening/')), isTrue,
        reason: 'sanity: should find tracked listening audio keys');

    final phonicsLive = _phonicsMaterialised();

    final missing = <String>[];
    final warned = <String>[];
    final skipped = <String>[];
    for (final key in all) {
      final path = key.startsWith('assets/') ? key : 'assets/$key';
      if (File(path).existsSync()) continue;

      // Always-excluded generated classes (dynamic keys / T35).
      if (_alwaysExcluded(key)) {
        skipped.add(key);
        continue;
      }
      // Phonics front door: skip ONLY in a clean checkout (dir not materialised).
      if (key.startsWith(_phonicsPrefix) && !phonicsLive) {
        skipped.add(key);
        continue;
      }
      if (allowed.contains(key)) {
        warned.add(key);
        continue;
      }
      missing.add(key);
    }

    if (warned.isNotEmpty) {
      // ignore: avoid_print
      print('AUDIO CONTRACT — ${warned.length} key(s) missing but ALLOWED '
          '(founder/T31 pending): ${(warned.toList()..sort()).join(', ')}');
    }
    if (skipped.isNotEmpty && !phonicsLive) {
      // ignore: avoid_print
      print('AUDIO CONTRACT — phonics class not materialised (clean checkout); '
          'front-door clips skipped this run.');
    }

    expect(
      missing..sort(),
      isEmpty,
      reason: 'Audio keys referenced in code but NOT on disk and NOT in '
          'assets/ALLOWED_MISSING.txt (a silent clip = a dead/unanswerable '
          'step):\n${missing.join('\n')}',
    );
  });
}
