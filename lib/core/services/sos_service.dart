import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a dynamic SOS alert record from Firestore (Step 9 / US-18).
class SosAlert {
  final String id;
  final String senderId;
  final String senderName;
  final String status;
  final String location;
  final DateTime timestamp;

  const SosAlert({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.status,
    required this.location,
    required this.timestamp,
  });

  factory SosAlert.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
    return SosAlert(
      id: id,
      senderId: data['senderId'] as String? ?? '',
      senderName: data['senderName'] as String? ?? 'Traveler',
      status: data['status'] as String? ?? 'SOS Alert Sent',
      location: data['location'] as String? ?? 'Unknown Location',
      timestamp: ts,
    );
  }
}

/// Service for SOS / Emergency Alerts operations.
class SosService {
  SosService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _sosCol(String sessionId) {
    return _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('sos');
  }

  /// Triggers a new SOS alert and saves it to Firestore.
  static Future<void> sendAlert({
    required String sessionId,
    required String senderId,
    required String senderName,
    required String location,
    String status = 'SOS Alert Sent',
  }) async {
    await _sosCol(sessionId).add({
      'senderId': senderId,
      'senderName': senderName,
      'location': location,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Returns a real-time stream of all SOS alerts in [sessionId] ordered by timestamp descending.
  static Stream<List<SosAlert>> watchAlerts(String sessionId) {
    return _sosCol(sessionId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => SosAlert.fromFirestore(doc.id, doc.data()))
            .toList());
  }
}
