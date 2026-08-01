import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/core/utils/backend_url.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_message.dart';
import 'package:knowledgetree/features/chat/presentation/widgets/message_bubble.dart';
import 'package:knowledgetree/features/chat/presentation/widgets/web_search_animation.dart';
import 'package:knowledgetree/services/chat_api_service.dart';
import 'package:knowledgetree/services/chat_storage.dart';
import 'package:knowledgetree/services/content_sanitizer.dart';
import 'package:knowledgetree/services/rag_api_service.dart';

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
  final _ragApiService = RagApiService();
  List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _isStreaming = false;
  bool _streamFailed = false;
  String _streamBuffer = '';

  bool _ragSearching = false;
  String _ragStage = '';
  String _ragStageMessage = '';
  String _ragQuery = '';
  int _ragAttempt = 1;
  List<String> _ragSources = const [];

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
    if (text.isEmpty || _isStreaming || _ragSearching) return;
    _controller.clear();

    final prefs = await SharedPreferences.getInstance();
    final baseUrl = BackendUrl.resolve(prefs.getString('base_url') ?? '');
    final apiKey = prefs.getString('api_key') ?? '';
    final model = prefs.getString('model_name') ?? 'openai/gpt-oss-20b:free';

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
    _streamFailed = false;

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
        _streamFailed = true;
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
    // Finalize the streamed answer only when it's the assistant bubble we were
    // filling. Without the guard, an error bubble added by [onError] above
    // would get overwritten with the full buffered answer -> duplicated text.
    if (_streamBuffer.isNotEmpty &&
        _messages.isNotEmpty &&
        !_streamFailed &&
        _messages.last.role == MessageRole.assistant) {
      _messages.last = _messages.last.copyWith(content: _streamBuffer);
    }
    _saveMessages();
  }

  void _pauseGeneration() {
    _apiService.cancel();
  }

  String _normalizeBaseUrl(String raw) {
    return BackendUrl.resolve(raw);
  }

  Future<String> _backendBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return _normalizeBaseUrl(prefs.getString('base_url') ?? '');
  }

  /// Ask a question with internet retrieval: the backend runs the RAG
  /// pipeline (DuckDuckGo search -> crawl -> BM25 index -> LLM answer) and
  /// streams stage events that drive the [WebSearchAnimation].
  Future<void> _runWebSearch() async {
    final text = ContentSanitizer.sanitize(_controller.text.trim());
    if (text.isEmpty) {
      _showSnack('Type a question first, then tap the web search icon',
          isError: true);
      return;
    }
    if (_isStreaming || _ragSearching) return;
    _controller.clear();

    final baseUrl = await _backendBaseUrl();
    if (baseUrl.isEmpty) {
      _showSnack('Backend URL not configured', isError: true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final model = prefs.getString('model_name') ?? '';
    final apiKey = prefs.getString('api_key') ?? '';

    final userMsg = ChatMessage(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.user,
      content: text,
    );

    setState(() {
      _messages.add(userMsg);
      _ragSearching = true;
      _ragQuery = text;
      _ragStage = 'searching';
      _ragStageMessage = 'Connecting to backend...';
      _ragAttempt = 1;
      _ragSources = const [];
    });
    _scrollToBottom();

    final result = await _ragApiService.search(
      baseUrl: baseUrl,
      query: text,
      mode: 'web',
      model: model,
      apiKey: apiKey.isNotEmpty ? apiKey : null,
      onStage: (stage) {
        if (!mounted) return;
        setState(() {
          _ragStage = stage.stage;
          _ragStageMessage = stage.message;
          if (stage.attempt > _ragAttempt) _ragAttempt = stage.attempt;
        });
        _scrollToBottom();
      },
    );

    if (!mounted) return;
    setState(() {
      _ragSearching = false;
      _ragSources = result.sources;
    });

    if (result.error != null && result.error!.isNotEmpty) {
      setState(() {
        _messages.add(ChatMessage(
          id: 'asst_${DateTime.now().millisecondsSinceEpoch}',
          role: MessageRole.assistant,
          content: 'Error: ${result.error}',
        ));
      });
    } else {
      var answer = result.response ?? 'No answer generated.';
      if (_ragSources.isNotEmpty) {
        answer += '\n\n---\n\n**Sources:**\n';
        for (final s in _ragSources) {
          answer += '- $s\n';
        }
      }
      setState(() {
        _messages.add(ChatMessage(
          id: 'asst_${DateTime.now().millisecondsSinceEpoch}',
          role: MessageRole.assistant,
          content: answer,
        ));
      });
    }
    _scrollToBottom();
    _saveMessages();
  }

  /// Pick files and upload them to the backend knowledge base (BM25 index).
  Future<void> _uploadFiles() async {
    if (_ragSearching || _isStreaming) return;

    FilePickerResult? picked;
    try {
      picked = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: const [
          'txt', 'md', 'markdown', 'text', 'pdf', 'docx', 'json', 'csv',
        ],
      );
    } catch (e) {
      _showSnack('File picker error: $e', isError: true);
      return;
    }
    if (picked == null || picked.files.isEmpty) return;

    final baseUrl = await _backendBaseUrl();
    if (baseUrl.isEmpty) {
      _showSnack('Backend URL not configured', isError: true);
      return;
    }

    _showSnack('Uploading ${picked.files.length} file(s)...');
    final resp = await _ragApiService.uploadFiles(
      baseUrl: baseUrl,
      files: picked.files,
    );
    if (!mounted) return;
    if (resp.containsKey('error')) {
      _showSnack('${resp['error']}', isError: true);
    } else {
      _showSnack(
        'Uploaded ${resp['files'] ?? 0} file(s) · '
        '${resp['chunks'] ?? 0} chunks indexed',
      );
    }
  }

  /// Clear the backend knowledge base (crawled pages + uploaded files).
  Future<void> _clearKnowledgeBase() async {
    if (_ragSearching || _isStreaming) return;

    final baseUrl = await _backendBaseUrl();
    if (!mounted) return;
    if (baseUrl.isEmpty) {
      _showSnack('Backend URL not configured', isError: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text('Clear knowledge base',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text(
          'Delete all crawled pages and uploaded documents from the backend?',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgent),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final resp = await _ragApiService.clearIndex(baseUrl);
    if (!mounted) return;
    if (resp.containsKey('error')) {
      _showSnack('${resp['error']}', isError: true);
    } else {
      _showSnack('Cleared ${resp['cleared'] ?? 0} file(s)');
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.urgent : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
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
                  itemCount: _messages.length +
                      (_isLoading ? 1 : 0) +
                      (_ragSearching ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _messages.length && _ragSearching) {
                      return WebSearchAnimation(
                        query: _ragQuery,
                        stage: _ragStage,
                        message: _ragStageMessage,
                        attempt: _ragAttempt,
                      );
                    }
                    if (index >= _messages.length) {
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
                _inputIconBtn(
                  Icons.attach_file_rounded,
                  _uploadFiles,
                  tooltip: 'Upload to knowledge base',
                  enabled: !_ragSearching && !_isStreaming,
                ),
                const SizedBox(width: 6),
                _inputIconBtn(
                  Icons.travel_explore,
                  _runWebSearch,
                  tooltip: 'Search the web',
                  enabled: !_ragSearching && !_isStreaming,
                ),
                const SizedBox(width: 6),
                _inputIconBtn(
                  Icons.delete_sweep_outlined,
                  _clearKnowledgeBase,
                  tooltip: 'Clear knowledge base',
                  enabled: !_ragSearching && !_isStreaming,
                ),
                const SizedBox(width: 6),
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

  Widget _inputIconBtn(
    IconData icon,
    VoidCallback onTap, {
    required String tooltip,
    required bool enabled,
  }) {
    final color = enabled ? AppColors.textSecondary : AppColors.textQuaternary;
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
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