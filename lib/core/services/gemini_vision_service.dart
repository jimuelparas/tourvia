import 'dart:convert';
import 'dart:typed_data';

import '../config/app_config.dart';
import 'package:http/http.dart' as http;

/// Result from Gemini Vision ID verification.
class GeminiIdVerificationResult {
  /// Whether the uploaded image is a valid Philippine government-issued ID.
  final bool isValidId;

  /// Whether the uploaded document does not match the selected ID type.
  final bool isTypeMismatch;

  /// Whether the name on the ID matches the registered user's name.
  final bool isNameMatch;

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
      isValidId &&
      !isTypeMismatch &&
      isNameMatch &&
      !isExpired &&
      isImageClear &&
      failureReason == null;

  /// Legacy getter kept for backward compatibility with existing UI code.
  bool get isOfficialDotId => isValidId && !isTypeMismatch;

  const GeminiIdVerificationResult({
    required this.isValidId,
    this.isTypeMismatch = false,
    this.isNameMatch = true,
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
      isTypeMismatch: json['isTypeMismatch'] as bool? ?? false,
      isNameMatch: json['isNameMatch'] as bool? ?? true,
      detectedIdType: json['detectedIdType'] as String?,
      extractedName: json['extractedName'] as String?,
      extractedIdNumber: json['extractedIdNumber'] as String?,
      accreditationType: json['accreditationType'] as String?,
      expiryDate: json['expiryDate'] as String?,
      isExpired: json['isExpired'] as bool? ?? false,
      isImageClear: json['isImageClear'] as bool? ?? true,
      failureReason: json['failureReason'] as String?,
    );
  }

  factory GeminiIdVerificationResult.failed(String reason, {bool isTypeMismatch = false}) {
    return GeminiIdVerificationResult(
      isValidId: false,
      isTypeMismatch: isTypeMismatch,
      isNameMatch: false,
      isExpired: true,
      isImageClear: false,
      failureReason: reason,
    );
  }
}

/// Service for verifying Tour Guide IDs using Google Gemini Vision API.
///
/// Strictly distinguishes between:
/// 1. "DOT Tour Guide ID" (Department of Tourism Accredited Tour Guide ID)
/// 2. "Barangay ID" (Barangay Local Government ID Card with Photo)
class GeminiVisionService {
  GeminiVisionService._();

