import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Service that connects to Google Gemini (Step 11 / US-21).
///
/// Enforces a Philippines-only tourism scope via the system prompt.
/// API key is loaded from the `.env` asset file via flutter_dotenv.
class ChatbotService {
  ChatbotService._();

  /// System prompt that strictly enforces a Philippines-only tourism scope.
  static const String _systemPrompt = '''
You are Tourvia AI, an intelligent, enthusiastic travel assistant dedicated EXCLUSIVELY to tourism, travel, culture, history, geography, food, and attractions in the PHILIPPINES.

STRICT NON-PHILIPPINES REFUSAL POLICY:
- If the user asks about ANY destination, city, region, landmark, or country outside the Philippines (e.g., Tokyo, Japan, Paris, France, New York, USA, Singapore, Thailand, Bali, etc.), or asks general non-travel/non-Philippine questions, you MUST IMMEDIATELY and POLITELY REFUSE.
- Your refusal MUST state:
  "I am Tourvia AI, an assistant dedicated exclusively to Philippine travel and tourism. I cannot provide information about destinations outside the Philippines. Please feel free to ask me about any of the 7,641 islands, destinations, food, or activities in the Philippines!"
- Do NOT provide even partial information or comparisons about foreign destinations.

RESPONSE FORMATTING (Gemini Design Style):
- Provide clear, rich, and well-structured responses formatted in Markdown.
- Start with a captivating introductory paragraph defining the destination (e.g. its location, nickname, and why it is special).
- Use clear numbered/bold sections such as:
  1. Climate & Atmosphere (or Overview)
  2. Key Attractions & Landmarks (with bullet points and bold titles)
  3. Culture, Activities & Experiences
  4. Must-Try Local Food & Delicacies
  5. Practical Travel Tips & Best Time to Visit
- Use bullet points (`- **Attraction Name:** Description`) with clear descriptions.
- Respond in the language of the user (Filipino, English, or Taglish).
''';

  /// Sends [userMessage] to Gemini REST API and returns the assistant's reply.
  static Future<String> ask(String userMessage) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'] ?? dotenv.env['OPENAI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('GEMINI_API_KEY not found in .env file.');
    }

    final candidateModels = [
      'gemini-3.6-flash',
      'gemini-2.5-flash',
      'gemini-flash-latest',
      'gemini-2.0-flash',
      'gemini-1.5-flash',
    ];

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': userMessage}
          ]
        }
      ],
      'systemInstruction': {
        'parts': [
          {'text': _systemPrompt}
        ]
      },
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 2048,
      },
    });

    String? lastError;
    for (final model in candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
      );

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates != null && candidates.isNotEmpty) {
            final text =
                candidates[0]['content']?['parts']?[0]?['text'] as String?;
            if (text != null && text.isNotEmpty) {
              return text.trim();
            }
          }
        } else if (response.statusCode == 429) {
          lastError = 'Rate limit reached on $model. Trying next available model...';
          continue;
        } else if (response.statusCode == 400 || response.statusCode == 403) {
          final err = jsonDecode(response.body);
          lastError =
              err['error']?['message'] ?? 'API Error ${response.statusCode}';
          if (lastError?.contains('API key not valid') ?? false) {
            throw Exception(
                'Invalid API key. Please check your .env configuration.');
          }
        } else {
          final err = jsonDecode(response.body);
          lastError =
              err['error']?['message'] ?? 'Error ${response.statusCode}';
        }
      } catch (e) {
        if (e.toString().contains('Rate limit') ||
            e.toString().contains('Invalid API key')) {
          rethrow;
        }
        lastError = e.toString();
      }
    }

    throw Exception(lastError ?? 'Could not get response from Gemini.');
  }
}
