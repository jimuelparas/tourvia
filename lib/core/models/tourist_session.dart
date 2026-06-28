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
}

/// Singleton-style holder so any screen can access the current tourist session.
class TouristSessionManager {
  TouristSessionManager._();

  static TouristSession? _current;

  static TouristSession? get current => _current;

  static void set(TouristSession session) => _current = session;

  static void clear() => _current = null;

  static bool get isLoggedIn => _current != null;
}
