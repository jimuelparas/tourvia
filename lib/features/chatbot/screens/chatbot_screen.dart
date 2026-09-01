import 'package:flutter/material.dart';

import 'package:flutter_markdown/flutter_markdown.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/services/chatbot_service.dart';
import '../../chat/models/chat_message.dart';

/// Screen for the AI Chatbot Assistant (US-21).
/// Uses the Google Gemini API (gemini-1.5-flash) scoped to Philippine tourism.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen>
    with TickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;

  // Entrance animation
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  List<ChatMessage> _messages = [];
  bool _isLoadingHistory = true;

  final List<String> _quickPrompts = [
    '🏰 Intramuros',
    '🏖️ Boracay',
    '🌲 Baguio',
    '🏝️ Palawan',
    '🗻 Mayon Volcano',
    '🐟 Tubbataha Reef',
    '🌊 Siargao',
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    final history = await ChatbotService.loadHistory();
    if (!mounted) return;
    setState(() {
      _messages = history;
      _isLoadingHistory = false;
    });
    _scrollToBottom();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage([String? text]) async {
    final userText = (text ?? _textController.text).trim();
    if (userText.isEmpty || _isTyping || _isLoadingHistory) return;

    final userMsg = ChatMessage(
      id: 'user_${DateTime.now().millisecondsSinceEpoch}',
      senderId: 'current_user',
      senderName: 'You',
      text: userText,
      timestamp: DateTime.now(),
    );

    setState(() {
      _messages.add(userMsg);
      _textController.clear();
      _isTyping = true;
    });

    await ChatbotService.saveHistory();
    _scrollToBottom();

    try {
      final reply = await ChatbotService.ask(userText);
      if (!mounted) return;
      
      final botMsg = ChatMessage(
        id: 'bot_${DateTime.now().millisecondsSinceEpoch}',
        senderId: 'ai_bot',
        senderName: 'Tourvia AI',
        text: reply,
        timestamp: DateTime.now(),
        isGuide: true,
      );

      setState(() {
        _isTyping = false;
        _messages.add(botMsg);
      });

      await ChatbotService.saveHistory();
    } catch (e) {
      if (!mounted) return;
      final rawError = e.toString().replaceFirst('Exception: ', '').trim();
      final String errorMessage;
      if (rawError.contains('GEMINI_API_KEY') || rawError.contains('API key')) {
        errorMessage = '⚠️ **AI Assistant is not configured yet.**\n\n'
            'Please configure your `GEMINI_API_KEY` in Codemagic environment variables or `assets/env/.env`.';
      } else {
        errorMessage = '⚠️ Sorry, I couldn\'t get a response right now. '
            'Please check your internet connection and try again.\n\n'
            'Error: $rawError';
      }

      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            id: 'err_${DateTime.now().millisecondsSinceEpoch}',
            senderId: 'ai_bot',
            senderName: 'Tourvia AI',
            text: errorMessage,
            timestamp: DateTime.now(),
            isGuide: true,
          ),
        );
      });
    }

    _scrollToBottom();
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.accentTeal.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: AppColors.accentTeal, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Assistant',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  _isTyping ? 'Typing...' : 'Powered by Google Gemini',
                  style: TextStyle(
                    fontSize: 11,
                    color: _isTyping
                        ? AppColors.accent
                        : AppColors.textHint,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Clear Chat',
            onPressed: _isTyping || _isLoadingHistory
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Clear Chat'),
                        content: const Text(
                            'Are you sure you want to clear your chat history with Tourvia AI?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'Clear',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await ChatbotService.clearHistory();
                      if (!mounted) return;
                      setState(() {
                        _messages = ChatbotService.messages;
                      });
                    }
                  },
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: _isLoadingHistory
            ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.accentTeal,
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length && _isTyping) {
                          return _buildTypingIndicator();
                        }
                        final message = _messages[index];
                        final isMe = message.senderId == 'current_user';
                        return _buildMessageBubble(message, isMe);
                      },
                    ),
                  ),
                  _buildQuickPrompts(),
                  _buildInputArea(),
                ],
              ),
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.accentTeal,
            child: Icon(Icons.smart_toy_rounded,
                color: Colors.white, size: 18),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + (index * 200)),
      builder: (context, value, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.textHint.withValues(
              alpha: 0.3 + (0.7 * ((value * 3.14).remainder(1.0))),
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildMessageBubble(ChatMessage message, bool isMe) {
    if (isMe) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 20, left: 48),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4F9),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  message.text,
                  style: const TextStyle(
                    color: Color(0xFF1F1F1F),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // AI Message bubble (Gemini Style)
    return Padding(
      padding: const EdgeInsets.only(bottom: 28, right: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(6),
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0FE),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: MarkdownBody(
              data: message.text,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: const TextStyle(
                  fontSize: 15,
                  height: 1.65,
                  color: Color(0xFF2D2D2D),
                  letterSpacing: 0.1,
                ),
                h1: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                  height: 1.5,
                ),
                h2: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                  height: 1.5,
                ),
                h3: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1F1F1F),
                  height: 1.4,
                ),
                strong: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A1A),
                ),
                listBullet: const TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 15,
                  height: 1.6,
                ),
                listIndent: 22,
                blockSpacing: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPrompts() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: 38,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _quickPrompts.length,
          separatorBuilder: (_, __) => const SizedBox(width: 8),
          itemBuilder: (_, i) {
            return GestureDetector(
              onTap: _isTyping
                  ? null
                  : () {
                      // Strip emoji prefix for the query
                      final text = _quickPrompts[i]
                          .replaceAll(RegExp(r'^[^\w]+'), '')
                          .trim();
                      _sendMessage(text);
                    },
              child: AnimatedOpacity(
                opacity: _isTyping ? 0.4 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    _quickPrompts[i],
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                enabled: !_isTyping && !_isLoadingHistory,
                decoration: InputDecoration(
                  hintText: _isLoadingHistory
                      ? 'Loading history...'
                      : (_isTyping
                          ? 'AI is thinking...'
                          : 'Ask about PH destinations...'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _isTyping || _isLoadingHistory
                    ? AppColors.textHint
                    : AppColors.accentTeal,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: _isTyping
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
                onPressed: _isTyping || _isLoadingHistory ? null : () => _sendMessage(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
