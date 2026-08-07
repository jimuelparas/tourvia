import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/itinerary/models/itinerary_item.dart';
import '../services/routing_service.dart';

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
      'latitude': item.latitude,
      'longitude': item.longitude,
      'status': item.status.name,
      'distanceToNext': item.distanceToNext,
      'durationToNext': item.durationToNext,
      'encodedPolyline': item.encodedPolyline,
      'routeEndLatitude': item.routeEndLatitude,
      'routeEndLongitude': item.routeEndLongitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Run route recalculation async (fire and forget)
    recalculateRoutes(sessionId);

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
      'latitude': item.latitude,
      'longitude': item.longitude,
      'status': item.status.name,
      'distanceToNext': item.distanceToNext,
      'durationToNext': item.durationToNext,
      'encodedPolyline': item.encodedPolyline,
      'routeEndLatitude': item.routeEndLatitude,
      'routeEndLongitude': item.routeEndLongitude,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    recalculateRoutes(sessionId);
  }

  /// Deletes a stop document from Firestore.
  static Future<void> deleteStop(String sessionId, String stopId) async {
    await _col(sessionId).doc(stopId).delete();
    recalculateRoutes(sessionId);
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
    recalculateRoutes(sessionId);
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

    final statusStr = data['status'] as String? ?? 'upcoming';
    final status = ItineraryStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => ItineraryStatus.upcoming,
    );

    return ItineraryItem(
      id: doc.id,
      destinationName: data['destinationName'] as String? ?? '',
      date: date,
      startTime: data['startTime'] as String? ?? '',
      endTime: data['endTime'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      status: status,
      distanceToNext: (data['distanceToNext'] as num?)?.toDouble(),
      durationToNext: (data['durationToNext'] as num?)?.toInt(),
      encodedPolyline: data['encodedPolyline'] as String?,
      routeEndLatitude: (data['routeEndLatitude'] as num?)?.toDouble(),
      routeEndLongitude: (data['routeEndLongitude'] as num?)?.toDouble(),
    );
  }

  // ── Route Recalculation ──────────────────────────────────

  /// Recalculates routes for adjacent stops if they have moved or don't have a route.
  static Future<void> recalculateRoutes(String sessionId) async {
    final snap = await _col(sessionId).orderBy('order').get();
    if (snap.docs.isEmpty) return;

    final stops = snap.docs.map(_fromDoc).toList();
    final batch = _db.batch();
    bool hasUpdates = false;

    for (int i = 0; i < stops.length; i++) {
      final current = stops[i];
      if (i < stops.length - 1) {
        final next = stops[i + 1];
        // Check if we need to fetch new route
        // We recalculate if: routeEndLatitude != next.latitude OR routeEndLongitude != next.longitude OR encodedPolyline is null
        // And we only calculate if both have valid coordinates
        if (current.latitude != 0.0 && next.latitude != 0.0) {
          if (current.routeEndLatitude != next.latitude ||
              current.routeEndLongitude != next.longitude ||
              current.encodedPolyline == null) {
            
            final route = await RoutingService.getRoute(
              startLat: current.latitude,
              startLng: current.longitude,
              endLat: next.latitude,
              endLng: next.longitude,
            );

            if (route != null) {
              batch.update(_col(sessionId).doc(current.id), {
                'distanceToNext': route['distance'],
                'durationToNext': route['duration'],
                'encodedPolyline': route['polyline'],
                'routeEndLatitude': next.latitude,
                'routeEndLongitude': next.longitude,
              });
              hasUpdates = true;
            }
          }
        }
      } else {
        // Last stop should have no route to next
        if (current.encodedPolyline != null || current.distanceToNext != null) {
          batch.update(_col(sessionId).doc(current.id), {
            'distanceToNext': FieldValue.delete(),
            'durationToNext': FieldValue.delete(),
            'encodedPolyline': FieldValue.delete(),
            'routeEndLatitude': FieldValue.delete(),
            'routeEndLongitude': FieldValue.delete(),
          });
          hasUpdates = true;
        }
      }
    }

    if (hasUpdates) {
      await batch.commit();
    }
  }
}
