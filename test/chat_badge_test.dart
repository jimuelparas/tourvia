import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat Unread Count Logic', () {
    test('filters out messages sent by the current user', () {
      final currentUserId = 'user_123';
      final messages = [
        {'senderId': 'user_123', 'text': 'Hello'},
        {'senderId': 'user_123', 'text': 'How are you?'},
      ];

      int unread = 0;
      for (final msg in messages) {
        if (msg['senderId'] == currentUserId) continue;
        unread++;
      }

      expect(unread, 0);
    });

    test('counts messages from other users when user has never read chat', () {
      final currentUserId = 'user_123';
      final messages = [
        {'senderId': 'user_456', 'text': 'Welcome to the tour!'},
        {'senderId': 'user_123', 'text': 'Thanks!'},
        {'senderId': 'user_789', 'text': 'Excited to be here!'},
      ];

      int computeUnread(List<Map<String, dynamic>> msgs, DateTime? lr) {
        int count = 0;
        for (final msg in msgs) {
          if (msg['senderId'] == currentUserId) continue;
          if (lr == null) {
            count++;
            continue;
          }
          final ts = msg['timestamp'] as DateTime?;
          if (ts == null || ts.isAfter(lr)) {
            count++;
          }
        }
        return count;
      }

      final unread = computeUnread(messages, null);

      expect(unread, 2);
    });

    test('counts only messages newer than lastReadTimestamp', () {
      final currentUserId = 'user_123';
      final t0 = DateTime(2026, 9, 14, 10, 0);
      final t1 = DateTime(2026, 9, 14, 10, 5); // lastRead
      final t2 = DateTime(2026, 9, 14, 10, 10);
      final t3 = DateTime(2026, 9, 14, 10, 15);

      final messages = [
        {'senderId': 'guide_1', 'timestamp': t0},
        {'senderId': 'guide_1', 'timestamp': t1},
        {'senderId': 'guide_1', 'timestamp': t2},
        {'senderId': 'tourist_2', 'timestamp': t3},
        {'senderId': 'user_123', 'timestamp': DateTime(2026, 9, 14, 10, 16)},
      ];

      final lastRead = t1;

      int unread = 0;
      for (final msg in messages) {
        if (msg['senderId'] == currentUserId) continue;
        final ts = msg['timestamp'] as DateTime;
        if (ts.isAfter(lastRead)) {
          unread++;
        }
      }

      expect(unread, 2); // t2 and t3 from other users
    });

    test('unread count is 0 when all messages have been read', () {
      final currentUserId = 'user_123';
      final t0 = DateTime(2026, 9, 14, 10, 0);
      final t1 = DateTime(2026, 9, 14, 10, 5);
      final lastRead = DateTime(2026, 9, 14, 10, 10); // after all messages

      final messages = [
        {'senderId': 'guide_1', 'timestamp': t0},
        {'senderId': 'guide_1', 'timestamp': t1},
      ];

      int unread = 0;
      for (final msg in messages) {
        if (msg['senderId'] == currentUserId) continue;
        final ts = msg['timestamp'] as DateTime;
        if (ts.isAfter(lastRead)) {
          unread++;
        }
      }

      expect(unread, 0);
    });
  });
}
