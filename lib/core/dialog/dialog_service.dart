import 'claude_client.dart';
import 'content_filter.dart';

/// The three NPC conversation scenarios available in the MVP.
enum DialogScenario {
  greetNpc,
  shopDialog,
  battleIntro,
}

extension DialogScenarioX on DialogScenario {
  String get label {
    switch (this) {
      case DialogScenario.greetNpc:
        return 'むらびとにあいさつ';
      case DialogScenario.shopDialog:
        return 'おみせでかいもの';
      case DialogScenario.battleIntro:
        return 'バトルのはじまり';
    }
  }

  String get npcName {
    switch (this) {
      case DialogScenario.greetNpc:
        return 'むらびと Elder';
      case DialogScenario.shopDialog:
        return 'Merchant ショップ';
      case DialogScenario.battleIntro:
        return 'Knight ナイト';
    }
  }

  String get npcEmoji {
    switch (this) {
      case DialogScenario.greetNpc:
        return '👴';
      case DialogScenario.shopDialog:
        return '🛒';
      case DialogScenario.battleIntro:
        return '⚔️';
    }
  }

  List<String> get quickReplies {
    switch (this) {
      case DialogScenario.greetNpc:
        return ['Hello!', 'Who are you?', 'Goodbye!'];
      case DialogScenario.shopDialog:
        return ['What do you sell?', 'How much?', 'I will buy it!'];
      case DialogScenario.battleIntro:
        return ['I am ready!', 'Tell me more.', 'Let us fight!'];
    }
  }

  String get scenarioDescription {
    switch (this) {
      case DialogScenario.greetNpc:
        return 'greeting';
      case DialogScenario.shopDialog:
        return 'shop transaction';
      case DialogScenario.battleIntro:
        return 'battle introduction';
    }
  }
}

/// A single message in a conversation.
class ChatMessage {
  final String role; // 'user' or 'assistant'
  final String content;

  const ChatMessage({required this.role, required this.content});

  Map<String, String> toMap() => {'role': role, 'content': content};
}

/// High-level dialog service wrapping [ClaudeClient].
/// Falls back to offline canned responses when [ClaudeClient.isOfflineMode] is true.
class DialogService {
  final ClaudeClient _client;

  /// Offline fallback responses, cycled round-robin per scenario.
  static const Map<DialogScenario, List<String>> _offlineResponses = {
    DialogScenario.greetNpc: [
      'Hello! Welcome to our village!',
      'How are you today?',
      'Nice to meet you!',
    ],
    DialogScenario.shopDialog: [
      'What do you want to buy?',
      'That costs 5 coins.',
      'Thank you very much!',
    ],
    DialogScenario.battleIntro: [
      'Are you ready to fight?',
      'Good luck, hero!',
      'Let us begin!',
    ],
  };

  /// Tracks the current offline response index per scenario.
  final Map<DialogScenario, int> _offlineIndex = {
    for (final s in DialogScenario.values) s: 0,
  };

  DialogService({required ClaudeClient client}) : _client = client;

  /// Hardcoded child-safety system prompt prefix.
  ///
  /// This is prepended to every NPC system prompt to enforce age-appropriate
  /// content boundaries at the model level (defense-in-depth alongside the
  /// client-side [ContentFilter]).
  static const String _childSafetyPrefix =
      '''You are an English learning tutor for Japanese children ages 4-18 studying for the Eiken (英検) exam.
Rules:
- Only discuss English learning, vocabulary, grammar, and age-appropriate educational topics
- Never discuss violence, adult content, politics, religion, or controversial topics
- Respond in simple, encouraging language appropriate for the student's level
- If asked about non-educational topics, redirect to English learning
- Use Japanese for explanations, English for the target language content

''';

  /// Builds the NPC system prompt for [scenario] and [playerName].
  ///
  /// The prompt is prefixed with [_childSafetyPrefix] to enforce child-safe
  /// content at the model level.
  String _systemPrompt(DialogScenario scenario, String playerName) {
    return '''${_childSafetyPrefix}You are a friendly NPC in an English learning RPG for Japanese children (age 6–12).
Use only A1 CEFR English vocabulary. Maximum sentence length: 10 words.
Keep responses under 3 sentences. Be encouraging and fun.
The player's name is $playerName.
Scenario: ${scenario.scenarioDescription}.
Never use complex grammar. Always stay in character as ${scenario.npcName}.''';
  }

  /// Sends [userInput] to Claude (or returns an offline fallback) and returns
  /// the NPC's response text.
  ///
  /// Input is checked by [ContentFilter.isSafe] before being forwarded to the
  /// API.  If the input is unsafe the method returns
  /// [ContentFilter.rejectionMessage] without making a network call.
  /// The model's response is also post-filtered via [ContentFilter.filterResponse].
  Future<String> chat({
    required DialogScenario scenario,
    required List<ChatMessage> history,
    required String userInput,
    String playerName = 'Hero',
  }) async {
    // ── Crisis (self-harm) gate — MUST precede the profanity gate so a child
    //    in distress receives support, never a "you can't say that". The AI is
    //    NOT called. (Anonymized safety-event logging is a documented follow-up.)
    if (ContentFilter.isCrisisSignal(userInput)) {
      return ContentFilter.crisisMessage();
    }

    // ── Input safety gate ─────────────────────────────────────────────────
    final safeInput = ContentFilter.sanitize(userInput);
    if (safeInput == null) {
      return ContentFilter.rejectionMessage();
    }

    if (_client.isOfflineMode) {
      return _nextOfflineResponse(scenario);
    }

    final messages = [
      ...history.map((m) => m.toMap()),
      {'role': 'user', 'content': safeInput},
    ];

    try {
      final raw = await _client.sendMessage(
        systemPrompt: _systemPrompt(scenario, playerName),
        messages: messages,
      );
      // ── Output safety gate ──────────────────────────────────────────────
      return ContentFilter.filterResponse(raw);
    } on ClaudeOfflineException {
      return _nextOfflineResponse(scenario);
    } on ClaudeApiException catch (e) {
      return 'Sorry, I cannot talk right now. ($e)';
    } catch (e) {
      return _nextOfflineResponse(scenario);
    }
  }

  String _nextOfflineResponse(DialogScenario scenario) {
    final responses = _offlineResponses[scenario]!;
    final idx = _offlineIndex[scenario]!;
    _offlineIndex[scenario] = (idx + 1) % responses.length;
    return responses[idx];
  }
}
