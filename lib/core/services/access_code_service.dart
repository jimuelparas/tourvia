import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tourist_session.dart';

/// Service for all access-code operations.
/// Handles tourist login (Step 3) and guide code generation (Step 4).
class AccessCodeService {
  AccessCodeService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Step 3: Tourist Login ───────────────────────────────

  /// Validates [code] against active tours in /access_codes/{code},
  /// /tours where accessCode == input, or /tour_sessions/{sessionId}/codes.
  ///
  /// Returns the raw Firestore document snapshot if valid, or throws
  /// [AccessCodeException] with a specific code.
  static Future<DocumentSnapshot<Map<String, dynamic>>> validateCode(
      String code) async {
    final trimmed = code.trim().toUpperCase();

    // 1. Check index collection /access_codes/{code}
    try {
      final codeDoc = await _db.collection('access_codes').doc(trimmed).get();
      if (codeDoc.exists) {
        final codeData = codeDoc.data()!;
        final tourId = codeData['tourId'] as String? ?? codeDoc.id;
        final tourDoc = await _db.collection('tours').doc(tourId).get();
        if (tourDoc.exists) {
          final data = tourDoc.data()!;
          final status = (data['status'] as String? ?? 'active').toLowerCase();
          if (status == 'completed' || status == 'ended') {
            throw AccessCodeException('code-inactive');
          }
          return tourDoc;
        }
      }
    } catch (e) {
      if (e is AccessCodeException) rethrow;
    }

    // 2. Query /tours collection directly by accessCode
    try {
      final tourQuery = await _db
          .collection('tours')
          .where('accessCode', isEqualTo: trimmed)
          .limit(1)
          .get();

      if (tourQuery.docs.isNotEmpty) {
        final tourDoc = tourQuery.docs.first;
        final data = tourDoc.data();
        final status = (data['status'] as String? ?? 'active').toLowerCase();
        if (status == 'completed' || status == 'ended') {
          throw AccessCodeException('code-inactive');
        }
        return tourDoc;
      }
    } catch (e) {
      if (e is AccessCodeException) rethrow;
    }

    // 3. Fallback to legacy collectionGroup('codes')
    try {
      final query = await _db
          .collectionGroup('codes')
          .where('code', isEqualTo: trimmed)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final data = doc.data();
        if (data['isActive'] != true) {
          throw AccessCodeException('code-inactive');
        }
        return doc;
      }
    } catch (_) {}

