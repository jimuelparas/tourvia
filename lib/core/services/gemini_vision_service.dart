import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

/// Result from Gemini Vision ID verification.
class GeminiIdVerificationResult {
  /// Whether the uploaded image is an official DOT Tour Guide ID.
  final bool isOfficialDotId;

  /// Extracted full name from the ID (if detected).
  final String? extractedName;

  /// Extracted ID number from the card (if detected).
  final String? extractedIdNumber;

  /// Accreditation type (e.g. Regional, National).
  final String? accreditationType;

  /// Expiry date as a string (e.g. "2026-12-31").
  final String? expiryDate;

  /// Whether the ID has expired based on the date on the card.
  final bool isExpired;

  /// Whether the uploaded image is clear, complete, and not blurry/cropped.
  final bool isImageClear;

  /// If verification failed, the reason why.
  final String? failureReason;

  /// Whether ALL checks passed and the ID is verified.
  bool get isVerified =>
      isOfficialDotId && !isExpired && isImageClear && failureReason == null;

  const GeminiIdVerificationResult({
    required this.isOfficialDotId,
    this.extractedName,
    this.extractedIdNumber,
    this.accreditationType,
    this.expiryDate,
    required this.isExpired,
    required this.isImageClear,
    this.failureReason,
  });

  factory GeminiIdVerificationResult.fromJson(Map<String, dynamic> json) {
    return GeminiIdVerificationResult(
      isOfficialDotId: json['isOfficialDotId'] as bool? ?? false,
      extractedName: json['extractedName'] as String?,
      extractedIdNumber: json['extractedIdNumber'] as String?,
      accreditationType: json['accreditationType'] as String?,
      expiryDate: json['expiryDate'] as String?,
      isExpired: json['isExpired'] as bool? ?? true,
      isImageClear: json['isImageClear'] as bool? ?? false,
      failureReason: json['failureReason'] as String?,
    );
  }

  factory GeminiIdVerificationResult.failed(String reason) {
    return GeminiIdVerificationResult(
      isOfficialDotId: false,
      isExpired: true,
      isImageClear: false,
      failureReason: reason,
    );
  }
}

/// Service for verifying DOT Tour Guide IDs using Google Gemini Vision API.
///
/// Sends the uploaded ID image to Gemini for AI-powered verification including:
/// - Official DOT logo and header detection
/// - ID layout/format validation
/// - Name, ID Number, Accreditation Type, and Expiry Date extraction
/// - Expiry date validation
/// - Image quality check (blur, crop)
class GeminiVisionService {
  GeminiVisionService._();

  /// The system prompt that instructs Gemini to verify the DOT Tour Guide ID.
  static const String _verificationPrompt = '''
You are an AI ID verification system for the Philippine Department of Tourism (DOT) Tour Guide ID.

Analyze the uploaded image and determine if it is an authentic, valid DOT Tour Guide ID.

Perform the following checks IN ORDER:

1. **Official DOT ID Detection**: Check for the presence of:
   - The official Department of Tourism (DOT) logo
   - "Republic of the Philippines" text
   - "Department of Tourism" text/header
   If these official elements are NOT detected, immediately reject the ID.

2. **ID Layout & Format**: Verify the card follows the official DOT Tour Guide ID layout and format (photo, name, ID number, accreditation details).

3. **Data Extraction**: Extract the following fields:
   - Full Name
   - ID Number
   - Accreditation Type (e.g. Regional, National)
   - Expiry Date

4. **Expiry Check**: Determine if the ID has expired based on the expiry date shown on the card. Today's date is used for comparison.

5. **Image Quality**: Check if the uploaded image is:
   - Clear and readable (not blurry)
   - Complete (not cropped, all edges visible)
   - Well-lit (text is legible)

Respond ONLY with a valid JSON object (no markdown, no code fences, no extra text) in exactly this format:
{
  "isOfficialDotId": true/false,
  "extractedName": "string or null",
  "extractedIdNumber": "string or null",
  "accreditationType": "string or null",
  "expiryDate": "YYYY-MM-DD or null",
  "isExpired": true/false,
  "isImageClear": true/false,
  "failureReason": "string explaining failure or null if all checks pass"
}

If the image is NOT a DOT Tour Guide ID at all, set isOfficialDotId to false and provide a clear failureReason. Do NOT extract fields from non-DOT IDs.
''';

  /// Verifies a DOT Tour Guide ID image using Google Gemini Vision API.
  ///
  /// [imageBytes] - The raw bytes of the uploaded ID image.
  /// [mimeType] - The MIME type of the image (e.g. 'image/jpeg', 'image/png').
  ///
  /// Returns a [GeminiIdVerificationResult] with the verification outcome.
  static Future<GeminiIdVerificationResult> verifyTourGuideId(
    Uint8List imageBytes, {
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    if (apiKey == null || apiKey.isEmpty || apiKey == 'your_key_here') {
      return GeminiIdVerificationResult.failed(
        'Gemini API key not configured. Please add GEMINI_API_KEY to .env.',
      );
    }

    final base64Image = base64Encode(imageBytes);

    final candidateModels = ['gemini-3.6-flash', 'gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.0-flash', 'gemini-1.5-flash'];

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _verificationPrompt},
            {
              'inline_data': {
                'mime_type': mimeType,
                'data': base64Image,
              },
            },
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0.1,
        'maxOutputTokens': 1024,
      },
    });

    http.Response? lastResponse;
    for (final modelName in candidateModels) {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        '$modelName:generateContent?key=$apiKey',
      );

      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );

        lastResponse = response;
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final candidates = data['candidates'] as List<dynamic>?;
          if (candidates == null || candidates.isEmpty) {
            return GeminiIdVerificationResult.failed(
              'No response from Gemini. Please try again.',
            );
          }

          final text = candidates[0]['content']?['parts']?[0]?['text'] as String?;
          if (text == null || text.isEmpty) {
            return GeminiIdVerificationResult.failed(
              'Gemini returned an empty response.',
            );
          }

          final jsonStr = _extractJson(text);
          if (jsonStr == null) {
            return GeminiIdVerificationResult.failed(
              'Could not parse verification results from Gemini.',
            );
          }

          final parsed = jsonDecode(jsonStr) as Map<String, dynamic>;
          return GeminiIdVerificationResult.fromJson(parsed);
        } else if (response.statusCode == 404 || response.statusCode == 429) {
          // Try next candidate model
          continue;
        } else {
          final errBody = jsonDecode(response.body);
          final errMsg = errBody['error']?['message'] ?? 'Unknown error';
          return GeminiIdVerificationResult.failed(
            'Gemini API error (${response.statusCode}): $errMsg',
          );
        }
      } catch (_) {
        continue;
      }
    }

    return GeminiIdVerificationResult.failed(
      lastResponse != null
          ? 'Gemini API error (${lastResponse.statusCode})'
          : 'Unable to connect to Gemini Vision service.',
    );
  }

  static String? _extractJson(String raw) {
    String text = raw.trim();
    if (text.startsWith('```')) {
      text = text
          .replaceFirst(RegExp(r'^```json?\s*'), '')
          .replaceFirst(RegExp(r'```\s*$'), '')
          .trim();
    }
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start != -1 && end != -1 && end > start) {
      return text.substring(start, end + 1);
    }
    return text;
  }
}

