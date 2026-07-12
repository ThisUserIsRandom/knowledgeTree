import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import '../features/knowledge_tree/domain/models/tree_project.dart';
import '../features/knowledge_tree/domain/models/knowledge_node.dart';
import '../services/tree_storage.dart';

class TreeProjectsNotifier extends Notifier<List<TreeProject>> {
  @override
  List<TreeProject> build() {
    _load();
    return [];
  }

  void _load() async {
    final projects = await TreeStorage.loadProjects();
    if (projects.isNotEmpty) {
      state = projects;
    } else {
      state = [
        TreeProject(
          id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
          name: 'My Knowledge Tree',
          roots: _defaultNodes(),
        ),
      ];
    }
  }

  List<KnowledgeNode> _defaultNodes() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return [
      KnowledgeNode(
        id: 'n_$now',
        title: 'Flutter',
        summary: 'Cross-platform UI framework',
        tags: ['mobile', 'web', 'desktop'],
        children: [
          KnowledgeNode(
            id: 'n_${now + 1}',
            title: 'Widgets',
            summary: 'Core building blocks',
            children: [
              KnowledgeNode(id: 'n_${now + 2}', title: 'StatelessWidget'),
              KnowledgeNode(id: 'n_${now + 3}', title: 'StatefulWidget'),
            ],
          ),
          KnowledgeNode(id: 'n_${now + 4}', title: 'State Management'),
        ],
      ),
    ];
  }

  @override
  set state(List<TreeProject> newState) {
    super.state = newState;
    _persist();
  }

  Future<void> _persist() async {
    await TreeStorage.saveProjects(state);
  }

  void createProject(String name) {
    state = [
      ...state,
      TreeProject(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
      ),
    ];
  }

  void deleteProject(String projectId) {
    state = state.where((p) => p.id != projectId).toList();
  }

  void renameProject(String projectId, String newName) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: newName,
          createdAt: p.createdAt,
          roots: p.roots,
        );
      }
      return p;
    }).toList();
  }

  void addNode(String projectId, String parentId, {String title = 'New Node'}) {
    final newNode = KnowledgeNode(
      id: 'n_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
    );
    state = state.map((p) {
      if (p.id == projectId) {
        // Root nodes are positioned in a row so they don't all stack at (0,0)
        // and become unclickable/draggable.
        if (parentId == 'root') {
          final placed = KnowledgeNode(
            id: newNode.id,
            title: newNode.title,
            summary: newNode.summary,
            tags: List.from(newNode.tags),
            x: 40.0 + p.roots.length * 260.0,
            y: 40.0,
          );
          return TreeProject(
            id: p.id,
            name: p.name,
            createdAt: p.createdAt,
            roots: [...p.roots, placed],
          );
        }
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _addChild(p.roots, parentId, newNode),
        );
      }
      return p;
    }).toList();
  }

  List<KnowledgeNode> _addChild(
      List<KnowledgeNode> nodes, String parentId, KnowledgeNode child) {
    return nodes.map((n) {
      if (n.id == parentId) {
        final px = n.x ?? 0.0;
        final py = n.y ?? 0.0;
        // Fan children out so siblings never stack on the exact same spot
        // (stacked nodes overlap and only the topmost stays interactable).
        final c = n.children.length;
        final placedChild = KnowledgeNode(
          id: child.id,
          title: child.title,
          summary: child.summary,
          tags: List.from(child.tags),
          x: px + 300 + (c % 3) * 40,
          y: py + 120 + (c ~/ 3) * 110,
        );
        return KnowledgeNode(
          id: n.id,
          title: n.title,
          summary: n.summary,
          tags: List.from(n.tags),
          x: n.x,
          y: n.y,
          children: [...n.children, placedChild],
        );
      }
      return KnowledgeNode(
        id: n.id,
        title: n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        x: n.x,
        y: n.y,
        children: _addChild(n.children, parentId, child),
      );
    }).toList();
  }

  void deleteNode(String projectId, String nodeId) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _deleteNode(p.roots, nodeId),
        );
      }
      return p;
    }).toList();
  }

  List<KnowledgeNode> _deleteNode(List<KnowledgeNode> nodes, String nodeId) {
    return nodes
        .where((n) => n.id != nodeId)
        .map((n) => KnowledgeNode(
              id: n.id,
              title: n.title,
              summary: n.summary,
              tags: List.from(n.tags),
              children: _deleteNode(n.children, nodeId),
            ))
        .toList();
  }

  void renameNode(String projectId, String nodeId, String newTitle) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _renameNode(p.roots, nodeId, newTitle),
        );
      }
      return p;
    }).toList();
  }

  void updateNodePosition(String projectId, String nodeId, double x, double y) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _updateNodePosition(p.roots, nodeId, x, y),
        );
      }
      return p;
    }).toList();
  }

  void moveNodeByDelta(String projectId, String nodeId, {required double deltaX, required double deltaY}) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _moveNodeByDelta(p.roots, nodeId, deltaX, deltaY),
        );
      }
      return p;
    }).toList();
  }

  List<KnowledgeNode> _moveNodeByDelta(
      List<KnowledgeNode> nodes, String nodeId, double deltaX, double deltaY) {
    return nodes.map((n) {
      if (n.id == nodeId) {
        return KnowledgeNode(
          id: n.id,
          title: n.title,
          summary: n.summary,
          tags: List.from(n.tags),
          x: (n.x ?? 0) + deltaX,
          y: (n.y ?? 0) + deltaY,
          children: List.from(n.children),
        );
      }
      return KnowledgeNode(
        id: n.id,
        title: n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        x: n.x,
        y: n.y,
        children: _moveNodeByDelta(n.children, nodeId, deltaX, deltaY),
      );
    }).toList();
  }

  List<KnowledgeNode> _updateNodePosition(
      List<KnowledgeNode> nodes, String nodeId, double x, double y) {
    return nodes.map((n) {
      if (n.id == nodeId) {
        return KnowledgeNode(
          id: n.id,
          title: n.title,
          summary: n.summary,
          tags: List.from(n.tags),
          x: x,
          y: y,
          children: List.from(n.children),
        );
      }
      return KnowledgeNode(
        id: n.id,
        title: n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        x: n.x,
        y: n.y,
        children: _updateNodePosition(n.children, nodeId, x, y),
      );
    }).toList();
  }

  void moveNode(String projectId, String sourceId, String targetId) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _moveNode(p.roots, sourceId, targetId),
        );
      }
      return p;
    }).toList();
  }

  List<KnowledgeNode> _moveNode(
      List<KnowledgeNode> nodes, String sourceId, String targetId) {
    KnowledgeNode? sourceNode;
    final nodesWithoutSource = nodes.map((n) {
      if (n.id == sourceId) {
        sourceNode = n;
        return null;
      }
      return KnowledgeNode(
        id: n.id,
        title: n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        x: n.x,
        y: n.y,
        children: _moveNode(n.children, sourceId, targetId),
      );
    }).whereType<KnowledgeNode>().toList();

    if (sourceNode == null) return nodes;

    return nodesWithoutSource.map((n) {
      if (n.id == targetId) {
        return KnowledgeNode(
          id: n.id,
          title: n.title,
          summary: n.summary,
          tags: List.from(n.tags),
          x: n.x,
          y: n.y,
          children: [...n.children, sourceNode!],
        );
      }
      return KnowledgeNode(
        id: n.id,
        title: n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        x: n.x,
        y: n.y,
        children: _moveNode(n.children, sourceId, targetId),
      );
    }).toList();
  }

