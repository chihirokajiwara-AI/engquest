import 'dart:convert';
import 'dart:io';

/// HTTP client that calls the Anthropic Claude API.
///
/// Cost estimate: ~$0.00025/1K input, ~$0.00125/1K output → <$0.0001/turn
/// with claude-3-haiku-20240307.
class ClaudeClient {
  final String apiKey;
  final String model;
  final int maxTokens;

  static const String _baseUrl = 'api.anthropic.com';
  static const String _messagesPath = '/v1/messages';
  static const String _anthropicVersion = '2023-06-01';

  ClaudeClient({
    required this.apiKey,
    this.model = 'claude-3-haiku-20240307',
    this.maxTokens = 150,
  });

  /// Returns true when no real API key is configured.
  bool get isOfflineMode => apiKey == 'REPLACE_WITH_KEY' || apiKey.isEmpty;

  /// Sends a conversation to Claude and returns the assistant's reply text.
  ///
  /// [systemPrompt] — persona / instructions for the NPC.
  /// [messages] — conversation history as [{role: 'user'|'assistant', content: '...'}].
  Future<String> sendMessage({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    if (isOfflineMode) {
      throw const ClaudeOfflineException('API key not configured — offline mode');
    }

    final client = HttpClient();
    try {
      final request = await client.postUrl(
        Uri.https(_baseUrl, _messagesPath),
      );

      request.headers
        ..set('Content-Type', 'application/json')
        ..set('x-api-key', apiKey)
        ..set('anthropic-version', _anthropicVersion);

      final body = jsonEncode({
        'model': model,
        'max_tokens': maxTokens,
        'system': systemPrompt,
        'messages': messages,
      });

      request.write(body);

      final response = await request.close();
      final responseBody = await response.transform(utf8.decoder).join();

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
        final content = decoded['content'] as List<dynamic>;
        if (content.isNotEmpty) {
          return (content.first as Map<String, dynamic>)['text'] as String;
        }
        throw const ClaudeApiException('Empty content in response');
      } else {
        throw ClaudeApiException(
          'HTTP ${response.statusCode}: $responseBody',
        );
      }
    } finally {
      client.close();
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
