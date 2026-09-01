import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import 'package:http/http.dart' as http;
import '../../features/chat/models/chat_message.dart';

/// Service that connects to Google Gemini (Step 11 / US-21).
///
/// Enforces a Philippines-only tourism scope via the system prompt.
/// API key is loaded from the AppConfig (supports `.env` asset file and compile-time environment variables).
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

  static const String _historyKey = 'tourvia_chatbot_history';
  static final List<ChatMessage> _messages = [];

  /// Get the current chatbot message list
  static List<ChatMessage> get messages => _messages;

  /// Loads chatbot history from SharedPreferences.
  /// If empty, initializes with default greeting.
  static Future<List<ChatMessage>> loadHistory() async {
    if (_messages.isNotEmpty) {
      return _messages;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString(_historyKey);
      if (historyJson != null) {
        final decoded = jsonDecode(historyJson) as List<dynamic>;
        _messages.clear();
        for (final item in decoded) {
          final map = item as Map<String, dynamic>;
          _messages.add(ChatMessage(
            id: map['id'] as String? ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
            senderId: map['senderId'] as String? ?? 'ai_bot',
            senderName: map['senderName'] as String? ?? 'Tourvia AI',
            text: map['text'] as String? ?? '',
            timestamp: DateTime.parse(map['timestamp'] as String? ?? DateTime.now().toIso8601String()),
            isGuide: map['isGuide'] as bool? ?? true,
            isMedia: map['isMedia'] as bool? ?? false,
            mediaUrl: map['mediaUrl'] as String?,
          ));
        }
      }
    } catch (e) {
      // Fallback: list remains empty or retains partial load
    }

    if (_messages.isEmpty) {
      _messages.add(ChatMessage(
        id: 'bot0',
        senderId: 'ai_bot',
        senderName: 'Tourvia AI',
        text: "Hello! 👋 I'm your Tourvia Assistant powered by AI. Ask me anything about Philippine tourist spots!",
        timestamp: DateTime.now(),
        isGuide: true,
      ));
    }

    return _messages;
  }

  /// Saves the current list of chatbot messages to SharedPreferences.
  static Future<void> saveHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = _messages.map((msg) => {
        'id': msg.id,
        'senderId': msg.senderId,
        'senderName': msg.senderName,
        'text': msg.text,
        'timestamp': msg.timestamp.toIso8601String(),
        'isGuide': msg.isGuide,
        'isMedia': msg.isMedia,
        'mediaUrl': msg.mediaUrl,
      }).toList();
      await prefs.setString(_historyKey, jsonEncode(list));
    } catch (e) {
      // Silent error
    }
  }

  /// Clears the chatbot history from both memory and SharedPreferences.
  static Future<void> clearHistory() async {
    _messages.clear();
    _messages.add(ChatMessage(
      id: 'bot0',
      senderId: 'ai_bot',
      senderName: 'Tourvia AI',
      text: "Hello! 👋 I'm your Tourvia Assistant powered by AI. Ask me anything about Philippine tourist spots!",
      timestamp: DateTime.now(),
      isGuide: true,
    ));
    await saveHistory();
  }

  /// Sends [userMessage] along with the conversation history to Gemini REST API and returns the assistant's reply.
  static Future<String> ask(String userMessage) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('Gemini API key is not configured. Please set GEMINI_API_KEY in your environment or assets/env/.env.');
    }

    final candidateModels = [
      'gemini-3.6-flash',
      'gemini-2.5-flash',
    ];

    // Build the contents array from chat history for conversation context (max 20 messages)
    final contents = <Map<String, dynamic>>[];
    
    // Filter out error messages
    final validHistory = _messages.where((msg) => !msg.id.startsWith('err_')).toList();
    
    // Build alternating user/model turns starting from the end
    final List<ChatMessage> alternatingMessages = [];
    String? lastRole;
    
    for (int i = validHistory.length - 1; i >= 0; i--) {
      final msg = validHistory[i];
      final role = (msg.senderId == 'current_user') ? 'user' : 'model';
      
      if (role == lastRole) {
        continue;
      }
      
      alternatingMessages.insert(0, msg);
      lastRole = role;
      
      if (alternatingMessages.length >= 20) {
        break;
      }
    }

    // Ensure the list starts with a user message as required by Gemini API
    while (alternatingMessages.isNotEmpty && alternatingMessages.first.senderId != 'current_user') {
      alternatingMessages.removeAt(0);
    }

    // Map to API format
    for (final msg in alternatingMessages) {
      final role = (msg.senderId == 'current_user') ? 'user' : 'model';
      contents.add({
        'role': role,
        'parts': [
          {'text': msg.text}
        ]
      });
    }

    // Fallback if empty to ensure we at least send the user message
    if (contents.isEmpty) {
      contents.add({
        'role': 'user',
        'parts': [
          {'text': userMessage}
        ]
      });
    }

    final body = jsonEncode({
      'contents': contents,
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
