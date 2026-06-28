class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final DateTime timestamp;
  final bool isMedia;
  final String? mediaUrl;
  final bool isGuide;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.isMedia = false,
    this.mediaUrl,
    this.isGuide = false,
  });
}
