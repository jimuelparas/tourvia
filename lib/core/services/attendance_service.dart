import 'dart:async';
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
          String tourId, String stopId) =>
      _db
          .collection('tours')
          .doc(tourId)
          .collection('attendance')
          .doc(stopId)
          .collection('records');

  static CollectionReference<Map<String, dynamic>> _legacyRecordsCol(
          String tourId, String stopId) =>
      _db
          .collection('tour_sessions')
          .doc(tourId)
          .collection('attendance')
          .doc(stopId)
          .collection('records');

  static CollectionReference<Map<String, dynamic>> _codesCol(
          String tourId) =>
      _db.collection('tour_sessions').doc(tourId).collection('codes');

  // ── Roster (who is in the session) ──────────────────────

  /// Returns a real-time stream of all claimed/approved tourists in [sessionId] (tourId).
  static Stream<List<TouristRecord>> watchRoster(String sessionId) {
    if (sessionId.isEmpty) return Stream.value([]);

    return _db
        .collection('tours')
        .doc(sessionId)
        .collection('tourists')
        .snapshots()
        .asyncMap((touristSnap) async {
      final map = <String, TouristRecord>{};

      // 1. Load from /tours/{sessionId}/tourists
      for (final d in touristSnap.docs) {
        final data = d.data();
        final name = data['touristName'] as String? ?? '';
        if (name.isNotEmpty) {
          map[d.id] = TouristRecord(
            codeDocId: d.id,
            code: data['contactNumber'] as String? ?? data['code'] as String? ?? 'Approved',
            touristName: name,
          );
        }
      }

      // 2. Also merge from /tours/{sessionId}/join_requests where status == 'approved'
      try {
        final reqSnap = await _db
            .collection('tours')
            .doc(sessionId)
            .collection('join_requests')
            .where('status', isEqualTo: 'approved')
            .get();
        for (final d in reqSnap.docs) {
          final data = d.data();
          final tId = data['touristId'] as String? ?? d.id;
          final name = data['touristName'] as String? ?? '';
          if (name.isNotEmpty && !map.containsKey(tId)) {
            map[tId] = TouristRecord(
              codeDocId: tId,
              code: data['contactNumber'] as String? ?? 'Approved',
              touristName: name,
            );
          }
        }
      } catch (_) {}

      // 3. Fallback / merge legacy /tour_sessions/{sessionId}/codes
      try {
        final codeSnap = await _codesCol(sessionId).get();
        for (final d in codeSnap.docs) {
          final data = d.data();
          final name = data['touristName'] as String? ?? '';
          if (name.isNotEmpty && !map.containsKey(d.id)) {
            map[d.id] = TouristRecord(
              codeDocId: d.id,
              code: data['code'] as String? ?? '',
              touristName: name,
            );
          }
        }
      } catch (_) {}

      final list = map.values.toList();
      list.sort((a, b) => a.touristName.toLowerCase().compareTo(b.touristName.toLowerCase()));
      return list;
    });
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
    final recordData = {
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
    };

    try {
      await _recordsCol(sessionId, stopId).doc(touristId).set(recordData, SetOptions(merge: true));
    } catch (_) {}
    try {
      await _legacyRecordsCol(sessionId, stopId).doc(touristId).set(recordData, SetOptions(merge: true));
    } catch (_) {}
  }

  /// Returns a real-time stream of attendance records for [stopId].
  /// Emits a map of {codeDocId → AttendanceStatus}.
  static Stream<Map<String, AttendanceRecord>> watchAttendance(
      String sessionId, String stopId) {
    return _recordsCol(sessionId, stopId).snapshots().asyncMap((snap) async {
      if (snap.docs.isNotEmpty) {
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
      }
      try {
        final legSnap = await _legacyRecordsCol(sessionId, stopId).get();
        final map = <String, AttendanceRecord>{};
        for (final doc in legSnap.docs) {
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
      } catch (_) {}
      return <String, AttendanceRecord>{};
    });
  }

  /// Returns a real-time stream of the stop attendance summary (presentCount and totalCount)
  /// using the exact same approved roster and attendance records as the Attendance module.
  static Stream<({int presentCount, int totalCount})> watchStopAttendanceSummary(
      String tourId, String stopId) {
    final tId = tourId.trim();
    final sId = stopId.trim();
    if (tId.isEmpty || sId.isEmpty) {
      return Stream.value((presentCount: 0, totalCount: 0));
    }

    late StreamController<({int presentCount, int totalCount})> controller;
    StreamSubscription? rosterSub;
    StreamSubscription? attendanceSub;

    List<TouristRecord> currentRoster = [];
    Map<String, AttendanceRecord> currentRecords = {};

    void emitSummary() {
      if (controller.isClosed) return;
      final total = currentRoster.length;
      final present = currentRoster.where((t) {
        final rec = currentRecords[t.codeDocId];
        return rec?.status == AttendanceStatus.present;
      }).length;
      controller.add((presentCount: present, totalCount: total));
    }

    controller =
        StreamController<({int presentCount, int totalCount})>.broadcast(
      onListen: () {
        rosterSub = watchRoster(tId).listen((roster) {
          currentRoster = roster;
          emitSummary();
        }, onError: (_) {});

        attendanceSub = watchAttendance(tId, sId).listen((records) {
          currentRecords = records;
          emitSummary();
        }, onError: (_) {});
      },
      onCancel: () {
        rosterSub?.cancel();
        attendanceSub?.cancel();
      },
    );

    return controller.stream;
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
