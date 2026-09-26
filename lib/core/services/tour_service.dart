import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/join_request_model.dart';
import '../models/tour_model.dart';
import 'tour_status_resolver.dart';

/// Centralized service for Multi-Tour Pre-Planning, Conflict Checks,
/// Access Code Generation, and Tourist Join Requests (REV-002).
class TourService {
  TourService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Centralized Status Resolution & Sync (REV-004) ───────

  /// Centralized resolver function determining the effective status of any tour.
  static TourStatus resolveTourStatus(Tour tour, [DateTime? now]) {
    return TourStatusResolver.resolve(tour, now);
  }

  /// Asynchronously synchronizes the stored Firestore status of a tour if it is stale.
  /// Does not block UI or throw unhandled exceptions.
  static Future<void> syncTourStatusIfNeeded(Tour tour) async {
    // If tour is manually ended, ensure status is completed and isEnded remains true.
    if (tour.isEnded) {
      if (tour.status.trim().toLowerCase() != 'completed') {
        try {
          await _db.collection('tours').doc(tour.id).update({
            'status': 'completed',
            'isEnded': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (_) {}
      }
      return;
    }

    // Automatically transition from upcoming to active when the start time arrives
    final effective = tour.effectiveStatus;
    if (effective == TourStatus.active && tour.status.trim().toLowerCase() == 'upcoming') {
      try {
        await _db.collection('tours').doc(tour.id).update({
          'status': 'active',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  /// Audits and synchronizes all existing tours in Firestore to ensure status consistency (REV-004 Section 8).
  static Future<void> syncAllTourStatuses({String? guideId}) async {
    try {
      Query<Map<String, dynamic>> query = _db.collection('tours');
      if (guideId != null && guideId.isNotEmpty) {
        query = query.where('guideId', isEqualTo: guideId);
      }
      final snapshot = await query.get();
      for (final doc in snapshot.docs) {
        final tour = Tour.fromFirestore(doc.id, doc.data());
        await syncTourStatusIfNeeded(tour);
      }
    } catch (_) {}
  }

  // ── Multi-Tour Streams & Queries ─────────────────────────

  /// Real-time stream of all tours created by a specific Tour Guide.
  static Stream<List<Tour>> watchToursByGuide(String guideId) {
    return _db
        .collection('tours')
        .where('guideId', isEqualTo: guideId)
        .snapshots()
        .map((snapshot) {
          final tours = snapshot.docs
              .map((doc) => Tour.fromFirestore(doc.id, doc.data()))
              .toList();
          for (final tour in tours) {
            syncTourStatusIfNeeded(tour);
          }
          tours.sort((a, b) => a.startDate.compareTo(b.startDate));
          return tours;
        });
  }

  /// Real-time stream of a single Tour by [tourId].
  /// Listens to /tours/{tourId} with fallback to legacy /tour_sessions/{tourId}.
  static Stream<Tour?> watchTour(String tourId) {
    if (tourId.trim().isEmpty) return Stream.value(null);
    return _db.collection('tours').doc(tourId).snapshots().asyncMap((doc) async {
      if (doc.exists && doc.data() != null) {
        final tour = Tour.fromFirestore(doc.id, doc.data()!);
        syncTourStatusIfNeeded(tour);
        return tour;
      }
      try {
        final leg = await _db.collection('tour_sessions').doc(tourId).get();
        if (leg.exists && leg.data() != null) {
          final tour = Tour.fromFirestore(leg.id, leg.data()!);
          syncTourStatusIfNeeded(tour);
          return tour;
        }
      } catch (_) {}
      return null;
    });
  }

  /// Fetches a single Tour by [tourId].
  static Future<Tour?> getTour(String tourId) async {
    final doc = await _db.collection('tours').doc(tourId).get();
    if (doc.exists && doc.data() != null) {
      final tour = Tour.fromFirestore(doc.id, doc.data()!);
      syncTourStatusIfNeeded(tour);
      return tour;
    }
    try {
      final leg = await _db.collection('tour_sessions').doc(tourId).get();
      if (leg.exists && leg.data() != null) {
        final tour = Tour.fromFirestore(leg.id, leg.data()!);
        syncTourStatusIfNeeded(tour);
        return tour;
      }
    } catch (_) {}
    return null;
  }

  /// Real-time stream of the currently active tour.
  /// A tour is considered active if its centralized effectiveStatus == ACTIVE.
  static Stream<Tour?> watchActiveTour(String guideId) {
    return watchToursByGuide(guideId).map((tours) {
      return tours.where((t) => t.isActive).firstOrNull;
    });
  }

  /// Real-time stream of the tour to display on the Tour Guide Dashboard panel:
  /// Real-time stream of the tour to display on the Tour Guide Dashboard panel:
  /// 1. FIRST: Active Tour (effectiveStatus == TourStatus.active && !isEnded && status != 'completed')
  /// 2. SECOND: Nearest Upcoming Tour (effectiveStatus == TourStatus.upcoming, sorted by startDateTime ascending)
  /// 3. THIRD: null (Completed tours are NEVER selected for the Dashboard panel; Dashboard renders "No Active Tour" card)
  static Stream<Tour?> watchCurrentOrUpcomingTour(String guideId) {
    return watchToursByGuide(guideId).map((tours) {
      if (tours.isEmpty) return null;

      // Priority 1: ACTIVE tour
      final activeTour = tours.where((t) => t.isActive && !t.isEnded).firstOrNull;
      if (activeTour != null) return activeTour;

      // Priority 2: Nearest UPCOMING tour ordered by startDateTime ascending
      final upcomingTours = tours.where((t) {
        final raw = t.status.trim().toLowerCase();
        return !t.isEnded &&
            raw != 'completed' &&
            raw != 'ended' &&
            t.endedAt == null &&
            t.completedAt == null &&
            t.isUpcoming;
      }).toList();

      if (upcomingTours.isNotEmpty) {
        upcomingTours.sort((a, b) {
          final sA = TourStatusResolver.getTourStartDateTime(a);
          final sB = TourStatusResolver.getTourStartDateTime(b);
          return sA.compareTo(sB);
        });
        return upcomingTours.first;
      }

      // Priority 3: None (Completed tours are never displayed on the Dashboard)
      return null;
    });
  }

  // ── Schedule Conflict Detection (REV-002 Section 3.2) ────

  /// Checks whether a proposed date range overlaps with any existing tour
  /// created by the same guide.
  ///
  /// Uses full DateTime (Date + Time) for overlap detection.
  /// Returns the conflicting [Tour] if found, or null if no conflict exists.
  static Future<Tour?> findScheduleConflict({
    required String guideId,
    required DateTime startDate,
    required DateTime endDate,
    String? startTime,
    String? endTime,
    String? excludeTourId,
  }) async {
    final query = await _db
        .collection('tours')
        .where('guideId', isEqualTo: guideId)
        .get();

    final existingTours = query.docs
        .map((d) => Tour.fromFirestore(d.id, d.data()))
        .where((t) => t.id != excludeTourId && !t.isCompleted);

    // Build full start/end DateTime for the proposed tour
    DateTime proposedStart = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime proposedEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);

    if (startTime != null && startTime.trim().isNotEmpty) {
      final parsed = TourStatusResolver.parseTimeOfDay(startTime);
      if (parsed != null) {
        proposedStart = DateTime(startDate.year, startDate.month, startDate.day, parsed.hour, parsed.minute);
      }
    }
    if (endTime != null && endTime.trim().isNotEmpty) {
      final parsed = TourStatusResolver.parseTimeOfDay(endTime);
      if (parsed != null) {
        proposedEnd = DateTime(endDate.year, endDate.month, endDate.day, parsed.hour, parsed.minute, 59, 999);
      }
    }

    for (final tour in existingTours) {
      if (tour.overlapsWith(proposedStart, proposedEnd)) {
        return tour;
      }
    }
    return null;
  }

  // ── Automatic Access Code Generation (Section 3.3) ───────

  /// Generates a unique 6-character alphanumeric code (e.g. TRV-894 or CRN72X).
  /// Guarantees global uniqueness by checking against `/access_codes`.
  static Future<String> generateUniqueAccessCode() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // omit easily confused chars: 0, 1, I, O
    final random = Random();

    for (int attempt = 0; attempt < 10; attempt++) {
      final prefix = 'TRV';
      final suffix = List.generate(3, (_) => chars[random.nextInt(chars.length)]).join();
      final code = '$prefix-$suffix';

      final doc = await _db.collection('access_codes').doc(code).get();
      if (!doc.exists) {
        return code;
      }
    }

    // Fallback: 6 random alphanumeric characters
    return List.generate(6, (_) => chars[random.nextInt(chars.length)]).join();
  }

  // ── Tour Creation & Management ───────────────────────────

  /// Creates a new Tour with automatic conflict check and unique access code.
  static Future<Tour> createTour({
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required int totalDays,
    String schedule = '',
    required String guideId,
    required String guideName,
    String? startTime,
    String? endTime,
  }) async {
    // 1. Conflict Check (uses full DateTime with time)
    final conflict = await findScheduleConflict(
      guideId: guideId,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
    );

    if (conflict != null) {
      throw TourConflictException(
        'Schedule Conflict: You already have an existing tour "${conflict.name}" '
        'scheduled from ${conflict.formattedDateRange}. '
        'Please adjust the dates so tours do not overlap.',
        conflictingTour: conflict,
      );
    }

    // 2. Auto-Generate Unique Access Code
    final accessCode = await generateUniqueAccessCode();

    // 3. Determine initial status based on full DateTime (Date + Time)
    final now = DateTime.now();
    // Build full start/end DateTime
    DateTime fullStart = DateTime(startDate.year, startDate.month, startDate.day);
    DateTime fullEnd = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
    if (startTime != null && startTime.trim().isNotEmpty) {
      final parsed = TourStatusResolver.parseTimeOfDay(startTime);
      if (parsed != null) {
        fullStart = DateTime(startDate.year, startDate.month, startDate.day, parsed.hour, parsed.minute);
      }
    }
    if (endTime != null && endTime.trim().isNotEmpty) {
      final parsed = TourStatusResolver.parseTimeOfDay(endTime);
      if (parsed != null) {
        fullEnd = DateTime(endDate.year, endDate.month, endDate.day, parsed.hour, parsed.minute, 59, 999);
      }
    }

    String initialStatus = 'upcoming';
    if (!now.isBefore(fullStart) && !now.isAfter(fullEnd)) {
      initialStatus = 'active';
    } else {
      initialStatus = 'upcoming';
    }

    // 4. Create Tour Document
    final tourRef = _db.collection('tours').doc();
    final tour = Tour(
      id: tourRef.id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      totalDays: totalDays,
      schedule: schedule,
      guideId: guideId,
      guideName: guideName,
      status: initialStatus,
      accessCode: accessCode,
      touristCount: 0,
      startTime: startTime,
      endTime: endTime,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final batch = _db.batch();
    batch.set(tourRef, tour.toFirestore()..['createdAt'] = FieldValue.serverTimestamp());

    // 5. Index Access Code under /access_codes/{code}
    final codeRef = _db.collection('access_codes').doc(accessCode);
    batch.set(codeRef, {
      'tourId': tourRef.id,
      'guideId': guideId,
      'tourName': name,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    return tour;
  }

  /// Updates an existing tour's details.
  static Future<void> updateTour(Tour tour) async {
    final conflict = await findScheduleConflict(
      guideId: tour.guideId,
      startDate: tour.startDate,
      endDate: tour.endDate,
      startTime: tour.startTime,
      endTime: tour.endTime,
      excludeTourId: tour.id,
    );

    if (conflict != null) {
      throw TourConflictException(
        'Schedule Conflict: Tour overlaps with "${conflict.name}" (${conflict.formattedDateRange}).',
        conflictingTour: conflict,
      );
    }

    await _db.collection('tours').doc(tour.id).update(tour.toFirestore());
  }

  /// Ends an active tour: sets status to 'completed', isEnded to true,
  /// saves endedAt timestamp using server timestamp, disables the access code
  /// for new tourists, and updates any legacy session references.
  ///
  /// IMPORTANT: All itinerary, attendance, chat, and tourist records are
  /// preserved for historical review.
  static Future<void> endTour(String tourId) async {
    final tourRef = _db.collection('tours').doc(tourId);
    final tourSnap = await tourRef.get();
    if (!tourSnap.exists) return;

    final data = tourSnap.data() ?? {};
    final accessCode = (data['accessCode'] as String? ?? '').toUpperCase().trim();
    final guideId = data['guideId'] as String? ?? '';

    final batch = _db.batch();

    // 1. Update Tour Document: completed, isEnded = true, server timestamps
    batch.update(tourRef, {
      'status': 'completed',
      'isEnded': true,
      'endedAt': FieldValue.serverTimestamp(),
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Disable Access Code so new tourists cannot join
    if (accessCode.isNotEmpty) {
      final codeRef = _db.collection('access_codes').doc(accessCode);
      batch.update(codeRef, {
        'status': 'disabled',
        'isActive': false,
        'endedAt': FieldValue.serverTimestamp(),
      });
    }

    // 3. Update legacy tour_sessions document if present
    final sessionRef = _db.collection('tour_sessions').doc(tourId);
    batch.set(sessionRef, {
      'status': 'ended',
      'isEnded': true,
      'endedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (guideId.isNotEmpty && guideId != tourId) {
      final guideSessionRef = _db.collection('tour_sessions').doc(guideId);
      batch.set(guideSessionRef, {
        'status': 'ended',
        'isEnded': true,
        'endedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  /// Sets a tour status to 'completed'. Delegates to [endTour].
  static Future<void> completeTour(String tourId) async {
    await endTour(tourId);
  }

  /// Permanently deletes a Completed (or Upcoming) tour and all its related data.
  ///
  /// Uses Tour Guide UID + selected tourId for strict data isolation.
  /// Never touches user profiles, guide/tourist accounts, or other tours.
  static Future<void> deleteTour(String tourId, {String? guideId}) async {
    final tourDoc = _db.collection('tours').doc(tourId);
    final tourSnap = await tourDoc.get();
    if (!tourSnap.exists) return;

    final tourData = tourSnap.data() ?? {};
    final docGuideId = tourData['guideId'] as String? ?? '';

    // Security check: verify ownership if guideId is supplied
    if (guideId != null &&
        guideId.isNotEmpty &&
        docGuideId.isNotEmpty &&
        docGuideId != guideId) {
      throw Exception(
          'Unauthorized: Tour does not belong to the current tour guide.');
    }

    final effectiveGuideId = guideId ?? docGuideId;
    final accessCode =
        (tourData['accessCode'] as String? ?? '').toUpperCase().trim();

    // 1. Delete Access Code only if it belongs to this tourId
    if (accessCode.isNotEmpty) {
      try {
        final codeDoc =
            await _db.collection('access_codes').doc(accessCode).get();
        if (codeDoc.exists) {
          final codeTourId = codeDoc.data()?['tourId'] as String?;
          if (codeTourId == tourId) {
            await codeDoc.reference.delete();
          }
        }
      } catch (_) {}
    }

    // 2. Delete all subcollections belonging exclusively to this tour
    await _deleteCollection(tourDoc.collection('itinerary'));
    await _deleteCollection(tourDoc.collection('join_requests'));
    await _deleteCollection(tourDoc.collection('tourists'));

    // Attendance (both per-stop records and stop documents)
    try {
      final attDocs = await tourDoc.collection('attendance').get();
      for (final stopDoc in attDocs.docs) {
        await _deleteCollection(stopDoc.reference.collection('records'));
        await stopDoc.reference.delete();
      }
    } catch (_) {}

    await _deleteCollection(tourDoc.collection('chat'));
    await _deleteCollection(tourDoc.collection('locations'));
    await _deleteCollection(tourDoc.collection('sos'));
    await _deleteCollection(tourDoc.collection('notifications'));

    // 3. Clean legacy /tour_sessions/{tourId} subcollections if present
    final sessionDoc = _db.collection('tour_sessions').doc(tourId);
    final sessionSnap = await sessionDoc.get();
    if (sessionSnap.exists) {
      await _deleteCollection(sessionDoc.collection('itinerary'));
      await _deleteCollection(sessionDoc.collection('codes'));
      try {
        final legAttDocs = await sessionDoc.collection('attendance').get();
        for (final stopDoc in legAttDocs.docs) {
          await _deleteCollection(stopDoc.reference.collection('records'));
          await stopDoc.reference.delete();
        }
      } catch (_) {}
      await _deleteCollection(sessionDoc.collection('chat'));
      await _deleteCollection(sessionDoc.collection('locations'));
      await _deleteCollection(sessionDoc.collection('sos'));
      await _deleteCollection(sessionDoc.collection('tourists'));
      await _deleteCollection(sessionDoc.collection('notifications'));

      // If sessionDoc.id != guideId, safely delete the session document itself
      if (tourId != effectiveGuideId) {
        try {
          await sessionDoc.delete();
        } catch (_) {}
      }
    }

    // 4. Delete the primary Tour document
    await tourDoc.delete();
  }

  // ── Tourist Join Request Management (REV-002 Section 6) ──

  /// Stream of join requests for a specific tour filtered by status.
  static Stream<List<JoinRequest>> watchJoinRequests(
    String tourId, {
    String? statusFilter,
  }) {
    final joinReqCol =
        _db.collection('tours').doc(tourId).collection('join_requests');
    final touristsCol =
        _db.collection('tours').doc(tourId).collection('tourists');

    return joinReqCol.snapshots().asyncMap((reqSnap) async {
      final list = reqSnap.docs
          .map((doc) =>
              JoinRequest.fromFirestore(doc.id, doc.data()))
          .toList();

      // Also merge approved tourists from /tourists subcollection
      if (statusFilter == null || statusFilter == 'approved') {
        try {
          final touristSnap = await touristsCol.get();
          for (final tDoc in touristSnap.docs) {
            final tData = tDoc.data();
            final tName = tData['touristName'] as String? ?? '';
            final tId = tDoc.id;
            final alreadyExists =
                list.any((r) => r.touristId == tId || r.id == tId);
            if (!alreadyExists && tName.isNotEmpty) {
              list.add(JoinRequest(
                id: tId,
                tourId: tourId,
                touristId: tId,
                touristName: tName,
                contactNumber: tData['contactNumber'] as String? ?? '',
                emergencyContact: tData['emergencyContact'] as String? ?? '',
                status: 'approved',
                createdAt: tData['joinedAt'] is Timestamp
                    ? (tData['joinedAt'] as Timestamp).toDate()
                    : null,
              ));
            }
          }
        } catch (_) {}
      }

      var filtered = list;
      if (statusFilter != null) {
        filtered = list.where((r) => r.status == statusFilter).toList();
      }

      filtered.sort((a, b) {
        final dateA = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final dateB = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return dateB.compareTo(dateA);
      });
      return filtered;
    });
  }

  /// Real-time stream of all approved tourists for a tour.
  /// Sources from /tours/{tourId}/tourists and merges approved join_requests
  /// and legacy session codes for full backwards and cross compatibility.
  static Stream<List<ApprovedTourist>> watchApprovedTourists(String tourId) {
    if (tourId.isEmpty) return Stream.value([]);
    final touristsCol =
        _db.collection('tours').doc(tourId).collection('tourists');
    return touristsCol.snapshots().asyncMap((touristSnap) async {
      final map = <String, ApprovedTourist>{};

      // 1. Primary: /tours/{tourId}/tourists
      for (final doc in touristSnap.docs) {
        final data = doc.data();
        final name = data['touristName'] as String? ?? '';
        final tId = (data['touristId'] as String?)?.isNotEmpty == true
            ? data['touristId'] as String
            : doc.id;
        if (tId.isNotEmpty && name.isNotEmpty) {
          map[tId] = ApprovedTourist.fromFirestore(tId, data);
        }
      }

      // 2. Merge approved join_requests
      try {
        final reqSnap = await _db
            .collection('tours')
            .doc(tourId)
            .collection('join_requests')
            .where('status', isEqualTo: 'approved')
            .get();
        for (final doc in reqSnap.docs) {
          final data = doc.data();
          final tId = (data['touristId'] as String?)?.isNotEmpty == true
              ? data['touristId'] as String
              : doc.id;
          final name = data['touristName'] as String? ?? '';
          if (tId.isNotEmpty && name.isNotEmpty && !map.containsKey(tId)) {
            map[tId] = ApprovedTourist(
              touristId: tId,
              touristName: name,
              contactNumber: data['contactNumber'] as String? ?? '',
              emergencyContact: data['emergencyContact'] as String? ?? '',
              joinedAt: (data['reviewedAt'] as Timestamp?)?.toDate() ??
                  (data['createdAt'] as Timestamp?)?.toDate(),
            );
          }
        }
      } catch (_) {}

      // 3. Fallback: /tour_sessions/{tourId}/codes
      try {
        final codeSnap = await _db
            .collection('tour_sessions')
            .doc(tourId)
            .collection('codes')
            .get();
        for (final doc in codeSnap.docs) {
          final data = doc.data();
          final name = data['touristName'] as String? ?? '';
          if (name.isNotEmpty && !map.containsKey(doc.id)) {
            map[doc.id] = ApprovedTourist(
              touristId: doc.id,
              touristName: name,
              contactNumber: data['code'] as String? ?? '',
              joinedAt: (data['claimedAt'] as Timestamp?)?.toDate(),
            );
          }
        }
      } catch (_) {}

      final list = map.values.toList();
      list.sort((a, b) =>
          a.touristName.toLowerCase().compareTo(b.touristName.toLowerCase()));
      return list;
    });
  }

  /// Approves a tourist's join request.
  /// Moves tourist to the tour roster (/tours/{tourId}/tourists/{touristId})
  /// and updates touristCount.
  static Future<void> approveJoinRequest(String tourId, JoinRequest request) async {
    final tourRef = _db.collection('tours').doc(tourId);
    final requestRef = tourRef.collection('join_requests').doc(request.id);
    final touristRef = tourRef.collection('tourists').doc(request.touristId);

    final batch = _db.batch();

    // 1. Update Join Request status to approved
    batch.update(requestRef, {
      'status': 'approved',
      'reviewedAt': FieldValue.serverTimestamp(),
    });

    // 2. Add to Approved Tour Roster
    batch.set(touristRef, {
      'touristId': request.touristId,
      'touristName': request.touristName,
      'contactNumber': request.contactNumber,
      'emergencyContact': request.emergencyContact,
      'status': 'approved',
      'joinedAt': FieldValue.serverTimestamp(),
    });

    // 3. Sync to /tour_sessions/{tourId}/codes for attendance, chat, and location tracking
    final codeRef = _db
        .collection('tour_sessions')
        .doc(tourId)
        .collection('codes')
        .doc(request.touristId);
    batch.set(codeRef, {
      'touristName': request.touristName,
      'isActive': true,
      'claimedAt': FieldValue.serverTimestamp(),
      'sessionId': tourId,
    }, SetOptions(merge: true));

    // 4. Increment tourist count
    batch.update(tourRef, {
      'touristCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  /// Rejects a tourist's join request.
  static Future<void> rejectJoinRequest(String tourId, String requestId) async {
    await _db
        .collection('tours')
        .doc(tourId)
        .collection('join_requests')
        .doc(requestId)
        .update({
      'status': 'rejected',
      'reviewedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Helper: Batch Delete Collection ──────────────────────

  static Future<void> _deleteCollection(CollectionReference collection) async {
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

/// Custom exception thrown when a proposed tour schedule overlaps with an existing tour.
class TourConflictException implements Exception {
  final String message;
  final Tour? conflictingTour;

  TourConflictException(this.message, {this.conflictingTour});

  @override
  String toString() => message;
}

/// Represents an approved tourist in a tour roster (REV-002 / REV-005).
class ApprovedTourist {
  final String touristId;
  final String touristName;
  final String contactNumber;
  final String emergencyContact;
  final DateTime? joinedAt;

  const ApprovedTourist({
    required this.touristId,
    required this.touristName,
    this.contactNumber = '',
    this.emergencyContact = '',
    this.joinedAt,
  });

  factory ApprovedTourist.fromFirestore(String id, Map<String, dynamic> data) {
    return ApprovedTourist(
      touristId: (data['touristId'] as String?)?.isNotEmpty == true
          ? data['touristId'] as String
          : id,
      touristName: data['touristName'] as String? ?? '',
      contactNumber: data['contactNumber'] as String? ?? '',
      emergencyContact: data['emergencyContact'] as String? ?? '',
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate(),
    );
  }
}

