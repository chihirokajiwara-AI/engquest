// test/qa/audio_asset_contract_test.dart
// #44 — Audio-asset contract guard (TRACKED audio).
//
// Walks the ACTUAL data structures (not a text scan, so it catches dynamically
// built keys like audio/listening/<id> that the R2 python gate can't see) and
// asserts every referenced audio clip that is SUPPOSED to be committed either
// exists on disk OR is registered in assets/ALLOWED_MISSING.txt.
//
// Why this matters: a missing clip is silent at runtime (AudioCueService
// swallows the error), so a 英検 listening item becomes unanswerable → a wrong
// answer that drags down 合格率. This guard fails the gate on such a gap.
//
// SCOPE — tracked audio only. The generated-audio class (assets/audio/phonics,
// /quiz, /eiken*) is .gitignored (regenerated via Kokoro / founder-recorded),
// so it is legitimately absent in a clean checkout (CI) and present locally.
// Verifying it here would (a) be red in CI for a non-bug and (b) require a T35
// architecture decision (commit vs regenerate-in-CI) that is the CEO's, not
// ours. That class stays covered by the R2 gate (check_asset_contract.py),
// task #45 (founder phonemes), and the pending T35 decision. This test is
// therefore green in BOTH the working tree and a clean CI checkout.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:engquest/features/quest/quest_data.dart';
import 'package:engquest/features/explore/hotspot.dart';
import 'package:engquest/features/exam_practice/listening_data.dart';

// Key prefixes whose backing files are .gitignored generated audio (see
// .gitignore) — out of scope here, covered by R2 / #45 / the T35 decision.
const _generatedPrefixes = <String>[
  'audio/phonics/',
  'audio/quiz/',
  'audio/eiken',
];

bool _isGeneratedClass(String key) =>
    _generatedPrefixes.any((p) => key.startsWith(p));

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

  test('every referenced TRACKED audio key has a backing asset or is ALLOWED',
      () {
    final allowed = loadAllowedMissing();
    final all = collectAudioKeys();
    expect(all, isNotEmpty, reason: 'sanity: should find audio keys');

    // Tracked (committed) audio only — generated/.gitignored class is excluded
    // (covered by R2 + #45 + the T35 decision; see file header).
    final tracked = all.where((k) => !_isGeneratedClass(k)).toSet();
    expect(tracked, isNotEmpty,
        reason: 'sanity: should find tracked (listening) audio keys');

    final missing = <String>[];
    final warned = <String>[];
    for (final key in tracked) {
      final path = key.startsWith('assets/') ? key : 'assets/$key';
      if (File(path).existsSync()) continue;
      if (allowed.contains(key)) {
        warned.add(key);
        continue;
      }
      missing.add(key);
    }

    if (warned.isNotEmpty) {
      // ignore: avoid_print
      print('AUDIO CONTRACT — ${warned.length} tracked key(s) missing but '
          'ALLOWED: ${(warned.toList()..sort()).join(', ')}');
    }

    expect(
      missing..sort(),
      isEmpty,
      reason: 'Tracked audio keys referenced in code but NOT on disk and NOT in '
          'assets/ALLOWED_MISSING.txt (a silent clip = unanswerable item):\n'
          '${missing.join('\n')}',
    );
  });
}
