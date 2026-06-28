import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/itinerary/models/itinerary_item.dart';

/// Service for all itinerary CRUD operations (Step 5).
///
/// Firestore path: /tour_sessions/{sessionId}/itinerary/{stopId}
///
/// Tourists get a real-time stream; the guide does full CRUD.
class ItineraryService {
  ItineraryService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Firestore path helper ────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _col(String sessionId) =>
      _db.collection('tour_sessions').doc(sessionId).collection('itinerary');

  // ── Guide: CRUD ──────────────────────────────────────────

  /// Adds a new stop to Firestore and returns the generated [stopId].
  static Future<String> addStop(String sessionId, ItineraryItem item) async {
    final existing = await _col(sessionId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();

    final nextOrder =
        existing.docs.isEmpty ? 1 : (existing.docs.first['order'] as int) + 1;

    final ref = await _col(sessionId).add({
      'destinationName': item.destinationName,
      'date': Timestamp.fromDate(item.date),
      'startTime': item.startTime,
      'endTime': item.endTime,
      'notes': item.notes,
      'order': nextOrder,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    return ref.id;
  }

  /// Updates an existing stop's fields in Firestore.
  static Future<void> updateStop(
    String sessionId,
    String stopId,
    ItineraryItem item,
  ) async {
    await _col(sessionId).doc(stopId).update({
      'destinationName': item.destinationName,
      'date': Timestamp.fromDate(item.date),
      'startTime': item.startTime,
      'endTime': item.endTime,
      'notes': item.notes,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a stop document from Firestore.
  static Future<void> deleteStop(String sessionId, String stopId) async {
    await _col(sessionId).doc(stopId).delete();
  }

  /// Re-orders stops by writing a new [order] field to each doc.
  /// [orderedIds] is the list of stop IDs in the new desired order.
  static Future<void> reorderStops(
    String sessionId,
    List<String> orderedIds,
  ) async {
    final batch = _db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      batch.update(
        _col(sessionId).doc(orderedIds[i]),
        {'order': i + 1, 'updatedAt': FieldValue.serverTimestamp()},
      );
    }
    await batch.commit();
  }

  // ── Shared: Real-time stream ─────────────────────────────

  /// Returns a live stream of itinerary items ordered by [order].
  /// Used by both the guide (to reflect reorder) and tourist (read-only).
  static Stream<List<ItineraryItem>> watchItinerary(String sessionId) {
    return _col(sessionId)
        .orderBy('order')
        .snapshots()
        .map((snap) => snap.docs.map(_fromDoc).toList());
  }

  // ── Converter ────────────────────────────────────────────

  static ItineraryItem _fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final ts = data['date'];
    final date = ts is Timestamp ? ts.toDate() : DateTime.now();

    return ItineraryItem(
      id: doc.id,
      destinationName: data['destinationName'] as String? ?? '',
      date: date,
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
    );
  }
}