void applyAutoLayout(String projectId, Map<String, Offset> positions) {
    state = state.map((p) {
      if (p.id == projectId) {
        return TreeProject(
          id: p.id,
          name: p.name,
          createdAt: p.createdAt,
          roots: _applyPositions(p.roots, positions),
        );
      }
      return p;
    }).toList();
  }

  List<KnowledgeNode> _applyPositions(List<KnowledgeNode> nodes, Map<String, Offset> positions) {
    return nodes.map((n) {
      final positioned = positions[n.id];
      return KnowledgeNode(
        id: n.id,
        title: n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        x: positioned?.dx,
        y: positioned?.dy,
        children: _applyPositions(n.children, positions),
      );
    }).toList();
  }

  List<KnowledgeNode> _renameNode(
      List<KnowledgeNode> nodes, String nodeId, String newTitle) {
    return nodes.map((n) {
      return KnowledgeNode(
        id: n.id,
        title: n.id == nodeId ? newTitle : n.title,
        summary: n.summary,
        tags: List.from(n.tags),
        children: _renameNode(n.children, nodeId, newTitle),
      );
    }).toList();
  }
}

final treeProjectsProvider =
    NotifierProvider<TreeProjectsNotifier, List<TreeProject>>(
  TreeProjectsNotifier.new,
);

final activeProjectIdProvider = StateProvider<String?>((ref) => null);

final activeProjectProvider = Provider<TreeProject?>((ref) {
  final projects = ref.watch(treeProjectsProvider);
  final activeId = ref.watch(activeProjectIdProvider);
  if (activeId == null) return null;
  try {
    return projects.firstWhere((p) => p.id == activeId);
  } catch (_) {
    return null;
  }
});
