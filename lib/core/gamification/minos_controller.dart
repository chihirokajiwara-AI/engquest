// lib/core/gamification/minos_controller.dart
// Wave 1 — ミノス (Minos) per-ナゾ value + decay controller.
//
// Pure-Dart, no Flutter import, unit-testable.
// Design (from LAYTON-CLASS-REDESIGN-2026-06-05.json):
//   • Each item has a starting value (grade-dependent).
//   • Wrong tap decays: full → ⅔ → ⅓ → 40% floor.
//   • No timer, no fail. A player who keeps getting wrong eventually earns
//     the floor value — never zero.
//   • On correct: call [earn()] to bank the current value. Returns banked int.

class MinosController {
  /// Create a controller for one ナゾ item.
  ///
  /// [maxValue] — the starting Minos value for this item (e.g. 10 for 5級
  /// vocab, 50 for 準1級 reading — see [minosMaxForGrade]).
  MinosController({required int maxValue})
      : _maxValue = maxValue,
        _wrongCount = 0;

  final int _maxValue;
  int _wrongCount;

  // Decay table: full → ⅔ → ⅓ → floor at 40% (a generic decay-on-wrong scoring
  // curve — the mechanic is unprotectable; the ミノス name/world is ours).
  // Index == number of wrong taps, capped at the last entry.
  static const _decaySteps = [1.0, 2 / 3, 1 / 3, 0.4];

  /// The current earnable value (decays with each wrong tap).
  int get currentValue {
    final stepIdx = _wrongCount.clamp(0, _decaySteps.length - 1);
    return (_maxValue * _decaySteps[stepIdx]).round().clamp(1, _maxValue);
  }

  /// How many wrong taps have occurred.
  int get wrongCount => _wrongCount;

  /// Has the item been solved yet.
  bool get isSolved => _solved;
  bool _solved = false;

  /// Register a wrong tap. Decays [currentValue] by one step (floor at 40%).
  void onWrong() {
    if (_solved) return;
    if (_wrongCount < _decaySteps.length - 1) {
      _wrongCount++;
    }
    // Already at floor — stays there.
  }

  /// Register a correct answer. Returns the earned Minos value and locks the
  /// controller (subsequent calls are no-ops and return 0).
  int earn() {
    if (_solved) return 0;
    _solved = true;
    return currentValue;
  }

  /// Reset to full value (for unit tests / retries).
  void reset() {
    _wrongCount = 0;
    _solved = false;
  }
}

// ── Grade-based starting values ───────────────────────────────────────────────

/// Return the Minos starting value appropriate for an 英検 grade string and
/// step kind. Maps to the design's scale (5級 vocab = 10 … 準1級 reading = 50).
int minosMaxForGrade(String eikenLevel) {
  switch (eikenLevel) {
    case '5':
      return 10;
    case '4':
      return 15;
    case '3':
      return 20;
    case 'pre2':
      return 25;
    case '2':
      return 35;
    case 'pre1':
      return 50;
    default:
      return 10;
  }
}
