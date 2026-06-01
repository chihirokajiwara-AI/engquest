import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase/auth_service.dart';

/// HTTP client that calls the Claude API via the backend proxy.
///
/// The API key is held server-side — the client authenticates with
/// a Firebase ID token, and the backend proxies to Anthropic.
///
/// Cost estimate: ~$0.00025/1K input, ~$0.00125/1K output -> <$0.0001/turn
/// with claude-haiku-4-5.
class ClaudeClient {
  final String backendUrl;
  final String model;
  final int maxTokens;

  /// When true, the client is in offline mode and will not make API calls.
  /// This is determined by whether a backend URL is configured.
  final bool _offlineMode;

  static const String _defaultBackendUrl = 'https://api.akenquest.jp';

  // Lazy-initialized to avoid Firebase dependency in offline/test mode
  AuthService? _authInstance;
  AuthService get _auth => _authInstance ??= AuthService();

  ClaudeClient({
    String? backendUrl,
    // Keep apiKey parameter for backward compatibility but ignore it
    String apiKey = '',
    this.model = 'claude-haiku-4-5-20251001',
    this.maxTokens = 150,
  })  : backendUrl = backendUrl ?? _defaultBackendUrl,
        _offlineMode = (backendUrl ?? _defaultBackendUrl).isEmpty;

  /// Returns true when no backend is configured.
  bool get isOfflineMode => _offlineMode;

  /// Sends a conversation to Claude via the backend proxy and returns
  /// the assistant's reply text.
  ///
  /// [systemPrompt] -- persona / instructions for the NPC.
  /// [messages] -- conversation history as [{role: 'user'|'assistant', content: '...'}].
  Future<String> sendMessage({
    required String systemPrompt,
    required List<Map<String, String>> messages,
  }) async {
    if (isOfflineMode) {
      throw const ClaudeOfflineException(
          'Backend URL not configured — offline mode');
    }

    // Get Firebase ID token for authentication
    final idToken = await _auth.getIdToken();
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (idToken != null) {
      headers['Authorization'] = 'Bearer $idToken';
    }

    final url = Uri.parse('$backendUrl/claude/messages');

    final body = jsonEncode({
      'model': model,
      'max_tokens': maxTokens,
      'system': systemPrompt,
      'messages': messages,
    });

    final response = await http
        .post(url, headers: headers, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final content = decoded['content'] as List<dynamic>;
      if (content.isNotEmpty) {
        return (content.first as Map<String, dynamic>)['text'] as String;
      }
      throw const ClaudeApiException('Empty content in response');
    } else if (response.statusCode == 429) {
      throw const ClaudeApiException(
          'Rate limit exceeded. Please wait a moment.');
    } else {
      throw ClaudeApiException(
        'Service error (${response.statusCode})',
      );
    }
  }
}

/// Thrown when the client is in offline mode (no backend configured).
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
