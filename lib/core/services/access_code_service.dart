import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tourist_session.dart';

/// Service for all access-code operations.
/// Handles tourist login (Step 3) and guide code generation (Step 4).
class AccessCodeService {
  AccessCodeService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Step 3: Tourist Login ───────────────────────────────

  /// Validates [code] against all active codes across all tour sessions.
  ///
  /// Returns the raw Firestore document snapshot if valid, or throws
  /// [AccessCodeException] with a specific code.
  ///
  /// Query path: /tour_sessions/{sessionId}/codes where code == input AND isActive == true
  static Future<DocumentSnapshot<Map<String, dynamic>>> validateCode(
      String code) async {
    final trimmed = code.trim().toUpperCase();

    // Firestore doesn't support cross-collection queries easily, so we use
    // a collectionGroup query on "codes" sub-collections.
    final query = await _db
        .collectionGroup('codes')
        .where('code', isEqualTo: trimmed)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) {
      throw AccessCodeException('code-not-found');
    }

    final doc = query.docs.first;
    final data = doc.data();

    if (data['isActive'] != true) {
      throw AccessCodeException('code-inactive');
    }

    return doc;
  }

  /// Claims [codeDocRef] for a tourist by writing their name and a timestamp.
  /// Also creates a TouristSession in the singleton manager.
  ///
  /// If the code already has a touristName, it means it was previously claimed —
  /// we still allow entry (re-join) but don't overwrite the name unless it changed.
  static Future<TouristSession> claimCode({
    required DocumentSnapshot<Map<String, dynamic>> codeDoc,
    required String touristName,
  }) async {
    final data = codeDoc.data()!;

    // Extract sessionId from the parent document path
    // Path structure: /tour_sessions/{sessionId}/codes/{codeDocId}
    final sessionId = codeDoc.reference.parent.parent!.id;
    final codeDocId = codeDoc.id;
    final code = data['code'] as String;

    // Only write if not yet claimed or name changed
    final existingName = data['touristName'] as String?;
    if (existingName == null || existingName.isEmpty) {
      await codeDoc.reference.update({
        'touristName': touristName.trim(),
        'claimedAt': FieldValue.serverTimestamp(),
      });
    }

    final session = TouristSession(
      code: code,
      touristName: touristName.trim(),
      sessionId: sessionId,
      codeDocId: codeDocId,
    );

    TouristSessionManager.set(session);
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