  /// Builds the Gemini verification prompt for [idType] and optional [expectedName].
  static String _buildVerificationPrompt(String idType, {String? expectedName}) {
    final nameInstruction = expectedName != null && expectedName.trim().isNotEmpty
        ? 'The user is registering as a Tour Guide with the declared name: "$expectedName".'
        : '';

    return '''
You are an AI verification system for Tour Guide registration in the Philippines.
$nameInstruction
The user selected the following ID type: "$idType".

Allowed Tour Guide ID categories:
1. "DOT Tour Guide ID": Official Department of Tourism (DOT) Tour Guide Accreditation ID card.
2. "Barangay ID": Official Barangay Government-issued ID card with photo.

Analyze the uploaded image and perform the following checks:

1. **ID Type Matching**:
   - Determine what document was uploaded.
   - If selected "$idType" is "DOT Tour Guide ID":
     The uploaded image MUST be an official Department of Tourism (DOT) Tour Guide Accreditation ID card. If the user uploaded a Barangay ID, Driver's License, or other document, set "isTypeMismatch": true, "isValidId": false, and "failureReason": "The uploaded ID does not match the selected ID type."
   - If selected "$idType" is "Barangay ID" or contains "Barangay":
     The uploaded image MUST be a Barangay-issued document from the Philippines. Philippine Barangay IDs have NO standardized national format — each Barangay designs their own. Common legitimate formats include:
       • A simple paper or cardboard card (often hand-laminated) with a pasted 1x1 or 2x2 photo
       • A Barangay Clearance or Certificate of Residency WITH a photo of the holder attached
       • A printed or handwritten card bearing the Barangay name/seal, resident name, address, and Punong Barangay (Captain) signature
     ALL of these are valid Barangay IDs. Accept them as long as the document shows: (1) a Barangay name or seal, (2) the holder's name, and (3) a photo of the holder (pasted or printed).
     Only reject if the uploaded image is clearly a completely different type of document (e.g. DOT ID, driver's license, passport, school ID) or not an ID at all.
   - If the image is not a valid Philippine ID at all (e.g. selfie, receipt, random screenshot), set "isValidId": false, "isTypeMismatch": false, and "failureReason": "The uploaded image is not a recognized ID document."

2. **Name Matching (LENIENT)**:
   - Extract the name on the ID.
   - If an expected name was provided ("$expectedName"), compare it with the name on the ID.
   - Philippine IDs display names in various formats: "LAST, FIRST MIDDLE", "FIRST MIDDLE LAST", "FIRST M. LAST", all uppercase, etc.
   - Perform a FLEXIBLE match: if the first name AND last name from the expected name both appear anywhere on the ID (regardless of order, casing, abbreviations, or middle name differences), set "isNameMatch": true.
   - Only set "isNameMatch": false if the first name or last name is COMPLETELY DIFFERENT (not just reordered or abbreviated).
   - If no expected name was provided, set "isNameMatch": true.

3. **Readability & Image Quality**:
   - Check if the image is clear and readable.
   - If the image is too blurry, cropped, dark, or glaring so text cannot be examined, set "isImageClear": false and "failureReason": "The uploaded ID image is blurry or unreadable. Please upload a clear photo."

4. **Expiry Check**:
   - Check if an expiry date is visible and whether it has passed. If expired, set "isExpired": true and "failureReason": "The uploaded ID has expired."
   - If no expiry date is shown (common on Barangay documents), set "isExpired": false.

Respond ONLY with a valid JSON object in exactly this format:
{
  "isValidId": true/false,
  "isTypeMismatch": true/false,
  "isNameMatch": true/false,
  "detectedIdType": "string or null",
  "extractedName": "string or null",
  "extractedIdNumber": "string or null",
  "accreditationType": "string or null",
  "expiryDate": "YYYY-MM-DD or null",
  "isExpired": true/false,
  "isImageClear": true/false,
  "failureReason": "string explaining failure or null if all checks pass"
}
''';
  }

  /// Verifies a Tour Guide ID image using Google Gemini Vision API.
  ///
  /// [imageBytes]   - The raw bytes of the uploaded ID image.
  /// [idType]       - "DOT Tour Guide ID" or "Barangay ID".
  /// [expectedName] - Optional full name of the registering user for name cross-validation.
  /// [mimeType]     - The MIME type of the image (e.g. 'image/jpeg', 'image/png').
  static Future<GeminiIdVerificationResult> verifyTourGuideId(
    Uint8List imageBytes, {
    String idType = 'DOT Tour Guide ID',
    String? expectedName,
    String mimeType = 'image/jpeg',
  }) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey == null || apiKey.isEmpty) {
      return GeminiIdVerificationResult.failed(
        'Gemini API key not configured. Please set GEMINI_API_KEY in environment or .env.',
      );
    }

    final base64Image = base64Encode(imageBytes);
    final prompt = _buildVerificationPrompt(idType, expectedName: expectedName);

    final candidateModels = ['gemini-3.6-flash', 'gemini-3.8-flash', 'gemini-flash-latest', 'gemini-2.0-flash', 'gemini-1.5-flash'];

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
        } else if (response.statusCode == 404 || response.statusCode == 429 || response.statusCode == 503) {
          // Try next candidate model (404=not found, 429=rate limit, 503=overloaded)
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

    final lastCode = lastResponse?.statusCode;
    String fallbackMsg;
    if (lastCode == 503) {
      fallbackMsg =
          'The AI verification service is currently experiencing high demand. '
          'Please wait a moment and try again.';
    } else if (lastResponse != null) {
      fallbackMsg = 'Gemini API error ($lastCode)';
    } else {
      fallbackMsg = 'Unable to connect to Gemini Vision service.';
    }
    return GeminiIdVerificationResult.failed(fallbackMsg);
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

