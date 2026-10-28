import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../models/chat.dart';
import '../services/chat_hub_service.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dispatcher Chat')),
      body: const ChatView(),
    );
  }
}

class ChatView extends StatefulWidget {
  const ChatView({super.key});

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _messageController = TextEditingController();
  final List<AppChatMessageDto> _messages = [];
  Timer? _pollingTimer;
  bool _isLoading = true;
  bool _isFetching = false;
  bool _showConnectionError = false;


  // For this design app, we'll assume a single main conversation
  // In production, receive ID via arguments
  String _conversationId = 'default-conv-id';

  @override
  void initState() {
    super.initState();
    unawaited(_initializeChat());
    chatHubService.onMessageReceived(_handleMessageReceived);
  }

  void _handleMessageReceived(List<Object?>? arguments) {
    if (mounted) _fetchMessages(silent: true);
  }

  Future<void> _initializeChat() async {
    final token = apiService.token;
    if (token != null && token.isNotEmpty) {
      try {
        await chatHubService.connect(token);
      } catch (e) {
        debugPrint('Chat hub connect skipped: $e');
      }
    }

    await _fetchMessages();
    if (mounted) {
      _pollingTimer?.cancel();
      _pollingTimer = Timer.periodic(
        const Duration(seconds: 10),
        (_) => _fetchMessages(silent: true),
      );
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _pollingTimer?.cancel();
    chatHubService.offMessageReceived(_handleMessageReceived);
    super.dispose();
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      if (!silent) setState(() => _isLoading = true);

      // We first need a conversation ID. If none, get the first available.
      if (_conversationId == 'default-conv-id') {
        final convs = await apiService.getConversations();
        if (convs.isNotEmpty) {
          _conversationId = convs.first.id;
        } else {
          _conversationId = await apiService.createConversation();
        }
      }

      final pagedResponse = await apiService.getMessages(_conversationId);
      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(pagedResponse.items);
          _isLoading = false;
          _showConnectionError = false;
        });
        await apiService.markAsRead(_conversationId);
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        if (mounted) setState(() => _showConnectionError = true);
      }
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final originalText = _messageController.text;
    _messageController.clear();
    try {
      await apiService.sendMessage(
        _conversationId,
        SendAppMessageRequest(content: text),
      );
      setState(() => _showConnectionError = false);
      _fetchMessages(silent: true);
    } on DioException catch (e) {
      _messageController.text = originalText;
      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout) {
        if (mounted) setState(() => _showConnectionError = true);
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
      }
    } catch (e) {
      _messageController.text = originalText;
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not send message: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    return Column(
      children: [
        if (_showConnectionError)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.red.shade100,
            child: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.red.shade900, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No internet connection. Please check your network.',
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: ListView.builder(
            reverse: true,
            padding: const EdgeInsets.all(16.0),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final message = _messages[index];
              return _MessageBubble(message: message);
            },
          ),
        ),
        _buildInputArea(cs),
      ],
    );
  }

  Widget _buildInputArea(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              enabled: !_showConnectionError,
              decoration: InputDecoration(
                hintText: _showConnectionError
                    ? 'Connect to internet to send message'
                    : 'Type your message...',
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: _showConnectionError ? null : _sendMessage,
            icon: const Icon(Icons.send_rounded),
            color: cs.onPrimary,
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final AppChatMessageDto message;
  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isMine = message.isMine;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? cs.primary : cs.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 0),
            bottomRight: Radius.circular(isMine ? 0 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isMine ? cs.onPrimary : cs.onSurface,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _formatTime(message.dateCreated),
              style: TextStyle(
                color: (isMine ? cs.onPrimary : cs.onSurface).withValues(
                  alpha: 0.6,
                ),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