    throw AccessCodeException('code-not-found');
  }

  /// Claims [codeDoc] for a tourist by writing their name and a timestamp.
  /// Also creates a TouristSession in the singleton manager.
  static Future<TouristSession> claimCode({
    required DocumentSnapshot<Map<String, dynamic>> codeDoc,
    required String touristName,
    String? contactNumber,
    String? emergencyContact,
  }) async {
    final data = codeDoc.data() ?? {};
    final isTourDoc = codeDoc.reference.parent.id == 'tours';

    String sessionId;
    String codeDocId;
    String code;

    if (isTourDoc) {
      sessionId = codeDoc.id;
      code = (data['accessCode'] as String? ?? '').toUpperCase();
      final tourName = data['name'] as String? ?? 'Tour';
      final totalDays = (data['totalDays'] as num?)?.toInt() ?? 1;

      // Ensure /tour_sessions/{sessionId} document exists and is synced
      await _db.collection('tour_sessions').doc(sessionId).set({
        'tourName': tourName,
        'totalDays': totalDays,
        'currentDay': 1,
        'status': 'active',
        'guideId': data['guideId'],
        'guideName': data['guideName'],
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      final codesCol =
          _db.collection('tour_sessions').doc(sessionId).collection('codes');

      final existingCodes = await codesCol
          .where('touristName', isEqualTo: touristName.trim())
          .limit(1)
          .get();

      if (existingCodes.docs.isNotEmpty) {
        codeDocId = existingCodes.docs.first.id;
      } else {
        final newDoc = codesCol.doc();
        codeDocId = newDoc.id;
        await newDoc.set({
          'code': code,
          'touristName': touristName.trim(),
          'isActive': true,
          'claimedAt': FieldValue.serverTimestamp(),
          'sessionId': sessionId,
        });

        // Also add pending join_request in /tours/{sessionId}/join_requests/{codeDocId}
        final joinReqRef = _db
            .collection('tours')
            .doc(sessionId)
            .collection('join_requests')
            .doc(codeDocId);

        await joinReqRef.set({
          'tourId': sessionId,
          'touristId': codeDocId,
          'touristName': touristName.trim(),
          'contactNumber': contactNumber?.trim() ?? '',
          'emergencyContact': emergencyContact?.trim() ?? '',
          'status': 'pending',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Legacy path: /tour_sessions/{sessionId}/codes/{codeDocId}
      sessionId = codeDoc.reference.parent.parent!.id;
      codeDocId = codeDoc.id;
      code = data['code'] as String? ?? '';

      final existingName = data['touristName'] as String?;
      if (existingName == null || existingName.isEmpty) {
        await codeDoc.reference.update({
          'touristName': touristName.trim(),
          'claimedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final session = TouristSession(
      code: code,
      touristName: touristName.trim(),
      sessionId: sessionId,
      codeDocId: codeDocId,
    );

    // Store globally in memory & SharedPreferences for easy access by other screens
    await TouristSessionManager.set(session);
    return session;
  }

  // ── Step 4: Guide Code Generation ──────────────────────

  /// Generates [count] random access codes under [sessionId] in Firestore.
  /// Uses a batch write for atomicity.
  static Future<void> generateCodes({
    required String sessionId,
    required int count,
  }) async {
    final batch = _db.batch();
    final codesRef = _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('codes');

    for (int i = 0; i < count; i++) {
      final newDoc = codesRef.doc(); // auto-id
      batch.set(newDoc, {
        'code': _generateRandomCode(),
        'isActive': true,
        'touristName': null,
        'claimedAt': null,
        'sessionId': sessionId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();
  }

  /// Returns a real-time stream of all code documents for [sessionId].
  static Stream<QuerySnapshot<Map<String, dynamic>>> watchCodes(
      String sessionId) {
    return _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('codes')
        .orderBy('createdAt', descending: false)
        .snapshots();
  }

  /// Deactivates a code by setting [isActive] to false.
  /// This makes it unavailable for tourist login without deleting the record.
  static Future<void> deactivateCode({
    required String sessionId,
    required String codeDocId,
  }) async {
    await _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('codes')
        .doc(codeDocId)
        .update({'isActive': false});
  }

  /// Permanently deletes a code document from Firestore.
  static Future<void> deleteCode({
    required String sessionId,
    required String codeDocId,
  }) async {
    await _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('codes')
        .doc(codeDocId)
        .delete();
  }

  /// Clears the tourist name from a code doc, making it available for re-claim.
  static Future<void> clearTouristName({
    required String sessionId,
    required String codeDocId,
  }) async {
    await _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('codes')
        .doc(codeDocId)
        .update({
      'touristName': null,
      'claimedAt': null,
    });
  }

  // ── Helpers ─────────────────────────────────────────────

  static String _generateRandomCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    final suffix = String.fromCharCodes(
      Iterable.generate(
        6,
        (_) => chars.codeUnitAt(random.nextInt(chars.length)),
      ),
    );
    return 'TRV-$suffix';
  }
}

/// Custom exception for access code errors.
class AccessCodeException implements Exception {
  final String code;
  AccessCodeException(this.code);

  String get message {
    switch (code) {
      case 'code-not-found':
        return 'Invalid access code. Please check the code and try again.';
      case 'code-inactive':
        return 'This code is no longer active. Please ask your guide for a new code.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
}
