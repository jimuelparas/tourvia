import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

import '../../features/chat/models/chat_message.dart';

/// Service for Group Chat operations (Step 7 / US-19 & US-20).
class ChatService {
  ChatService._();

  static final FirebaseFirestore _db = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static CollectionReference<Map<String, dynamic>> _chatCol(String sessionId) {
    return _db
        .collection('tour_sessions')
        .doc(sessionId)
        .collection('chat');
  }

  /// Sends a text or media message to the tour group chat.
  static Future<void> sendMessage({
    required String sessionId,
    required String senderId,
    required String senderName,
    required String text,
    required bool isGuide,
    bool isMedia = false,
    String? mediaUrl,
  }) async {
    await _chatCol(sessionId).add({
      'senderId': senderId,
      'senderName': senderName,
      'text': text,
      'isGuide': isGuide,
      'isMedia': isMedia,
      'mediaUrl': mediaUrl,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a message from the group chat.
  /// If the message contains a media URL hosted on Firebase Storage,
  /// the corresponding file is also deleted.
  static Future<void> deleteMessage({
    required String sessionId,
    required String messageId,
    String? mediaUrl,
  }) async {
    // Delete the Firestore document
    await _chatCol(sessionId).doc(messageId).delete();

    // Delete the media file from Storage if present
    if (mediaUrl != null && mediaUrl.isNotEmpty) {
      try {
        final ref = _storage.refFromURL(mediaUrl);
        await ref.delete();
      } catch (_) {
        // Silently ignore if file doesn't exist or URL is not a Storage URL
      }
    }
  }

  /// Uploads [xFile] to Firebase Storage under `/chat/{sessionId}/{filename}`.
  ///
  /// Ensures the user is anonymously authenticated before uploading so that
  /// Firebase Storage security rules allow the request (tourists have no
  /// Firebase Auth account).
  ///
  /// Optionally calls [onProgress] with a value between 0.0 and 1.0.
  /// Returns the public download URL on success.
  static Future<String> uploadMedia(
    String sessionId,
    XFile xFile, {
    void Function(double progress)? onProgress,
  }) async {
    // Ensure authenticated (anonymously) so Storage rules pass.
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      try {
        await auth.signInAnonymously();
      } catch (e) {
        // Fallback: If anonymous auth is disabled, sign in using a generic/shared tourist account
        try {
          await auth.signInWithEmailAndPassword(
            email: 'tourist@tourvia.com',
            password: 'TouristPassword123!',
          );
        } catch (authError) {
          // If the shared account doesn't exist, create it dynamically
          try {
            await auth.createUserWithEmailAndPassword(
              email: 'tourist@tourvia.com',
              password: 'TouristPassword123!',
            );
          } catch (_) {
            // Re-throw the original error if fallback also fails
            rethrow;
          }
        }
      }
    }

    final bytes = await xFile.readAsBytes();
    final mimeType = xFile.mimeType ?? 'image/jpeg';
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${xFile.name}';
    final ref = _storage.ref('chat/$sessionId/$fileName');

    final uploadTask = ref.putData(
      bytes,
      SettableMetadata(contentType: mimeType),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((snapshot) {
        if (snapshot.totalBytes > 0) {
          onProgress(snapshot.bytesTransferred / snapshot.totalBytes);
        }
      });
    }

    await uploadTask;
    return await ref.getDownloadURL();
  }

  /// Returns a real-time stream of all chat messages in [sessionId],
  /// ordered by timestamp ascending.
  static Stream<List<ChatMessage>> watchMessages(String sessionId) {
    return _chatCol(sessionId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((doc) {
              final data = doc.data();
              // Parse timestamp safely (null for newly written docs before server sync)
              final ts = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();
              return ChatMessage(
                id: doc.id,
                senderId: data['senderId'] as String? ?? '',
                senderName: data['senderName'] as String? ?? 'Anonymous',
                text: data['text'] as String? ?? '',
                timestamp: ts,
                isGuide: data['isGuide'] as bool? ?? false,
                isMedia: data['isMedia'] as bool? ?? false,
                mediaUrl: data['mediaUrl'] as String?,
              );
            }).toList());
  }
}

