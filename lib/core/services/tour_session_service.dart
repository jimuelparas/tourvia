import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the metadata of a tour session (US-06 / Itinerary active banner).
class TourSession {
  final String sessionId;
  final String tourName;
  final int totalDays;
  final int currentDay;
  final String? guideId;
  final String? guideName;

  const TourSession({
    required this.sessionId,
    required this.tourName,
    required this.totalDays,
    required this.currentDay,
    this.guideId,
    this.guideName,
  });

  factory TourSession.fromFirestore(String id, Map<String, dynamic> data) {
    return TourSession(
      sessionId: id,
      tourName: data['tourName'] as String? ?? 'Unnamed Tour',
      totalDays: data['totalDays'] as int? ?? 3,
      currentDay: data['currentDay'] as int? ?? 1,
      guideId: data['guideId'] as String?,
      guideName: data['guideName'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'tourName': tourName,
      'totalDays': totalDays,
      'currentDay': currentDay,
      'guideId': guideId,
      'guideName': guideName,
    };
  }
}

/// Service to manage tour session documents.
class TourSessionService {
  TourSessionService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Returns a stream of [TourSession] for a given [sessionId].
  /// If the document doesn't exist, we return a default TourSession and
  /// trigger an asynchronous write to create the document in Firestore.
  static Stream<TourSession> watchSession(String sessionId) {
    return _db.collection('tour_sessions').doc(sessionId).snapshots().map((doc) {
      if (!doc.exists) {
        // Asynchronously initialize the document so it is present in Firestore.
        ensureSessionExists(sessionId);
        return TourSession(
          sessionId: sessionId,
          tourName: 'Unnamed Tour',
          totalDays: 3,
          currentDay: 1,
        );
      }
      return TourSession.fromFirestore(doc.id, doc.data()!);
    });
  }

  /// Ensures a tour session document exists in Firestore.
  static Future<void> ensureSessionExists(String sessionId) async {
    final docRef = _db.collection('tour_sessions').doc(sessionId);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'tourName': 'Unnamed Tour',
        'totalDays': 3,
        'currentDay': 1,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Updates the guide's name and ID in the session.
  static Future<void> updateGuideInfo(String sessionId, String guideId, String guideName) async {
    await _db.collection('tour_sessions').doc(sessionId).set({
      'guideId': guideId,
      'guideName': guideName,
    }, SetOptions(merge: true));
  }

  /// Updates the tour session metadata.
  static Future<void> updateSession(
    String sessionId, {
    required String tourName,
    required int currentDay,
    required int totalDays,
  }) async {
    await _db.collection('tour_sessions').doc(sessionId).update({
      'tourName': tourName,
      'currentDay': currentDay,
      'totalDays': totalDays,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
