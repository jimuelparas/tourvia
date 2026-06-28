import 'package:cloud_firestore/cloud_firestore.dart';

import '../../features/attendance/models/tourist_attendance.dart'
    show AttendanceStatus;

/// Service for all attendance operations (Step 6).
///
/// Firestore paths:
///   Roster  : /tour_sessions/{sessionId}/codes/{codeDocId}
///   Records : /tour_sessions/{sessionId}/attendance/{stopId}/records/{codeDocId}
class AttendanceService {
  AttendanceService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Path helpers ─────────────────────────────────────────

  static CollectionReference<Map<String, dynamic>> _recordsCol(
          String sessionId, String stopId) =>
      _db
          .collection('tour_sessions')
          .doc(sessionId)
          .collection('attendance')
          .doc(stopId)
          .collection('records');

  static CollectionReference<Map<String, dynamic>> _codesCol(
          String sessionId) =>
      _db.collection('tour_sessions').doc(sessionId).collection('codes');

  // ── Roster (who is in the session) ──────────────────────

  /// Returns a real-time stream of all claimed tourists in [sessionId].
  /// A tourist is "in the session" when their code has a non-null [touristName].
  static Stream<List<TouristRecord>> watchRoster(String sessionId) {
    return _codesCol(sessionId)
        .where('touristName', isNotEqualTo: null)
        .snapshots()
        .map((snap) => snap.docs
            .where((d) =>
                (d.data()['touristName'] as String?)?.isNotEmpty == true)
            .map((d) => TouristRecord(
                  codeDocId: d.id,
                  code: d.data()['code'] as String? ?? '',
                  touristName: d.data()['touristName'] as String,
                ))
            .toList());
  }

  // ── Per-stop attendance ──────────────────────────────────

  /// Marks a tourist's attendance for [stopId] in Firestore.
  ///
  /// [touristId] is the code document ID (used as the unique record key).
  static Future<void> markAttendance({
    required String sessionId,
    required String stopId,
    required String touristId,
    required String touristName,
    required String touristCode,
    required AttendanceStatus status,
  }) async {
    await _recordsCol(sessionId, stopId).doc(touristId).set({
      'touristId': touristId,
      'touristName': touristName,
      'touristCode': touristCode,
      'status': _statusToString(status),
      'checkInTime': status != AttendanceStatus.pending
          ? FieldValue.serverTimestamp()
          : null,
      'stopId': stopId,
      'sessionId': sessionId,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Returns a real-time stream of attendance records for [stopId].
  /// Emits a map of {codeDocId → AttendanceStatus}.
  static Stream<Map<String, AttendanceRecord>> watchAttendance(
      String sessionId, String stopId) {
    return _recordsCol(sessionId, stopId).snapshots().map((snap) {
      final map = <String, AttendanceRecord>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        map[doc.id] = AttendanceRecord(
          touristId: doc.id,
          touristName: data['touristName'] as String? ?? '',
          touristCode: data['touristCode'] as String? ?? '',
          status: _statusFromString(data['status'] as String?),
          checkInTime: (data['checkInTime'] as Timestamp?)?.toDate(),
        );
      }
      return map;
    });
  }

  // ── Helpers ──────────────────────────────────────────────

  static String _statusToString(AttendanceStatus s) {
    switch (s) {
      case AttendanceStatus.present:
        return 'present';
      case AttendanceStatus.absent:
        return 'absent';
      case AttendanceStatus.pending:
        return 'pending';
    }
  }

  static AttendanceStatus _statusFromString(String? s) {
    switch (s) {
      case 'present':
        return AttendanceStatus.present;
      case 'absent':
        return AttendanceStatus.absent;
      default:
        return AttendanceStatus.pending;
    }
  }
}

// ── Data models ──────────────────────────────────────────────

/// A tourist who has claimed a code and joined the session.
class TouristRecord {
  final String codeDocId; // used as the unique tourist ID
  final String code;      // e.g. "TRV-A1B2C3"
  final String touristName;

  const TouristRecord({
    required this.codeDocId,
    required this.code,
    required this.touristName,
  });
}

/// A single tourist's attendance record for a stop.
class AttendanceRecord {
  final String touristId;
  final String touristName;
  final String touristCode;
  final AttendanceStatus status;
  final DateTime? checkInTime;

  const AttendanceRecord({
    required this.touristId,
    required this.touristName,
    required this.touristCode,
    required this.status,
    this.checkInTime,
  });
}
