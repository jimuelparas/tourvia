import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized configuration helper for API keys and environment parameters.
/// Supports both `--dart-define` / CI environment variables and `.env` files.
class AppConfig {
  AppConfig._();

  /// Retrieves the Gemini API key.
  /// 1. Checks compile-time environment variable (`--dart-define=GEMINI_API_KEY=...`).
  /// 2. If empty, safely checks `flutter_dotenv` if it was successfully initialized.
  static String? get geminiApiKey {
    // Check compile-time environment variable (used by CI/CD such as Codemagic)
    const envKey = String.fromEnvironment('GEMINI_API_KEY');
    if (envKey.isNotEmpty && envKey != 'your_key_here') {
      return envKey;
    }

    // Check flutter_dotenv if initialized from assets/env/.env
    if (dotenv.isInitialized) {
      final key = dotenv.maybeGet('GEMINI_API_KEY') ?? dotenv.maybeGet('OPENAI_API_KEY');
      if (key != null && key.trim().isNotEmpty && key != 'your_key_here') {
        return key.trim();
      }
    }

    return null;
  }
}
