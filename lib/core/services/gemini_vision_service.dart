import 'dart:convert';
import 'dart:typed_data';

import '../config/app_config.dart';
import 'package:http/http.dart' as http;

/// Result from Gemini Vision ID verification.
class GeminiIdVerificationResult {
  /// Whether the uploaded image is a valid Philippine government-issued ID
  /// matching the declared [idType]. (Replaces isOfficialDotId — Step 7)
  final bool isValidId;

  /// The detected/confirmed ID type from the card.
  final String? detectedIdType;

  /// Extracted full name from the ID (if detected).
  final String? extractedName;

  /// Extracted ID number from the card (if detected).
  final String? extractedIdNumber;

  /// Accreditation type (e.g. Regional, National — DOT IDs only).
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
      isValidId && !isExpired && isImageClear && failureReason == null;

  /// Legacy getter kept for backward compatibility with existing UI code.
  bool get isOfficialDotId => isValidId;

  const GeminiIdVerificationResult({
    required this.isValidId,
    this.detectedIdType,
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
      isValidId: json['isValidId'] as bool? ??
          json['isOfficialDotId'] as bool? ??
          false,
      detectedIdType: json['detectedIdType'] as String?,
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
      isValidId: false,
      isExpired: true,
      isImageClear: false,
      failureReason: reason,
    );
  }
}

/// Service for verifying Philippine government-issued IDs using Google Gemini Vision API.
///
/// Accepts any of the 9 supported Philippine ID types (REV-001 Step 7):
/// - Barangay ID / Barangay Clearance with Photo
/// - Philippine National ID (PhilID / ePhilID)
/// - Driver's License (LTO)
/// - Philippine Passport (DFA)
/// - UMID / SSS / GSIS ID
/// - Postal ID (PhilPost)
/// - Voter's ID / Comelec Certificate
/// - PRC ID (Professional Regulation Commission)
/// - DOT Tour Guide Accreditation ID
class GeminiVisionService {
  GeminiVisionService._();

  /// Builds the Gemini verification prompt for a specific [idType].
  /// Step 9 — Updated to recognize and validate expanded Philippine ID types.
  static String _buildVerificationPrompt(String idType) {
    return '''
You are an AI ID verification system for Philippine government-issued identification documents.
The user has declared that they are submitting a: "$idType".

Supported Philippine IDs that you MUST recognize and accept:
1. Barangay ID / Barangay Clearance with Photo
2. Philippine National ID (PhilID / ePhilID)
3. Driver's License (LTO)
4. Philippine Passport (DFA)
5. UMID / SSS / GSIS ID
6. Postal ID (PhilPost)
7. Voter's ID / Comelec Certificate
8. PRC ID (Professional Regulation Commission)
9. DOT Tour Guide Accreditation ID

Analyze the uploaded image and perform the following checks IN ORDER:

1. **ID Type Detection**: Confirm whether the uploaded image matches the declared type ("$idType") or is at least one of the 9 supported Philippine IDs listed above.
   - Set "isValidId" to true ONLY if it is a valid, recognizable Philippine government or local government ID from the list above.
   - Set "detectedIdType" to the actual ID type you detected (e.g. "Barangay ID", "Philippine National ID").
   - If the image is NOT an ID at all (e.g. selfie, random document), set isValidId to false.

2. **Data Extraction**: Extract as much of the following as visible on the card:
   - Full Name of the ID holder
   - ID Number / Reference Number
   - Expiry Date (if present — not all Philippine IDs have expiry dates; set to null if absent)
   - Accreditation Type (only applicable to DOT Tour Guide IDs; null for others)

3. **Expiry Check**: If an expiry date is shown, determine if the ID has expired. If no expiry date is visible, set "isExpired" to false.

4. **Image Quality**: Check if the uploaded image is:
   - Clear and readable (not blurry)
   - Complete (not cropped, all four edges visible)
   - Well-lit (text and photo are legible)

Respond ONLY with a valid JSON object (no markdown, no code fences, no extra text) in exactly this format:
{
  "isValidId": true/false,
  "detectedIdType": "string or null",
  "extractedName": "string or null",
  "extractedIdNumber": "string or null",
  "accreditationType": "string or null",
  "expiryDate": "YYYY-MM-DD or null",
  "isExpired": true/false,
  "isImageClear": true/false,
  "failureReason": "string explaining failure or null if all checks pass"
}

If the image is not a valid Philippine government ID, set isValidId to false and provide a clear failureReason.
''';
  }

  /// Verifies a Philippine government-issued ID image using Google Gemini Vision API.
  ///
  /// [imageBytes] - The raw bytes of the uploaded ID image.
  /// [idType]     - The declared ID type selected by the user (Step 8).
  /// [mimeType]   - The MIME type of the image (e.g. 'image/jpeg', 'image/png').
  ///
  /// Returns a [GeminiIdVerificationResult] with the verification outcome.
  static Future<GeminiIdVerificationResult> verifyTourGuideId(
    Uint8List imageBytes, {
    String idType = 'Philippine Government ID',
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return GeminiIdVerificationResult.failed(
        'Gemini API key not configured. Please set GEMINI_API_KEY in environment or .env.',
      );
    }

    final base64Image = base64Encode(imageBytes);
    final prompt = _buildVerificationPrompt(idType);

    final candidateModels = ['gemini-3.6-flash', 'gemini-2.5-flash', 'gemini-flash-latest', 'gemini-2.0-flash', 'gemini-1.5-flash'];

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
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

