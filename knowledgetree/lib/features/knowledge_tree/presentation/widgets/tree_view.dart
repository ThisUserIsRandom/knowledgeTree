import 'package:flutter/material.dart';
import 'package:graphview/GraphView.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/providers/tree_project_provider.dart';
import '../../domain/models/knowledge_node.dart';

/// Wraps [BuchheimWalkerAlgorithm] so each node can be shifted by a manual
/// drag offset on top of the automatic tree layout. The overall tree shape is
/// unchanged; only individual nodes move relative to their computed spot.
///
/// The expensive tree layout is computed once and cached; subsequent runs
/// (every drag frame) just re-apply the cached base positions plus the current
/// manual offsets, which keeps dragging light.
class _DraggableBuchheimAlgorithm extends BuchheimWalkerAlgorithm {
  final Map<String, Offset> dragOffsets;

  final Map<String, Offset> _basePositions = {};
  Size _cachedSize = Size.zero;

  _DraggableBuchheimAlgorithm(
    this.dragOffsets,
    BuchheimWalkerConfiguration configuration,
    EdgeRenderer renderer,
  ) : super(configuration, renderer);

  @override
  Size run(Graph? graph, double shiftX, double shiftY) {
    if (graph == null) return Size.zero;

    final ids = graph.nodes.map((n) => n.key?.value).toList();
    final needsRecompute = _basePositions.isEmpty ||
        ids.length != _basePositions.length ||
        !ids.every((id) => _basePositions.containsKey(id));

    if (needsRecompute) {
      _cachedSize = super.run(graph, shiftX, shiftY);
      _basePositions.clear();
      for (final node in graph.nodes) {
        final id = node.key?.value as String?;
        if (id != null) _basePositions[id] = node.position;
      }
    }

    for (final node in graph.nodes) {
      final id = node.key?.value as String?;
      if (id == null) continue;
      final base = _basePositions[id] ?? node.position;
      final offset = dragOffsets[id];
      node.position =
          offset != null && offset != Offset.zero ? base + offset : base;
    }
    return _cachedSize;
  }
}

class TreeView extends StatefulWidget {
  final List<KnowledgeNode> roots;
  final void Function(String) onAddChild;
  final void Function(String) onDelete;
  final void Function(String) onDeleteChat;
  final void Function(String, String) onOpenChat;
  final void Function(String) onRename;
  final void Function(String, double, double) onUpdatePosition;
  final TreeProjectsNotifier notifier;
  final String projectId;

  const TreeView({
    super.key,
    required this.roots,
    required this.onAddChild,
    required this.onDelete,
    required this.onDeleteChat,
    required this.onOpenChat,
    required this.onRename,
    required this.onUpdatePosition,
    required this.notifier,
    required this.projectId,
  });

  @override
  State<TreeView> createState() => _TreeViewState();
}

class _TreeViewState extends State<TreeView> {
  // graphview owns layout + pan/zoom, so we don't manage positions manually.
  Graph _graph = Graph()..isTree = true;
  final BuchheimWalkerConfiguration _config = BuchheimWalkerConfiguration()
    ..siblingSeparation = 60
    ..levelSeparation = 130
    ..subtreeSeparation = 70
    ..orientation = BuchheimWalkerConfiguration.ORIENTATION_TOP_BOTTOM;
  final GraphViewController _controller = GraphViewController();
  final Map<String, Offset> _dragOffsets = {};
  late final BuchheimWalkerAlgorithm _algorithm;
  final Paint _edgePaint = Paint()
    ..color = AppColors.nodeEdgeColor
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  final Map<String, KnowledgeNode> _nodeMap = {};
  final Map<String, Node> _graphNodes = {};

  @override
  void initState() {
    super.initState();
    _algorithm = _DraggableBuchheimAlgorithm(
      _dragOffsets,
      _config,
      TreeEdgeRenderer(_config),
    );
    _rebuildGraph();
  }

  @override
  void didUpdateWidget(covariant TreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roots != widget.roots) {
      _rebuildGraph();
      // New graph object => new layout. Re-frame so the tree is visible
      // regardless of where the algorithm placed the root.
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.zoomToFit());
    }
  }

  void _rebuildGraph() {
    _nodeMap.clear();
    _graphNodes.clear();
    void collect(List<KnowledgeNode> ns) {
      for (final n in ns) {
        _nodeMap[n.id] = n;
        collect(n.children);
      }
    }
    collect(widget.roots);

    _graph = Graph()..isTree = true;
    for (final n in _nodeMap.values) {
      _graphNodes[n.id] = Node.Id(n.id);
    }
    // Edges add their endpoints; roots (no children) are added explicitly so
    // they are still rendered.
    for (final n in _nodeMap.values) {
      for (final c in n.children) {
        _graph.addEdge(_graphNodes[n.id]!, _graphNodes[c.id]!, paint: _edgePaint);
      }
    }
    for (final root in widget.roots) {
      if (!_graph.nodes.contains(_graphNodes[root.id])) {
        _graph.addNode(_graphNodes[root.id]!);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.roots.isEmpty) return const SizedBox.shrink();

    return Stack(
      children: [
        GraphView.builder(
          graph: _graph,
          algorithm: _algorithm,
          controller: _controller,
          animated: true,
          centerGraph: true,
          autoZoomToFit: true,
          builder: (Node node) {
            final id = node.key?.value as String?;
            final kn = id != null ? _nodeMap[id] : null;
            if (kn == null) return const SizedBox.shrink();
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanUpdate: (details) {
                _dragOffsets[kn.id] =
                    (_dragOffsets[kn.id] ?? Offset.zero) + details.delta;
                _controller.forceRecalculation();
              },
              child: _nodeCard(kn),
            );
          },
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FloatingActionButton.small(
                heroTag: 'fit',
                onPressed: () => _controller.zoomToFit(),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tooltip: 'Fit to screen',
                child: const Icon(Icons.fit_screen, size: 18),
              ),
              const SizedBox(height: 8),
              FloatingActionButton.small(
                heroTag: 'resetView',
                onPressed: () => _controller.resetView(),
                backgroundColor: AppColors.surfaceElevated,
                foregroundColor: AppColors.textPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                tooltip: 'Reset view',
                child: const Icon(Icons.zoom_out_map, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _nodeCard(KnowledgeNode node) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.nodeCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.nodeCardBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.nodeCardShadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => widget.onRename(node.id),
            child: Text(
              node.title,
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _actBtn(Icons.add, AppColors.primary, () => widget.onAddChild(node.id)),
              _actBtn(Icons.delete_outline, AppColors.urgent, () => widget.onDelete(node.id)),
              _actBtn(Icons.open_in_new, AppColors.ai, () => widget.onOpenChat(node.id, node.title)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actBtn(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }
}
