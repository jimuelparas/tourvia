import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

/// Service that connects to Google Gemini (Step 11 / US-21).
///
/// Enforces a Philippines-only tourism scope via the system prompt.
/// API key is loaded from the `.env` asset file via flutter_dotenv.
class ChatbotService {
  ChatbotService._();

  static const String _modelName = 'gemini-1.5-flash';

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

  /// Sends [userMessage] to Gemini and returns the assistant's reply.
  ///
  /// Throws an [Exception] on network or API errors.
  static Future<String> ask(String userMessage) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file.');
    }

    try {
      final model = GenerativeModel(
        model: _modelName,
        apiKey: apiKey,
        systemInstruction: Content.system(_systemPrompt),
        generationConfig: GenerationConfig(
          temperature: 0.7,
          maxOutputTokens: 512,
        ),
      );

      final content = [Content.text(userMessage)];
      final response = await model.generateContent(content);

      if (response.text == null || response.text!.isEmpty) {
        throw Exception('Empty response from Gemini.');
      }
      return response.text!.trim();
    } catch (e) {
      if (e.toString().contains('429')) {
        throw Exception('Rate limit reached. Please wait a moment and try again.');
      } else if (e.toString().contains('API key not valid') || e.toString().contains('400')) {
        throw Exception('Invalid API key. Please check your .env configuration.');
      } else {
        throw Exception('Gemini API error: \$e');
      }
    }
  }
}
