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

/// Service for SOS / Emergency Alerts operations.
class SosService {
  SosService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _sosCol(String sessionId) {
    return _db.collection('tour_sessions').doc(sessionId).collection('sos');
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
    await _sosCol(sessionId).add({
      'senderId': senderId,
      'senderName': senderName,
      'lat': lat,
      'lng': lng,
      'status': status,
      'isResolved': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Marks an existing SOS alert as resolved.
  static Future<void> resolveAlert({
    required String sessionId,
    required String alertId,
  }) async {
    await _sosCol(sessionId).doc(alertId).update({
      'isResolved': true,
      'status': 'Resolved',
    });
  }

  // ── Read ────────────────────────────────────────────────────

  /// Real-time stream of ALL alerts (active + resolved) ordered latest first.
  static Stream<List<SosAlert>> watchAlerts(String sessionId) {
    return _sosCol(sessionId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((doc) => SosAlert.fromFirestore(doc.id, doc.data())).toList());
  }

  /// Real-time stream of only ACTIVE (unresolved) alerts.
  static Stream<List<SosAlert>> watchActiveAlerts(String sessionId) {
    return watchAlerts(sessionId).map((alerts) =>
        alerts.where((a) => !a.isResolved).toList());
  }
}
