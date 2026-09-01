import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/models/tourist_session.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/attendance_service.dart';
import '../models/chat_message.dart';

/// Screen for the Group Chat (US-19 & US-20).
/// - Text messages: real-time via Firestore StreamBuilder.
/// - Media: image_picker → Firebase Storage upload → Firestore message doc.
class GroupChatScreen extends StatefulWidget {
  final bool isCurrentUserGuide;
  final String sessionId;

  const GroupChatScreen({
    super.key,
    this.isCurrentUserGuide = false,
    required this.sessionId,
  });

  @override
  State<GroupChatScreen> createState() => _GroupChatScreenState();
}

class _GroupChatScreenState extends State<GroupChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _isSending = false;

  // Upload progress: null means no upload in progress.
  double? _uploadProgress;

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ── Identity helpers ──────────────────────────────────────────────────────

  String get _senderId => widget.isCurrentUserGuide
      ? (AuthService.currentUser?.uid ?? 'guide')
      : (TouristSessionManager.current?.codeDocId ?? 'tourist');

  String get _senderName => widget.isCurrentUserGuide
      ? (AuthService.currentUser?.displayName ?? 'Guide')
      : (TouristSessionManager.current?.touristName ?? 'Tourist');

  // ── Send text ─────────────────────────────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _textController.clear();

    try {
      await ChatService.sendMessage(
        sessionId: widget.sessionId,
        senderId: _senderId,
        senderName: _senderName,
        text: text,
        isGuide: widget.isCurrentUserGuide,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }

    _scrollToBottom();
  }

  // ── Pick & upload media ───────────────────────────────────────────────────

  Future<void> _pickAndUploadMedia(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;

    setState(() {
      _uploadProgress = 0.0;
      _isSending = true;
    });

    try {
      // Pass XFile directly — readAsBytes()+putData() works on web & mobile.
      final downloadUrl = await ChatService.uploadMedia(
        widget.sessionId,
        picked,
        onProgress: (progress) {
          if (mounted) setState(() => _uploadProgress = progress);
        },
      );

      await ChatService.sendMessage(
        sessionId: widget.sessionId,
        senderId: _senderId,
        senderName: _senderName,
        text: 'Shared a photo 📷',
        isGuide: widget.isCurrentUserGuide,
        isMedia: true,
        mediaUrl: downloadUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _uploadProgress = null;
          _isSending = false;
        });
      }
    }

    _scrollToBottom();
  }

  void _showMediaSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(Icons.camera_alt_rounded, color: AppColors.primary),
                ),
                title: const Text('Take a Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: AppColors.primarySurface,
                  child: Icon(Icons.photo_library_rounded, color: AppColors.primary),
                ),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickAndUploadMedia(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Delete message ────────────────────────────────────────────────────────

  Future<void> _confirmDeleteMessage(ChatMessage message) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Message'),
        content: Text(
          message.isMedia
              ? 'Delete this photo and message? This cannot be undone.'
              : 'Delete this message? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await ChatService.deleteMessage(
          sessionId: widget.sessionId,
          messageId: message.id,
          mediaUrl: message.mediaUrl,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Message deleted'),
                ],
              ),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    }
  }

  // ── Scroll ────────────────────────────────────────────────────────────────

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Image viewer & download ───────────────────────────────────────────────

  void _openImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
        child: Stack(
          children: [
            // Dismiss on background tap
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: const ColoredBox(color: Colors.transparent),
              ),
            ),
            // Full-screen pinch-to-zoom image
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const SizedBox(
                      height: 200,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_rounded,
                    color: Colors.white54,
                    size: 64,
                  ),
                ),
              ),
            ),
            // Close button (top-right)
            Positioned(
              top: 40,
              right: 16,
              child: SafeArea(
                child: CircleAvatar(
                  backgroundColor: Colors.black45,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ),
              ),
            ),
            // Download button (bottom-centre)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: _DownloadButton(imageUrl: imageUrl),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tour Group Chat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            StreamBuilder<List<TouristRecord>>(
              stream: AttendanceService.watchRoster(widget.sessionId),
              builder: (context, snapshot) {
                final count = (snapshot.data?.length ?? 0) + 1; // +1 for guide
                return Text(
                  '$count members • Online',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.normal,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Upload progress bar
          if (_uploadProgress != null)
            Column(
              children: [
                LinearProgressIndicator(
                  value: _uploadProgress,
                  backgroundColor: AppColors.border,
                  color: AppColors.primary,
                  minHeight: 3,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.cloud_upload_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Uploading… ${(_uploadProgress! * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // Chat messages
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: ChatService.watchMessages(widget.sessionId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.chat_bubble_outline_rounded,
                            size: 48, color: AppColors.textHint),
                        SizedBox(height: 12),
                        Text(
                          'No messages yet.\nBe the first to say hello! 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textHint),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToBottom());

                final currentUserId = _senderId;

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),

          _buildInputArea(),
        ],
      ),
    );
  }

  // ── Message bubble ────────────────────────────────────────────────────────

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    return GestureDetector(
      onLongPress: isMe ? () => _confirmDeleteMessage(message) : null,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              CircleAvatar(
                radius: 16,
                backgroundColor: message.isGuide
                    ? AppColors.primary
                    : AppColors.primarySurface,
                child: Text(
                  message.senderName[0],
                  style: TextStyle(
                    color: message.isGuide ? Colors.white : AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isMe ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(isMe ? 16 : 0),
                    bottomRight: Radius.circular(isMe ? 0 : 16),
                  ),
                  border: Border.all(
                    color: isMe ? Colors.transparent : AppColors.border,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isMe)
                      Text(
                        message.isGuide
                            ? '${message.senderName} (Guide)'
                            : message.senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: message.isGuide
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    if (!isMe) const SizedBox(height: 4),

                    // Media image
                    if (message.isMedia && message.mediaUrl != null) ...[
                      GestureDetector(
                        onTap: () => _openImageViewer(message.mediaUrl!),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final imgWidth = MediaQuery.of(context).size.width * 0.58;
                              return Image.network(
                                message.mediaUrl!,
                                height: 180,
                                width: imgWidth,
                                fit: BoxFit.cover,
                                loadingBuilder: (ctx, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    height: 180,
                                    width: imgWidth,
                                    alignment: Alignment.center,
                                    color: AppColors.surfaceVariant,
                                    child: CircularProgressIndicator(
                                      value: progress.expectedTotalBytes != null
                                          ? progress.cumulativeBytesLoaded /
                                              progress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (_, __, ___) => Container(
                                  height: 180,
                                  width: imgWidth,
                                  color: AppColors.surfaceVariant,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image_rounded,
                                      color: AppColors.textHint),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],

                    // Caption text
                    if (message.text.isNotEmpty)
                      Text(
                        message.text,
                        style: TextStyle(
                          color: isMe ? Colors.white : AppColors.textPrimary,
                        ),
                      ),

                    const SizedBox(height: 4),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        '${message.timestamp.hour}:${message.timestamp.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isMe) const SizedBox(width: 24),
          ],
        ),
      ),
    );
  }

  // ── Input area ────────────────────────────────────────────────────────────

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.add_photo_alternate_rounded,
                color: _isSending ? AppColors.textHint : AppColors.primary,
              ),
              tooltip: 'Send a photo',
              onPressed: _isSending ? null : _showMediaSourceSheet,
            ),
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !_isSending,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isSending ? AppColors.border : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }
}

// ── Download Button Widget ────────────────────────────────────────────────────
// Stateful so it can show its own loading indicator while downloading.

class _DownloadButton extends StatefulWidget {
  final String imageUrl;
  const _DownloadButton({required this.imageUrl});

  @override
  State<_DownloadButton> createState() => _DownloadButtonState();
}

class _DownloadButtonState extends State<_DownloadButton> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    setState(() => _downloading = true);

    try {
      // 1. Fetch image bytes via HTTP
      final response = await http.get(Uri.parse(widget.imageUrl));
      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) throw Exception('Downloaded file is empty');

      // 2. Determine save directory
      //    On Android we write to the public Pictures folder so the image
      //    is immediately visible in the device gallery / Files app.
      //    On other platforms we fall back to the app documents directory.
      final String dirPath;
      if (Platform.isAndroid) {
        dirPath = '/storage/emulated/0/Pictures/Tourvia';
      } else {
        // iOS / Desktop: we just surface a message that download is
        // Android-only for now, rather than crash.
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image download is supported on Android.')),
          );
        }
        return;
      }

      // 3. Create directory if needed
      final dir = Directory(dirPath);
      if (!dir.existsSync()) dir.createSync(recursive: true);

      // 4. Write file
      final fileName = 'tourvia_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('$dirPath/$fileName');
      await file.writeAsBytes(bytes, flush: true);

      // Verify the file was actually written
      if (!file.existsSync() || file.lengthSync() == 0) {
        throw Exception('File was not written correctly');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text('Image saved to Pictures/Tourvia'),
              ],
            ),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _downloading ? null : _download,
      icon: _downloading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.download_rounded),
      label: Text(_downloading ? 'Saving…' : 'Download'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }
}
