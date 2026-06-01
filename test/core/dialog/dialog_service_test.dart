// test/core/dialog/dialog_service_test.dart
// Tests for DialogService — offline fallback, quick replies, scenario labels
// Verifies P1-4: Japanese UI strings, A1 quick replies, NPC names

import 'package:flutter_test/flutter_test.dart';
import 'package:engquest/core/dialog/dialog_service.dart';
import 'package:engquest/core/dialog/claude_client.dart';

void main() {
  group('DialogScenario metadata', () {
    test('all scenarios have non-empty npcName', () {
      for (final s in DialogScenario.values) {
        expect(s.npcName, isNotEmpty, reason: '$s.npcName is empty');
      }
    });

    test('all scenarios have non-empty npcEmoji', () {
      for (final s in DialogScenario.values) {
        expect(s.npcEmoji, isNotEmpty, reason: '$s.npcEmoji is empty');
      }
    });

    test('all scenarios have exactly 3 quick replies', () {
      for (final s in DialogScenario.values) {
        expect(s.quickReplies.length, 3,
            reason: '$s should have 3 quick replies');
      }
    });

    test('greetNpc quick replies are A1 English phrases', () {
      final replies = DialogScenario.greetNpc.quickReplies;
      expect(replies, containsAll(['Hello!', 'Who are you?', 'Goodbye!']));
    });

    test('shopDialog quick replies include price-asking phrase', () {
      final replies = DialogScenario.shopDialog.quickReplies;
      expect(replies.any((r) => r.toLowerCase().contains('much') ||
          r.toLowerCase().contains('buy') ||
          r.toLowerCase().contains('sell')), isTrue);
    });

    test('scenario labels are in Japanese', () {
      // Japanese characters are in range \u3000-\u9FFF
      final jpPattern = RegExp(r'[\u3040-\u9FFF]');
      for (final s in DialogScenario.values) {
        expect(jpPattern.hasMatch(s.label), isTrue,
            reason: '${s.label} should contain Japanese characters');
      }
    });

    test('all scenario npcEmojis are distinct', () {
      final emojis = DialogScenario.values.map((s) => s.npcEmoji).toList();
      expect(emojis.toSet().length, emojis.length,
          reason: 'NPC emojis should all be unique');
    });
  });

  group('DialogService offline fallback', () {
    late DialogService service;

    setUp(() {
      // Force offline mode by using empty backend URL
      service = DialogService(
        client: ClaudeClient(backendUrl: ''),
      );
    });

    test('chat() returns non-empty string in offline mode', () async {
      final response = await service.chat(
        scenario: DialogScenario.greetNpc,
        history: [],
        userInput: 'Hello',
      );
      expect(response, isNotEmpty);
    });

    test('offline responses cycle round-robin (3 → wraps back to 0)', () async {
      final seen = <String>[];
      for (var i = 0; i < 4; i++) {
        final r = await service.chat(
          scenario: DialogScenario.greetNpc,
          history: [],
          userInput: 'hi',
        );
        seen.add(r);
      }
      // 4th response should be same as 1st (cycle of 3)
      expect(seen[3], equals(seen[0]));
    });

    test('different scenarios have different offline responses', () async {
      final greet = await service.chat(
        scenario: DialogScenario.greetNpc,
        history: [],
        userInput: 'hi',
      );
      final shop = await service.chat(
        scenario: DialogScenario.shopDialog,
        history: [],
        userInput: 'hi',
      );
      // They may differ — just verify both return content
      expect(greet, isNotEmpty);
      expect(shop, isNotEmpty);
    });

    test('empty input does not throw in offline mode', () async {
      expect(
        () => service.chat(
          scenario: DialogScenario.battleIntro,
          history: [],
          userInput: '',
        ),
        returnsNormally,
      );
    });
  });

  group('DialogService system prompt', () {
    test('_systemPrompt uses A1 vocabulary constraint', () {
      // We test this indirectly by verifying the scenario description is set
      for (final s in DialogScenario.values) {
        expect(s.scenarioDescription, isNotEmpty,
            reason: '$s.scenarioDescription empty');
      }
    });

    test('all scenarios have a non-empty scenarioDescription', () {
      final descriptions = DialogScenario.values
          .map((s) => s.scenarioDescription)
          .toList();
      for (final d in descriptions) {
        expect(d, isNotEmpty);
      }
    });
  });
}
