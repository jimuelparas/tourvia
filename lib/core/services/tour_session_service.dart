import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the metadata of a tour session (US-06 / Itinerary active banner).
class TourSession {
  final String sessionId;
  final String tourName;
  final int totalDays;
  final int currentDay;
  final String? guideId;
  final String? guideName;
  final String status; // 'active' | 'ended'

  const TourSession({
    required this.sessionId,
    required this.tourName,
    required this.totalDays,
    required this.currentDay,
    this.guideId,
    this.guideName,
    this.status = 'active',
  });

  bool get isActive => status == 'active';
  bool get isEnded => status == 'ended';

  factory TourSession.fromFirestore(String id, Map<String, dynamic> data) {
    return TourSession(
      sessionId: id,
      tourName: data['tourName'] as String? ?? 'Unnamed Tour',
      totalDays: data['totalDays'] as int? ?? 3,
      currentDay: data['currentDay'] as int? ?? 1,
      guideId: data['guideId'] as String?,
      guideName: data['guideName'] as String?,
      status: data['status'] as String? ?? 'active',
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

  /// Returns a stream of [TourSession] for a given [sessionId] (tourId).
  /// Connects directly to /tours/{tourId} and falls back to /tour_sessions/{tourId}.
  static Stream<TourSession> watchSession(String sessionId) {
    return _db.collection('tours').doc(sessionId).snapshots().asyncMap((tourDoc) async {
      if (tourDoc.exists && tourDoc.data() != null) {
        final data = tourDoc.data()!;
        final name = data['name'] as String? ?? 'Unnamed Tour';
        final totalDays = (data['totalDays'] as num?)?.toInt() ?? 1;
        final guideId = data['guideId'] as String?;
        final guideName = data['guideName'] as String?;

        DateTime parseDate(dynamic val) {
          if (val is Timestamp) return val.toDate();
          if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
          return DateTime.now();
        }

        final start = parseDate(data['startDate']);
        final now = DateTime.now();
        final startDay = DateTime(start.year, start.month, start.day);
        final targetDay = DateTime(now.year, now.month, now.day);
        final curDay = (targetDay.difference(startDay).inDays + 1).clamp(1, totalDays);

        return TourSession(
          sessionId: sessionId,
          tourName: name,
          totalDays: totalDays,
          currentDay: curDay,
          guideId: guideId,
          guideName: guideName,
        );
      }

      // Fallback to legacy /tour_sessions/{sessionId}
      try {
        final legDoc = await _db.collection('tour_sessions').doc(sessionId).get();
        if (legDoc.exists && legDoc.data() != null) {
          return TourSession.fromFirestore(legDoc.id, legDoc.data()!);
        }
      } catch (_) {}

      return TourSession(
        sessionId: sessionId,
        tourName: 'Unnamed Tour',
        totalDays: 1,
        currentDay: 1,
      );
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
        'status': 'active',
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

  // ── End Tour ────────────────────────────────────────────────

  /// Ends a tour session by:
  /// 1. Setting status to 'ended' on the session document
  /// 2. Deleting all temporary sub-collections: codes, chat, locations, sos
  /// 3. Deleting attendance records for each itinerary stop
  ///
  /// The session document and itinerary sub-collection are preserved
  /// for historical records. The guide's user account is never affected.
  static Future<void> endTour(String sessionId) async {
    final sessionDoc = _db.collection('tour_sessions').doc(sessionId);

    // 1. Mark session as ended
    await sessionDoc.update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });

    // 2. Delete temporary sub-collections
    await _deleteCollection(sessionDoc.collection('codes'));
    await _deleteCollection(sessionDoc.collection('chat'));
    await _deleteCollection(sessionDoc.collection('locations'));
    await _deleteCollection(sessionDoc.collection('sos'));

    // 3. Delete attendance records (nested under each stop)
    final attendanceDocs =
        await sessionDoc.collection('attendance').get();
    for (final stopDoc in attendanceDocs.docs) {
      await _deleteCollection(
        sessionDoc
            .collection('attendance')
            .doc(stopDoc.id)
            .collection('records'),
      );
      // Delete the attendance stop doc itself
      await stopDoc.reference.delete();
    }
  }

  // ── Reset / Start New Tour ──────────────────────────────────

  /// Fully resets an ended tour session so the guide can start fresh.
  /// Deletes the old session document (and its itinerary sub-collection),
  /// then creates a brand-new active session.
  static Future<void> resetSession(String sessionId) async {
    final sessionDoc = _db.collection('tour_sessions').doc(sessionId);

    // Delete itinerary stops
    await _deleteCollection(sessionDoc.collection('stops'));

    // Delete the old session document
    await sessionDoc.delete();

    // Create a fresh active session
    await sessionDoc.set({
      'tourName': 'Unnamed Tour',
      'totalDays': 3,
      'currentDay': 1,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Helper: deletes all documents in a Firestore collection.
  /// Uses batched writes (max 500 per batch) for efficiency.
  static Future<void> _deleteCollection(
      CollectionReference collection) async {
    const batchSize = 400;
    QuerySnapshot snapshot;

    do {
      snapshot = await collection.limit(batchSize).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } while (snapshot.docs.length == batchSize);
  }
}
