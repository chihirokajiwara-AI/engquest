// lib/core/ui/readability_scale.dart
//
// Opt-in text-size control for readability (flaw-hunt #114). The app authored
// its text at one size in a single (serif) family. 2026 accessibility research
// (BDA; PMC5629233; Edutopia 2026) is clear: specialty "dyslexia fonts" like
// OpenDyslexic do NOT improve reading, and the real levers are SIZE, SPACING and
// ADJUSTABILITY — not the font family. So instead of a risky global font swap we
// give the child/parent a size control that scales ALL text (composed on top of
// any OS text-scaling), applied once at the app root. Default 1.0 = unchanged.
//
// Mirrors the AudioMute global-static pattern: a ValueNotifier the root listens
// to, backed by a SharedPreferences double. Pure-Dart, web-safe, no Firebase.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReadabilityScale {
  ReadabilityScale._();

  static const _prefsKey = 'text_scale';

  /// Allowed steps (child-facing: ふつう / 大きい / とても大きい). Kept modest so an
  /// opt-in larger size aids legibility without shattering fixed layouts.
  static const List<double> steps = [1.0, 1.15, 1.3];

  /// The active multiplier. The app root listens to this and rebuilds on change.
  static final ValueNotifier<double> notifier = ValueNotifier<double>(1.0);

  static double get value => notifier.value;

  /// Load the persisted size before the first frame (call in bootstrap).
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final v = prefs.getDouble(_prefsKey);
      if (v != null && v > 0) notifier.value = v.clamp(1.0, 1.3);
    } catch (_) {
      // Non-fatal — default 1.0 (unchanged) is always safe.
    }
  }

  /// Set + persist a new size (best-effort).
  static Future<void> set(double v) async {
    final clamped = v.clamp(1.0, 1.3);
    notifier.value = clamped;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_prefsKey, clamped);
    } catch (_) {/* notifier already updated; persistence is best-effort */}
  }

  /// Child-facing label for a step.
  static String labelJa(double v) {
    if (v >= 1.3) return 'とても大（おお）きい';
    if (v >= 1.15) return '大（おお）きい';
    return 'ふつう';
  }
}
