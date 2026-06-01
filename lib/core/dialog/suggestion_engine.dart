// lib/core/dialog/suggestion_engine.dart
// P1.7 — Context-aware A1 suggestion chips for the Dialog screen.
//
// Goal: an L1-L2 boundary learner (age 6–12, A1 CEFR) should ALWAYS have
// 3 sensible English things they can tap to say next. Static per-scenario
// quick replies are the floor; this engine upgrades them to be *contextual*
// by reacting to keywords in the NPC's most recent message.
//
// Pure Dart, no Flutter / IO dependencies → fully unit-testable.

import 'dialog_service.dart';

/// Produces up to 3 A1-level reply suggestions for the player.
///
/// Strategy:
///   1. Inspect the NPC's last message for known A1 intent keywords
///      (question words, greetings, price/shop cues, battle cues).
///   2. Emit matching contextual replies (max 3, de-duplicated).
///   3. Backfill from the scenario's static [DialogScenario.quickReplies]
///      so the result is ALWAYS exactly 3 non-empty chips.
class SuggestionEngine {
  const SuggestionEngine();

  /// Number of chips shown below the input field.
  static const int chipCount = 3;

  /// Contextual reply rules keyed by an A1 trigger phrase found in the NPC
  /// message. Order matters: earlier rules take priority.
  static const List<_Rule> _rules = [
    // --- Greetings / introductions ---
    _Rule(['how are you'], ['I am fine!', 'I am happy!', 'And you?']),
    _Rule(['what is your name', 'your name'],
        ['I am Hero.', 'My name is Hero.', 'Nice to meet you!']),
    _Rule(['nice to meet you', 'welcome'],
        ['Nice to meet you!', 'Thank you!', 'I am happy!']),
    _Rule(['hello', 'hi ', 'hi!', 'good morning'],
        ['Hello!', 'Hi!', 'Good morning!']),
    _Rule(['goodbye', 'bye', 'see you'], ['Goodbye!', 'See you!', 'Bye bye!']),

    // --- Shop / price ---
    _Rule(['how many', 'do you want'],
        ['One, please.', 'Two, please.', 'No, thank you.']),
    _Rule(['coins', 'cost', 'price', 'how much'],
        ['I will buy it!', 'Too much!', 'How much?']),
    _Rule(['buy', 'sell', 'shop', 'want to buy'],
        ['What do you sell?', 'I want this.', 'How much?']),

    // --- Battle ---
    _Rule(['ready', 'fight', 'battle'],
        ['I am ready!', 'Let us fight!', 'Not yet!']),
    _Rule(['good luck', 'win', 'strong'],
        ['Thank you!', 'I can win!', 'Let us go!']),

    // --- Generic questions ---
    _Rule(['?'], ['Yes!', 'No, thank you.', 'Tell me more.']),
  ];

  /// Returns exactly [chipCount] suggestion strings for the given [scenario],
  /// reacting to [lastNpcMessage] when possible.
  ///
  /// [lastNpcMessage] may be null/empty (e.g. before the first NPC turn), in
  /// which case the scenario's static quick replies are returned.
  List<String> suggestionsFor(
    DialogScenario scenario, {
    String? lastNpcMessage,
  }) {
    final fallback = scenario.quickReplies;
    final result = <String>[];

    final msg = (lastNpcMessage ?? '').toLowerCase();
    if (msg.trim().isNotEmpty) {
      for (final rule in _rules) {
        if (rule.matches(msg)) {
          for (final reply in rule.replies) {
            if (result.length >= chipCount) break;
            if (!result.contains(reply)) result.add(reply);
          }
        }
        if (result.length >= chipCount) break;
      }
    }

    // Backfill from the scenario's static quick replies so we always show 3.
    for (final reply in fallback) {
      if (result.length >= chipCount) break;
      if (!result.contains(reply)) result.add(reply);
    }

    // Absolute safety net (should never trigger given non-empty fallback).
    while (result.length < chipCount && fallback.isNotEmpty) {
      result.add(fallback[result.length % fallback.length]);
    }

    return result.take(chipCount).toList();
  }
}

/// A single keyword→replies contextual rule.
class _Rule {
  final List<String> triggers;
  final List<String> replies;
  const _Rule(this.triggers, this.replies);

  bool matches(String lowerMessage) =>
      triggers.any((t) => lowerMessage.contains(t));
}
