import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a live SOS alert record from Firestore (Step 9 / US-18).
class SosAlert {
  final String id;
  final String senderId;
  final String senderName;
  final String status;
  final double lat;
  final double lng;
  final bool isResolved;
  final DateTime timestamp;

  const SosAlert({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.status,
    required this.lat,
    required this.lng,
    required this.isResolved,
    required this.timestamp,
  });

  /// Human-readable location string.
  String get locationLabel => 'Lat: ${lat.toStringAsFixed(5)}, Lng: ${lng.toStringAsFixed(5)}';

  factory SosAlert.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    return SosAlert(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Traveler',
      status: data['status'] as String? ?? 'SOS Alert Sent',
      lat: (data['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (data['lng'] as num?)?.toDouble() ?? 0.0,
      isResolved: data['isResolved'] as bool? ?? false,
      timestamp: ts,
    );
  }
}

/// Service for SOS / Emergency Alerts operations (REV-002).
class SosService {
  SosService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _sosCol(String tourId) {
    return _db.collection('tours').doc(tourId).collection('sos');
  }

  static CollectionReference<Map<String, dynamic>> _legacySosCol(String tourId) {
    return _db.collection('tour_sessions').doc(tourId).collection('sos');
  }

  // ── Write ───────────────────────────────────────────────────

  /// Creates an SOS alert with real GPS coordinates in Firestore.
  static Future<void> sendAlert({
    required String sessionId,
    required String senderId,
    required String senderName,
    required double lat,
    required double lng,
    String status = 'SOS Alert Sent',
  }) async {
    final alertData = {
      'senderId': senderId,
      'senderName': senderName,
      'lat': lat,
      'lng': lng,
      'status': status,
      'isResolved': false,
      'timestamp': FieldValue.serverTimestamp(),
    };

    final docRef = await _sosCol(sessionId).add(alertData);
    try {
      await _legacySosCol(sessionId).doc(docRef.id).set(alertData);
    } catch (_) {}
  }

  /// Marks an existing SOS alert as resolved.
  static Future<void> resolveAlert({
    required String sessionId,
    required String alertId,
  }) async {
    final updateData = {
      'isResolved': true,
      'status': 'Resolved',
      'resolvedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _sosCol(sessionId).doc(alertId).update(updateData);
    } catch (_) {}
    try {
      await _legacySosCol(sessionId).doc(alertId).update(updateData);
    } catch (_) {}
  }

  // ── Read ────────────────────────────────────────────────────

  /// Real-time stream of ALL alerts (active + resolved) ordered latest first.
  static Stream<List<SosAlert>> watchAlerts(String tourId) {
    return _sosCol(tourId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
        return snap.docs
            .map((doc) => SosAlert.fromFirestore(doc.id, doc.data()))
            .toList();
      }
      try {
        final legSnap = await _legacySosCol(tourId)
            .orderBy('timestamp', descending: true)
            .get();
        if (legSnap.docs.isNotEmpty) {
          return legSnap.docs
              .map((doc) => SosAlert.fromFirestore(doc.id, doc.data()))
              .toList();
        }
      } catch (_) {}
      return [];
    });
  }

  /// Real-time stream of only ACTIVE (unresolved) alerts.
  static Stream<List<SosAlert>> watchActiveAlerts(String sessionId) {
    return watchAlerts(sessionId).map((alerts) =>
        alerts.where((a) => !a.isResolved).toList());
  }
}
