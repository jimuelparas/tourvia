import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds in-memory session context for a logged-in tourist.
/// Tourists do NOT have Firebase Auth accounts — their identity
/// is tied to an access code and a session.
class TouristSession {
  /// The code doc ID in Firestore (e.g. "TRV-A1B2C3")
  final String code;

  /// The tourist's display name (entered on first login)
  final String touristName;

  /// Firestore session ID (the parent tour_sessions document)
  final String sessionId;

  /// The Firestore code doc ID (used for updates)
  final String codeDocId;

  const TouristSession({
    required this.code,
    required this.touristName,
    required this.sessionId,
    required this.codeDocId,
  });

  Map<String, dynamic> toJson() => {
        'code': code,
        'touristName': touristName,
        'sessionId': sessionId,
        'codeDocId': codeDocId,
      };

  factory TouristSession.fromJson(Map<String, dynamic> json) => TouristSession(
        code: json['code'] as String,
        touristName: json['touristName'] as String,
        sessionId: json['sessionId'] as String,
        codeDocId: json['codeDocId'] as String,
      );
}

/// Singleton-style holder so any screen can access the current tourist session.
class TouristSessionManager {
  TouristSessionManager._();

  static TouristSession? _current;

  static TouristSession? get current => _current;

  static const String _prefKey = 'tourvia_tourist_session';

  static Future<void> loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_prefKey);
    if (data != null) {
      try {
        _current = TouristSession.fromJson(jsonDecode(data));
      } catch (e) {
        _current = null;
      }
    }
  }

  static Future<void> set(TouristSession session) async {
    _current = session;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, jsonEncode(session.toJson()));
  }

  static Future<void> clear() async {
    _current = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKey);
  }

  static bool get isLoggedIn => _current != null;
}
