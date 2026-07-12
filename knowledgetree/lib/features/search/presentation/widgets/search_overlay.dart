import 'package:flutter/material.dart';
import 'package:knowledgetree/features/knowledge_tree/domain/models/knowledge_node.dart';

class SearchOverlay extends StatefulWidget {
  final List<KnowledgeNode> roots;
  final void Function(KnowledgeNode) onSelect;

  const SearchOverlay({super.key, required this.roots, required this.onSelect});

  @override
  State<SearchOverlay> createState() => _SearchOverlayState();
}

class _SearchOverlayState extends State<SearchOverlay> {
  final _controller = TextEditingController();
  List<KnowledgeNode> _results = [];

  void _search(String query) {
    if (query.isEmpty) {
      setState(() => _results = []);
      return;
    }
    final q = query.toLowerCase();
    final hits = <KnowledgeNode>[];
    void walk(List<KnowledgeNode> nodes) {
      for (final n in nodes) {
        if (n.title.toLowerCase().contains(q) ||
            n.summary.toLowerCase().contains(q) ||
            n.tags.any((t) => t.toLowerCase().contains(q))) {
          hits.add(n);
        }
        walk(n.children);
      }
    }
    walk(widget.roots);
    setState(() => _results = hits);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black54,
      child: Column(
        children: [
          const SizedBox(height: 60),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _controller,
              autofocus: true,
              onChanged: _search,
              style: const TextStyle(color: Color(0xFFF0F0F0), fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Search nodes...',
                hintStyle: const TextStyle(color: Color(0xFF606070)),
                prefixIcon: const Icon(Icons.search, color: Color(0xFF606070)),
                filled: true,
                fillColor: const Color(0xFF1A1A2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final node = _results[index];
                return ListTile(
                  leading: Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(color: Color(0xFF00D4FF), shape: BoxShape.circle),
                  ),
                  title: Text(node.title, style: const TextStyle(color: Color(0xFFF0F0F0))),
                  subtitle: node.summary.isNotEmpty
                      ? Text(node.summary, style: const TextStyle(color: Color(0xFFA0A0B0), fontSize: 12))
                      : null,
                  onTap: () => widget.onSelect(node),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
