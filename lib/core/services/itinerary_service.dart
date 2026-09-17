import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/itinerary/models/itinerary_item.dart';
import '../services/routing_service.dart';

/// Service for all itinerary CRUD operations (REV-002).
///
/// Firestore primary path: /tours/{tourId}/itinerary/{stopId}
/// Fallback/legacy path:   /tour_sessions/{sessionId}/itinerary/{stopId}
///
/// Tourists get a real-time stream; the guide does full CRUD.
class ItineraryService {
  ItineraryService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Firestore path helper ────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _col(String tourId) =>
      _db.collection('tours').doc(tourId).collection('itinerary');

  static CollectionReference<Map<String, dynamic>> _legacyCol(String tourId) =>
      _db.collection('tour_sessions').doc(tourId).collection('itinerary');

  // ── Time & Overlap Helpers (REV-002 Section 7.2) ──────────

  /// Parses a formatted time string (e.g. "09:30 AM") to minutes from midnight.
  static int parseTimeToMinutes(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      final isAm = parts.length > 1 && parts[1].toUpperCase() == 'AM';
      if (isPm && hour != 12) hour += 12;
      if (isAm && hour == 12) hour = 0;
      return hour * 60 + minute;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if a proposed stop overlaps in time with any existing stop on the same date.
  /// Overlap condition: newStart < existingEnd && newEnd > existingStart
  static Future<ItineraryItem?> findTimeOverlap(
    String sessionId,
    DateTime date,
    String startTime,
    String endTime, {
    String? excludeStopId,
  }) async {
    final snap = await _col(sessionId).get();
    final newStart = parseTimeToMinutes(startTime);
    final newEnd = parseTimeToMinutes(endTime);

    for (final doc in snap.docs) {
      if (doc.id == excludeStopId) continue;
      final stop = _fromDoc(doc);
      if (stop.date.year == date.year &&
          stop.date.month == date.month &&
          stop.date.day == date.day) {
        final existingStart = parseTimeToMinutes(stop.startTime);
        final existingEnd = parseTimeToMinutes(stop.endTime);

        if (newStart < existingEnd && newEnd > existingStart) {
          return stop;
        }
      }
    }
    return null;
  }

  /// Fetches all stops for a tour.
  static Future<List<ItineraryItem>> getStops(String tourId) async {
    final snap = await _col(tourId).orderBy('order').get();
    if (snap.docs.isNotEmpty) {
      return snap.docs.map(_fromDoc).toList();
    }
    final legacySnap = await _legacyCol(tourId).orderBy('order').get();
    return legacySnap.docs.map(_fromDoc).toList();
  }

  // ── Guide: CRUD ──────────────────────────────────────────

  /// Adds a new stop to Firestore and returns the generated [stopId].
  static Future<String> addStop(String tourId, ItineraryItem item) async {
    final existing = await _col(tourId)
        .orderBy('order', descending: true)
        .limit(1)
        .get();

    final nextOrder =
        existing.docs.isEmpty ? 1 : (existing.docs.first['order'] as int) + 1;

    final docData = {
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
    };

    final ref = await _col(tourId).add(docData);
    try {
      await _legacyCol(tourId).doc(ref.id).set(docData);
    } catch (_) {}

    // Run route recalculation async (fire and forget)
    recalculateRoutes(tourId);

    return ref.id;
  }

  /// Updates an existing stop's fields in Firestore.
  static Future<void> updateStop(
    String tourId,
    String stopId,
    ItineraryItem item,
  ) async {
    // Completed destinations are historical and read-only
    final docSnap = await _col(tourId).doc(stopId).get();
    if (docSnap.exists) {
      final existingStop = _fromDoc(docSnap);
      if (existingStop.effectiveStatus == ItineraryStatus.completed) {
        throw Exception('Completed itinerary stops are read-only.');
      }
    }

    final updateData = {
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
    };

    await _col(tourId).doc(stopId).update(updateData);
    try {
      await _legacyCol(tourId).doc(stopId).update(updateData);
    } catch (_) {}

    recalculateRoutes(tourId);
  }

  /// Deletes a stop document from Firestore.
  static Future<void> deleteStop(String tourId, String stopId) async {
    // Completed destinations cannot be deleted
    final docSnap = await _col(tourId).doc(stopId).get();
    if (docSnap.exists) {
      final existingStop = _fromDoc(docSnap);
      if (existingStop.effectiveStatus == ItineraryStatus.completed) {
        throw Exception('Completed itinerary stops cannot be deleted.');
      }
    }

    await _col(tourId).doc(stopId).delete();
    try {
      await _legacyCol(tourId).doc(stopId).delete();
    } catch (_) {}
    recalculateRoutes(tourId);
  }

  /// Marks a stop as [ItineraryStatus.completed] in Firestore.
  /// Called when the Tour Guide taps the "Done" button for a destination.
  static Future<void> markStopDone(String tourId, String stopId) async {
    final data = {
      'status': ItineraryStatus.completed.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    await _col(tourId).doc(stopId).update(data);
    try {
      await _legacyCol(tourId).doc(stopId).update(data);
    } catch (_) {}
  }

  /// Re-orders stops by writing a new [order] field to each doc.
  /// [orderedIds] is the list of stop IDs in the new desired order.
  static Future<void> reorderStops(
    String tourId,
    List<String> orderedIds,
  ) async {
    final batch = _db.batch();
    for (int i = 0; i < orderedIds.length; i++) {
      final data = {'order': i + 1, 'updatedAt': FieldValue.serverTimestamp()};
      batch.update(_col(tourId).doc(orderedIds[i]), data);
      batch.update(_legacyCol(tourId).doc(orderedIds[i]), data);
    }
    await batch.commit();
    recalculateRoutes(tourId);
  }

  // ── Shared: Real-time stream ─────────────────────────────

  /// Returns a live stream of itinerary items ordered by [order].
  /// Used by both the guide (to reflect reorder) and tourist (read-only).
  static Stream<List<ItineraryItem>> watchItinerary(String tourId) {
    return _col(tourId)
        .orderBy('order')
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
        return snap.docs.map(_fromDoc).toList();
      }
      // Fallback to legacy path if new path is empty
      try {
        final legSnap = await _legacyCol(tourId).orderBy('order').get();
        if (legSnap.docs.isNotEmpty) {
          return legSnap.docs.map(_fromDoc).toList();
        }
      } catch (_) {}
      return [];
    });
  }

  // ── Converter ────────────────────────────────────────────

  static ItineraryItem _fromDoc(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
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
