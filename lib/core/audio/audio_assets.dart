// lib/core/audio/audio_assets.dart
// Asks "is this audio clip actually bundled?" so the UI never presents a dead
// play button for a clip that doesn't exist (e.g. the founder-pending 5級
// phonemes — see #45). AudioCueService.play swallows a missing clip silently,
// so without this a child taps 🔊 and nothing happens.
//
// Uses the modern AssetManifest API (Flutter 3.7+) — it lists bundled assets
// WITHOUT loading their bytes. Cached after first load. Web-safe; NO dart:io.
//
// Safe-by-default: if the manifest can't be read, exists() returns true so the
// app degrades to its prior behavior (never shows a false "coming soon").

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetManifest, rootBundle;

class AudioAssets {
  static Set<String>? _assets; // logical keys, e.g. 'assets/audio/...'
  static bool _failed = false;

  /// Test seam: inject a known set of bundled asset keys (logical, with the
  /// 'assets/' prefix) so widget tests can exercise present/missing paths
  /// without depending on the test harness's AssetManifest.
  @visibleForTesting
  static set debugAssets(Set<String>? assets) {
    _assets = assets;
    _failed = false;
  }

  @visibleForTesting
  static void resetForTest() {
    _assets = null;
    _failed = false;
  }

  /// True if [key] (an 'audio/...' key as used in code, or an 'assets/...' path)
  /// is a bundled asset. Returns true if existence can't be determined, so the
  /// caller degrades to its prior behavior rather than hiding real audio.
  static Future<bool> exists(String key) async {
    if (_assets == null && !_failed) {
      try {
        final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
        _assets = manifest.listAssets().toSet();
      } catch (_) {
        _failed = true;
      }
    }
    if (_failed || _assets == null) return true; // can't tell → assume present
    final full = key.startsWith('assets/') ? key : 'assets/$key';
    return _assets!.contains(full);
  }
}
