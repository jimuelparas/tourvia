import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service that connects to OpenAI's Chat Completions API (Step 11 / US-21).
///
/// Enforces a Philippines-only tourism scope via the system prompt.
/// API key is loaded from the `.env` asset file via flutter_dotenv.
class ChatbotService {
  ChatbotService._();

  static const String _endpoint =
      'https://api.openai.com/v1/chat/completions';

  static const String _model = 'gpt-4o-mini';

  /// System prompt that restricts the AI to Philippine tourism topics only.
  static const String _systemPrompt = '''
You are a helpful tour assistant for Tourvia, a Philippine tourism app.
Your role is to help tourists discover and learn about tourist destinations,
culture, food, festivals, travel tips, and local attractions in the Philippines.

Guidelines:
- Only answer questions about tourist destinations and travel in the Philippines.
- If asked about destinations, attractions, or travel topics outside the Philippines
  (e.g., Paris, Tokyo, New York), politely decline and redirect the user to
  Philippine destinations instead.
- Be enthusiastic, friendly, and informative.
- Provide practical travel tips when relevant (best time to visit, how to get there,
  what to eat, what to bring, etc.).
- Keep responses concise and easy to read — use bullet points when listing options.
- Respond in the same language the user uses (Filipino or English).
''';

  /// Sends [userMessage] to OpenAI and returns the assistant's reply.
  ///
  /// Throws an [Exception] on network or API errors.
  static Future<String> ask(String userMessage) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('OpenAI API key not found in .env file.');
    }

    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      },
      body: jsonEncode({
        'model': _model,
        'messages': [
          {'role': 'system', 'content': _systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': 0.7,
        'max_tokens': 512,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>;
      if (choices.isEmpty) throw Exception('Empty response from OpenAI.');
      final message = choices[0]['message'] as Map<String, dynamic>;
      return (message['content'] as String).trim();
    } else if (response.statusCode == 429) {
      throw Exception('Rate limit reached. Please wait a moment and try again.');
    } else if (response.statusCode == 401) {
      throw Exception('Invalid API key. Please check your .env configuration.');
    } else {
      final body = jsonDecode(response.body);
      final errMsg = body['error']?['message'] ?? 'Unknown error';
      throw Exception('OpenAI API error (${response.statusCode}): $errMsg');
    }
  }
}
