import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/knowledge_tree/domain/models/knowledge_node.dart';
import 'package:knowledgetree/services/chat_storage.dart';
import 'package:knowledgetree/features/chat/presentation/screens/chat_panel.dart';
import 'package:knowledgetree/features/knowledge_tree/presentation/widgets/tree_view.dart';
import 'package:knowledgetree/providers/tree_project_provider.dart';
import 'package:knowledgetree/providers/backend_status_provider.dart';
import 'package:knowledgetree/features/connector/presentation/screens/connector_screen.dart';

class KnowledgeTreeScreen extends ConsumerStatefulWidget {
  final String projectId;
  final String projectName;

  const KnowledgeTreeScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  ConsumerState<KnowledgeTreeScreen> createState() => _KnowledgeTreeScreenState();
}

class _KnowledgeTreeScreenState extends ConsumerState<KnowledgeTreeScreen> {
  String? _chatNodeId;
  String? _chatNodeTitle;

  void _openChat(String id, String title) {
    setState(() {
      _chatNodeId = id;
      _chatNodeTitle = title;
    });
  }

  void _closeChat() {
    setState(() {
      _chatNodeId = null;
      _chatNodeTitle = null;
    });
  }

  Future<void> _promptAddNode(String parentId) async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text('Add Node',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Node name',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref
          .read(treeProjectsProvider.notifier)
          .addNode(widget.projectId, parentId, title: name);
    }
  }

  Future<void> _promptRename(String nodeId) async {
    final project = ref.read(activeProjectProvider);
    final node = _findNode(project?.roots ?? [], nodeId);
    final ctrl = TextEditingController(text: node?.title ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text('Rename Node',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'New name',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Rename'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      ref
          .read(treeProjectsProvider.notifier)
          .renameNode(widget.projectId, nodeId, name);
    }
  }

  KnowledgeNode? _findNode(List<KnowledgeNode> nodes, String id) {
    for (final n in nodes) {
      if (n.id == id) return n;
      final found = _findNode(n.children, id);
      if (found != null) return found;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final project = ref.watch(activeProjectProvider);
    final roots = project?.roots ?? [];

    return Scaffold(
      backgroundColor: AppColors.treeBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(roots),
            Expanded(child: _buildBody(roots)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(List<KnowledgeNode> roots) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 22),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 4),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.account_tree, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.projectName,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${roots.length} root${roots.length == 1 ? '' : 's'}',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 12),
                ),
              ],
            ),
          ),
          _backendStatus(),
          _iconButton(Icons.settings_rounded, AppColors.textSecondary, () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectorScreen()),
            ).then((_) => ref.read(backendStatusProvider.notifier).refresh());
          }),
        ],
      ),
    );
  }

  Widget _buildBody(List<KnowledgeNode> roots) {
    if (roots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.account_tree_outlined, color: AppColors.textQuaternary, size: 64),
            const SizedBox(height: 16),
            Text('This tree is empty',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 16)),
            const SizedBox(height: 8),
            Text('Start building your knowledge tree',
                style: TextStyle(color: AppColors.textQuaternary, fontSize: 14)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _promptAddNode('root'),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Root Node'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        TreeView(
          roots: roots,
          onAddChild: _promptAddNode,
          onDelete: (nodeId) => ref
              .read(treeProjectsProvider.notifier)
              .deleteNode(widget.projectId, nodeId),
          onDeleteChat: (nodeId) => ChatStorage.delete(nodeId),
          onOpenChat: _openChat,
          onRename: _promptRename,
          onUpdatePosition: (nodeId, deltaX, deltaY) => ref
              .read(treeProjectsProvider.notifier)
              .moveNodeByDelta(widget.projectId, nodeId, deltaX: deltaX, deltaY: deltaY),
          notifier: ref.read(treeProjectsProvider.notifier),
          projectId: widget.projectId,
        ),
        if (_chatNodeId != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: buildChatSheet(
              context,
              _chatNodeId!,
              _chatNodeTitle ?? '',
              _closeChat,
            ),
          ),
      ],
    );
  }

  Widget _backendStatus() {
    final status = ref.watch(backendStatusProvider);
    Color color;
    String label;
    if (status == BackendStatus.connected) {
      color = AppColors.success;
      label = 'Connected';
    } else if (status == BackendStatus.disconnected) {
      color = AppColors.urgent;
      label = 'Disconnected';
    } else {
      color = AppColors.warning;
      label = 'Connecting...';
    }
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: 'Backend: $label',
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}