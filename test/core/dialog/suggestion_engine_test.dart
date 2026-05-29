// test/core/dialog/suggestion_engine_test.dart
// P1.7 — Tests for context-aware A1 suggestion chips.

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/dialog/dialog_service.dart';
import 'package:engquest/core/dialog/suggestion_engine.dart';

void main() {
  const engine = SuggestionEngine();

  group('SuggestionEngine — always returns 3 chips', () {
    test('returns exactly 3 chips with null last message', () {
      for (final s in DialogScenario.values) {
        final out = engine.suggestionsFor(s, lastNpcMessage: null);
        expect(out.length, SuggestionEngine.chipCount, reason: '$s');
      }
    });

    test('returns exactly 3 chips with empty last message', () {
      for (final s in DialogScenario.values) {
        final out = engine.suggestionsFor(s, lastNpcMessage: '   ');
        expect(out.length, 3, reason: '$s');
      }
    });

    test('returns exactly 3 chips for arbitrary unmatched messages', () {
      final out = engine.suggestionsFor(
        DialogScenario.greetNpc,
        lastNpcMessage: 'The weather is sunny today over the mountains.',
      );
      expect(out.length, 3);
    });

    test('all chips are non-empty and unique', () {
      for (final s in DialogScenario.values) {
        final out = engine.suggestionsFor(s, lastNpcMessage: 'How much?');
        expect(out.every((c) => c.trim().isNotEmpty), isTrue, reason: '$s');
        expect(out.toSet().length, out.length, reason: '$s has dup chips');
      }
    });
  });

  group('SuggestionEngine — falls back to static quick replies', () {
    test('null message yields scenario quickReplies', () {
      for (final s in DialogScenario.values) {
        final out = engine.suggestionsFor(s, lastNpcMessage: null);
        expect(out, equals(s.quickReplies), reason: '$s');
      }
    });
  });

  group('SuggestionEngine — contextual matching', () {
    test('"How are you?" surfaces a feeling reply', () {
      final out = engine.suggestionsFor(
        DialogScenario.greetNpc,
        lastNpcMessage: 'Hello! How are you today?',
      );
      expect(
        out.any((c) => c.toLowerCase().contains('fine') ||
            c.toLowerCase().contains('happy')),
        isTrue,
        reason: 'expected a feeling response, got $out',
      );
    });

    test('a name question surfaces a name reply', () {
      final out = engine.suggestionsFor(
        DialogScenario.greetNpc,
        lastNpcMessage: 'What is your name?',
      );
      expect(
        out.any((c) => c.toLowerCase().contains('name') ||
            c.toLowerCase().contains('hero')),
        isTrue,
        reason: 'expected a name response, got $out',
      );
    });

    test('a price message surfaces a buy/price reply', () {
      final out = engine.suggestionsFor(
        DialogScenario.shopDialog,
        lastNpcMessage: 'That costs 5 coins.',
      );
      expect(
        out.any((c) => c.toLowerCase().contains('buy') ||
            c.toLowerCase().contains('much') ||
            c.toLowerCase().contains('too much')),
        isTrue,
        reason: 'expected a price/buy response, got $out',
      );
    });

    test('a battle prompt surfaces a readiness reply', () {
      final out = engine.suggestionsFor(
        DialogScenario.battleIntro,
        lastNpcMessage: 'Are you ready to fight?',
      );
      expect(
        out.any((c) => c.toLowerCase().contains('ready') ||
            c.toLowerCase().contains('fight') ||
            c.toLowerCase().contains('not yet')),
        isTrue,
        reason: 'expected a readiness response, got $out',
      );
    });

    test('a goodbye surfaces a farewell reply', () {
      final out = engine.suggestionsFor(
        DialogScenario.greetNpc,
        lastNpcMessage: 'Goodbye, hero! See you soon.',
      );
      expect(
        out.any((c) => c.toLowerCase().contains('bye') ||
            c.toLowerCase().contains('see you')),
        isTrue,
        reason: 'expected a farewell, got $out',
      );
    });

    test('matching is case-insensitive', () {
      final lower = engine.suggestionsFor(DialogScenario.greetNpc,
          lastNpcMessage: 'how are you?');
      final upper = engine.suggestionsFor(DialogScenario.greetNpc,
          lastNpcMessage: 'HOW ARE YOU?');
      expect(lower, equals(upper));
    });
  });

  group('SuggestionEngine — A1 vocabulary discipline', () {
    test('contextual chips stay short (<= 5 words, A1 sentence length)', () {
      const samples = [
        'How are you?',
        'What is your name?',
        'That costs 5 coins.',
        'Are you ready to fight?',
        'Goodbye!',
        'Do you want to buy?',
      ];
      for (final s in DialogScenario.values) {
        for (final m in samples) {
          final out = engine.suggestionsFor(s, lastNpcMessage: m);
          for (final chip in out) {
            final words = chip.split(RegExp(r'\s+')).length;
            expect(words, lessThanOrEqualTo(5),
                reason: 'chip "$chip" too long for A1 ($m / $s)');
          }
        }
      }
    });
  });
}
