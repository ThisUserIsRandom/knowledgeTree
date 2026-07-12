import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_message.dart';
import 'package:knowledgetree/features/chat/presentation/widgets/message_bubble.dart';
import 'package:knowledgetree/services/chat_api_service.dart';
import 'package:knowledgetree/services/chat_storage.dart';
import 'package:knowledgetree/services/content_sanitizer.dart';

class _DraggableChatSheet extends StatefulWidget {
  final String nodeId;
  final String nodeTitle;
  final VoidCallback onClose;

  const _DraggableChatSheet({
    required this.nodeId,
    required this.nodeTitle,
    required this.onClose,
  });

  @override
  State<_DraggableChatSheet> createState() => _DraggableChatSheetState();
}

class _DraggableChatSheetState extends State<_DraggableChatSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  int _chatContentVersion = 0;

  static const double _fullPosition = 0.1; // 90% screen
  static const double _halfPosition = 0.5; // 50% screen
  static const double _closePosition = 1.0; // Closed
  // Smallest usable height = status bar + header + input bar + a little content.
  static const double _minContentHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _halfPosition,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _snapTo(double value) {
    _controller.animateTo(value,
        duration: const Duration(milliseconds: 250), curve: Curves.easeOutCubic);
  }

  void _close() {
    _controller.animateTo(_closePosition, curve: Curves.easeInCubic).then((_) {
      if (mounted) widget.onClose();
    });
  }

  void _onDragUpdate(DragUpdateDetails details, double screenHeight) {
    _controller.value += details.primaryDelta! / screenHeight;
    _controller.value = _controller.value.clamp(_fullPosition, _closePosition);
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final pos = _controller.value;

    // Snap points: 0.1 = full (90%), 0.5 = half, 1.0 = closed
    if (velocity < -800 || pos < 0.25) {
      // Fast drag up or near top -> full screen (90%)
      _snapTo(_fullPosition);
    } else if (velocity > 800 || pos > 0.85) {
      // Fast drag down or near bottom -> close
      _close();
    } else if (pos < 0.4) {
      // Upper third -> full screen
      _snapTo(_fullPosition);
    } else if (pos > 0.6) {
      // Lower third -> close
      _close();
    } else {
      // Middle -> half screen
      _snapTo(_halfPosition);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final topPadding = MediaQuery.of(context).padding.top;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Controller: 0.1 = full (90%), 0.5 = half, 1.0 = closed
        final pos = _controller.value;
        if (pos >= 0.99) return const SizedBox.shrink();

        // Calculate visible height from bottom
        final maxHeight = screenHeight * 0.9; // 90% max
        final minHeight = topPadding + _minContentHeight;
        final height = (maxHeight * (1.0 - pos / _closePosition))
            .clamp(minHeight, maxHeight);

        return Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            height: height,
            child: _buildSheet(screenHeight, topPadding),
          ),
        );
      },
    );
  }

  Widget _buildSheet(double screenHeight, double topPadding) {
    return Container(
      margin: EdgeInsets.only(top: topPadding),
      decoration: const BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Color(0x260F172A),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragUpdate: (d) => _onDragUpdate(d, screenHeight),
            onVerticalDragEnd: _onDragEnd,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHandle(),
                _buildHeader(),
              ],
            ),
          ),
          Expanded(
            key: ValueKey('chat_${widget.nodeId}_$_chatContentVersion'),
            child: _ChatPanelContent(nodeId: widget.nodeId, onClose: _close),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 8, bottom: 4),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.textQuaternary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.aiContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.auto_awesome, color: AppColors.ai, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.nodeTitle,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: AppColors.urgent, size: 22),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  backgroundColor: AppColors.surfaceCard,
                  surfaceTintColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: AppColors.border, width: 1),
                  ),
                  title: Text('Clear chat',
                      style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
                  content: Text('Delete all messages for this node?',
                      style: TextStyle(color: AppColors.textSecondary)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx).pop(false),
                      child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(true),
                      style: FilledButton.styleFrom(backgroundColor: AppColors.urgent),
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
              if (confirm == true && mounted) {
                await ChatStorage.delete(widget.nodeId);
                setState(() => _chatContentVersion++);
              }
            },
            tooltip: 'Clear chat',
          ),
          IconButton(
            icon: Icon(Icons.close, color: AppColors.textSecondary, size: 22),
            onPressed: _close,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _ChatPanelContent extends StatefulWidget {
  final String nodeId;
  final VoidCallback onClose;

  const _ChatPanelContent({required this.nodeId, required this.onClose});

  @override
  State<_ChatPanelContent> createState() => _ChatPanelContentState();
}

class _ChatPanelContentState extends State<_ChatPanelContent> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _apiService = ChatApiService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  String _streamBuffer = '';

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    final raw = await ChatStorage.load(widget.nodeId);
    if (!mounted) return;
    setState(() {
      _messages = raw.map((m) => ChatMessage(
        id: '${m['role'] == 'user' ? 'usr' : 'asst'}_${DateTime.now().millisecondsSinceEpoch}',
        role: m['role'] == 'user' ? MessageRole.user : MessageRole.assistant,
        content: m['content'] ?? '',
      )).toList();
    });
  }

  Future<void> _saveMessages() async {
    await ChatStorage.save(
      widget.nodeId,
      _messages.map((m) => m.toApiMap()).toList(),
    );
  }

  Future<void> _copyMessage(String content) async {
    await Clipboard.setData(ClipboardData(text: content));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Copied to clipboard'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteMessage(int index) async {
    if (index < 0 || index >= _messages.length) return;
    setState(() {
      _messages.removeAt(index);
      // If we just removed a user question, also drop its paired answer
      // so a dangling response isn't left behind.
      if (index < _messages.length &&
          _messages[index].role == MessageRole.assistant) {
        _messages.removeAt(index);
      }
    });
    await _saveMessages();
  }

  Future<void> _sendMessage() async {
    final text = ContentSanitizer.sanitize(_controller.text.trim());
    if (text.isEmpty || _isStreaming) return;
    _controller.clear();

    final prefs = await SharedPreferences.getInstance();
    var baseUrl = prefs.getString('base_url') ?? '';
    if (baseUrl.endsWith('/')) baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    if (baseUrl.isNotEmpty && !baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      baseUrl = 'http://$baseUrl';
    }
    final apiKey = prefs.getString('api_key') ?? '';
    final model = prefs.getString('model_name') ?? 'tencent/hy3:free';

    final userMsg = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    final apiMessages = _messages
        .where((m) => m.role == MessageRole.user || m.role == MessageRole.assistant)
        .map((m) => m.toApiMap())
        .toList();

    _isStreaming = true;
    _streamBuffer = '';

    final error = await _apiService.streamChat(
      baseUrl: baseUrl,
      model: model,
      messages: apiMessages,
      apiKey: apiKey.isNotEmpty ? apiKey : null,
      onChunk: (chunk) {
        if (!mounted) return;
        _streamBuffer += chunk;
        setState(() {
          _isLoading = false;
          if (_messages.isNotEmpty && _messages.last.role == MessageRole.assistant) {
            _messages.last = _messages.last.copyWith(content: _streamBuffer);
          } else {
            _messages.add(ChatMessage(
              id: 'asst_${DateTime.now().millisecondsSinceEpoch}',
              role: MessageRole.assistant,
              content: _streamBuffer,
            ));
          }
        });
        _scrollToBottom();
      },
      onError: (err) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _messages.add(ChatMessage(
            id: 'asst_${DateTime.now().millisecondsSinceEpoch}',
            role: MessageRole.assistant,
            content: 'Error: ${err.message}',
          ));
        });
      },
    );

    if (error != null && mounted) {
      setState(() {
        _isLoading = false;
        _messages.add(ChatMessage(
          id: 'asst_${DateTime.now().millisecondsSinceEpoch}',
          role: MessageRole.assistant,
          content: 'Error: $error',
        ));
      });
    }

    _isStreaming = false;
    if (mounted) {
      setState(() => _isLoading = false);
    }
    if (_streamBuffer.isNotEmpty && _messages.isNotEmpty) {
      _messages.last = _messages.last.copyWith(content: _streamBuffer);
    }
    _saveMessages();
  }

  void _pauseGeneration() {
    _apiService.cancel();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(32),
                          ),
                          child: Icon(Icons.chat_bubble_outline, color: AppColors.primary, size: 32),
                        ),
                        const SizedBox(height: 16),
                        Text('Ask anything about this node',
                            style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('Start a conversation with AI',
                            style: TextStyle(color: AppColors.textQuaternary, fontSize: 13)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 8),
                  itemCount: _messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length) {
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      );
                    }
                    return MessageBubble(
                      message: _messages[index],
                      isStreaming: _isStreaming &&
                          index == _messages.length - 1 &&
                          _messages[index].role == MessageRole.assistant,
                      onCopy: _messages[index].role == MessageRole.assistant
                          ? () => _copyMessage(_messages[index].content)
                          : null,
                      onDelete: () => _deleteMessage(index),
                    );
                  },
                ),
        ),
        Container(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).padding.bottom + 8),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            border: Border(top: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Ask AI...',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(28),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                    ),
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: _isStreaming ? AppColors.urgent : AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isStreaming ? AppColors.urgent : AppColors.primary).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      _isStreaming ? Icons.stop_rounded : Icons.arrow_upward,
                      color: AppColors.textOnPrimary,
                      size: 22,
                    ),
                    onPressed: _isStreaming ? _pauseGeneration : _sendMessage,
                    tooltip: _isStreaming ? 'Pause' : 'Send',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

Widget buildChatSheet(
    BuildContext context, String nodeId, String nodeTitle, VoidCallback onClose) {
  return _DraggableChatSheet(
    nodeId: nodeId,
    nodeTitle: nodeTitle,
    onClose: onClose,
  );
}