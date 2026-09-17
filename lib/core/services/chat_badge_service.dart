import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to track per-user unread message counts per tour.
///
/// Firestore schema:
///   /tours/{tourId}/chat_read_status/{userId} → { lastReadTimestamp: Timestamp }
///
/// The unread count is computed by comparing each chat message's
/// timestamp against the user's `lastReadTimestamp`, excluding messages
/// sent by the user themselves.
class ChatBadgeService {
  ChatBadgeService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Update last-read timestamp ──────────────────────────────

  /// Marks all messages in [tourId] as read for [userId].
  /// Call this when the user opens the Group Chat screen.
  static Future<void> updateLastRead(String tourId, String userId) async {
    final tId = tourId.trim();
    final uId = userId.trim();
    if (tId.isEmpty || uId.isEmpty) return;

    final data = {
      'lastReadTimestamp': FieldValue.serverTimestamp(),
    };

    try {
      await _db
          .collection('tours')
          .doc(tId)
          .collection('chat_read_status')
          .doc(uId)
          .set(data, SetOptions(merge: true));
    } catch (_) {}

    try {
      await _db
          .collection('tour_sessions')
          .doc(tId)
          .collection('chat_read_status')
          .doc(uId)
          .set(data, SetOptions(merge: true));
    } catch (_) {}
  }

  // ── Watch unread count ──────────────────────────────────────

  /// Returns a real-time stream of the number of unread messages
  /// in [tourId] for [userId].
  ///
  /// A message is "unread" if:
  ///   1. Its `senderId` is NOT the current user
  ///   2. Its timestamp is after the user's `lastReadTimestamp` (or if the user
  ///      has never opened the chat, all messages from others are unread).
  ///
  /// Listens to both the messages collection and the user's read status document
  /// in real-time, emitting an updated count whenever either changes.
  static Stream<int> watchUnreadCount(String tourId, String userId) {
    final tId = tourId.trim();
    final uId = userId.trim();
    if (tId.isEmpty || uId.isEmpty) return Stream.value(0);

    final chatCol = _db.collection('tours').doc(tId).collection('chat');
    final statusDoc = _db
        .collection('tours')
        .doc(tId)
        .collection('chat_read_status')
        .doc(uId);

    late StreamController<int> controller;
    StreamSubscription? chatSub;
    StreamSubscription? statusSub;

    QuerySnapshot<Map<String, dynamic>>? latestChatSnap;
    DocumentSnapshot<Map<String, dynamic>>? latestStatusSnap;
    bool statusLoaded = false;
    bool chatLoaded = false;

    void recalculateAndEmit() {
      if (controller.isClosed) return;

      // Wait until both initial snapshots are received to prevent flickering
      if (!chatLoaded || !statusLoaded) return;

      final lastRead =
          latestStatusSnap?.data()?['lastReadTimestamp'] as Timestamp?;

      final docs = latestChatSnap?.docs ?? [];
      int count = 0;

      for (final doc in docs) {
        final data = doc.data();
        final senderId = (data['senderId'] as String? ?? '').trim();
        final ts = data['timestamp'] as Timestamp?;

        // 1. Skip messages sent by the current user
        if (senderId == uId) continue;

        // 2. If user has never read the chat, count all messages from others
        if (lastRead == null) {
          count++;
          continue;
        }

        // 3. If timestamp is null (e.g. pending write from other user), count as unread
        if (ts == null) {
          count++;
          continue;
        }

        // 4. Count as unread if message timestamp is newer than lastReadTimestamp
        if (ts.compareTo(lastRead) > 0) {
          count++;
        }
      }

      // Check legacy collection if primary collection has 0 messages
      if (docs.isEmpty) {
        _db
            .collection('tour_sessions')
            .doc(tId)
            .collection('chat')
            .orderBy('timestamp', descending: false)
            .get()
            .then((legSnap) {
          if (controller.isClosed || legSnap.docs.isEmpty) {
            if (!controller.isClosed) controller.add(0);
            return;
          }
          int legCount = 0;
          for (final doc in legSnap.docs) {
            final data = doc.data();
            final senderId = (data['senderId'] as String? ?? '').trim();
            final ts = data['timestamp'] as Timestamp?;
            if (senderId == uId) continue;
            if (lastRead == null) {
              legCount++;
              continue;
            }
            if (ts == null) {
              legCount++;
              continue;
            }
            if (ts.compareTo(lastRead) > 0) {
              legCount++;
            }
          }
          if (!controller.isClosed) controller.add(legCount);
        }).catchError((_) {
          if (!controller.isClosed) controller.add(0);
        });
      } else {
        controller.add(count);
      }
    }

    controller = StreamController<int>.broadcast(
      onListen: () {
        statusSub = statusDoc.snapshots().listen(
          (snap) {
            latestStatusSnap = snap;
            statusLoaded = true;
            recalculateAndEmit();
          },
          onError: (_) {
            statusLoaded = true;
            recalculateAndEmit();
          },
        );

        chatSub = chatCol
            .orderBy('timestamp', descending: false)
            .snapshots()
            .listen(
          (snap) {
            latestChatSnap = snap;
            chatLoaded = true;
            recalculateAndEmit();
          },
          onError: (_) {
            chatLoaded = true;
            if (!controller.isClosed) controller.add(0);
          },
        );
      },
      onCancel: () async {
        await chatSub?.cancel();
        await statusSub?.cancel();
      },
    );

    return controller.stream;
  }
}
