import 'dart:convert';

import 'package:http/http.dart' as http;

/// HTTP client that calls the Anthropic Claude API.
///
/// Cost estimate: ~$0.00025/1K input, ~$0.00125/1K output -> <$0.0001/turn
/// with claude-3-haiku-20240307.
class ClaudeClient {
  final String apiKey;
  final String model;
  final int maxTokens;

  static const String _baseUrl = 'https://api.anthropic.com';
  static const String _messagesPath = '/v1/messages';
  static const String _anthropicVersion = '2023-06-01';

  const ClaudeClient({
    required this.apiKey,
    this.model = 'claude-3-haiku-20240307',
    this.maxTokens = 150,
  });

  /// Returns true when no real API key is configured.
  bool get isOfflineMode => apiKey == 'REPLACE_WITH_KEY' || apiKey.isEmpty;

  /// Sends a conversation to Claude and returns the assistant's reply text.
  ///
  /// [systemPrompt] -- persona / instructions for the NPC.
  /// [messages] -- conversation history as [{role: 'user'|'assistant', content: '...'}].
  Future<String> sendMessage({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    if (isOfflineMode) {
      throw const ClaudeOfflineException('API key not configured — offline mode');
    }

    final url = Uri.parse('$_baseUrl$_messagesPath');

    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': messages,
    });

    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': apiKey,
        'anthropic-version': _anthropicVersion,
      },
      body: body,
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>;
      if (content.isNotEmpty) {
        return (content.first as Map<String, dynamic>)['text'] as String;
      }
      throw const ClaudeApiException('Empty content in response');
    } else {
      throw ClaudeApiException(
        'HTTP ${response.statusCode}: ${response.body}',
      );
    }
  }
}

/// Thrown when the client is in offline mode (no real API key).
class ClaudeOfflineException implements Exception {
  final String message;
  const ClaudeOfflineException(this.message);
  @override
  String toString() => 'ClaudeOfflineException: $message';
}

/// Thrown when the Claude API returns an error.
class ClaudeApiException implements Exception {
  final String message;
  const ClaudeApiException(this.message);
  @override
  String toString() => 'ClaudeApiException: $message';
}
