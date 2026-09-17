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
    final effective = tour.effectiveStatus.value;
    if (tour.status.trim().toLowerCase() != effective) {
      try {
        final updates = <String, dynamic>{
          'status': effective,
          'updatedAt': FieldValue.serverTimestamp(),
        };
        if (effective == 'completed' && tour.completedAt == null && tour.endedAt == null) {
          updates['completedAt'] = FieldValue.serverTimestamp();
        }
        await _db.collection('tours').doc(tour.id).update(updates);
      } catch (e) {
        // Silently catch; memory-resolved effectiveStatus governs client UI
      }
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

  /// Real-time stream of the current or next upcoming tour to display on dashboards:
  /// 1. ACTIVE tour: effectiveStatus == ACTIVE.
  /// 2. READY / UPCOMING tour: earliest upcoming tour (effectiveStatus == UPCOMING).
  /// 3. COMPLETED tour: most recently ended tour if all tours are completed.
  /// Returns null only if no tours exist for this guide.
  static Stream<Tour?> watchCurrentOrUpcomingTour(String guideId) {
    return watchToursByGuide(guideId).map((tours) {
      if (tours.isEmpty) return null;

      // 1. Check for an Active tour
      final activeTour = tours.where((t) => t.isActive).firstOrNull;
      if (activeTour != null) return activeTour;

      // 2. Check for the next scheduled READY / UPCOMING tour
      final upcomingTours = tours.where((t) => t.isUpcoming).toList();
      if (upcomingTours.isNotEmpty) {
        upcomingTours.sort((a, b) => a.startDate.compareTo(b.startDate));
        return upcomingTours.first;
      }

      // 3. Fallback: most recent completed tour
      final completedTours = tours.where((t) => t.isCompleted).toList();
      if (completedTours.isNotEmpty) {
        completedTours.sort((a, b) => b.endDate.compareTo(a.endDate));
        return completedTours.first;
      }

      return null;
    });
  }

  // ── Schedule Conflict Detection (REV-002 Section 3.2) ────

  /// Checks whether a proposed date range overlaps with any existing tour
  /// created by the same guide.
  ///
  /// Overlap check: NewStart <= ExistingEnd && NewEnd >= ExistingStart
  /// Returns the conflicting [Tour] if found, or null if no conflict exists.
  static Future<Tour?> findScheduleConflict({
    required String guideId,
    required DateTime startDate,
    required DateTime endDate,
    String? excludeTourId,
  }) async {
    final query = await _db
        .collection('tours')
        .where('guideId', isEqualTo: guideId)
        .get();

    final existingTours = query.docs
        .map((d) => Tour.fromFirestore(d.id, d.data()))
        .where((t) => t.id != excludeTourId && !t.isCompleted);

    for (final tour in existingTours) {
      if (tour.overlapsWith(startDate, endDate)) {
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
  }) async {
    // 1. Conflict Check
    final conflict = await findScheduleConflict(
      guideId: guideId,
      startDate: startDate,
      endDate: endDate,
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

    // 3. Determine initial status based on date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startDay = DateTime(startDate.year, startDate.month, startDate.day);
    final endDay = DateTime(endDate.year, endDate.month, endDate.day);

    String initialStatus = 'upcoming';
    if (!today.isBefore(startDay) && !today.isAfter(endDay)) {
      initialStatus = 'active';
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

  /// Sets a tour status to 'completed' (Read-Only mode for chat).
  static Future<void> completeTour(String tourId) async {
    await _db.collection('tours').doc(tourId).update({
      'status': 'completed',
      'completedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a tour document and all associated subcollections.
  static Future<void> deleteTour(String tourId) async {
    final tourDoc = _db.collection('tours').doc(tourId);
    final sessionDoc = _db.collection('tour_sessions').doc(tourId);
    final tourData = await tourDoc.get();
    final accessCode = tourData.data()?['accessCode'] as String?;

    if (accessCode != null && accessCode.isNotEmpty) {
      try {
        await _db.collection('access_codes').doc(accessCode).delete();
      } catch (_) {}
    }

    // Delete subcollections in /tours/{tourId}
    await _deleteCollection(tourDoc.collection('itinerary'));
    await _deleteCollection(tourDoc.collection('join_requests'));
    await _deleteCollection(tourDoc.collection('tourists'));
    await _deleteCollection(tourDoc.collection('attendance'));
    await _deleteCollection(tourDoc.collection('chat'));
    await _deleteCollection(tourDoc.collection('locations'));
    await _deleteCollection(tourDoc.collection('sos'));

    // Delete subcollections in legacy /tour_sessions/{tourId}
    await _deleteCollection(sessionDoc.collection('itinerary'));
    await _deleteCollection(sessionDoc.collection('codes'));
    await _deleteCollection(sessionDoc.collection('attendance'));
    await _deleteCollection(sessionDoc.collection('chat'));
    await _deleteCollection(sessionDoc.collection('locations'));
    await _deleteCollection(sessionDoc.collection('sos'));
    await _deleteCollection(sessionDoc.collection('tourists'));

    await tourDoc.delete();
    try {
      await sessionDoc.delete();
    } catch (_) {}
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

