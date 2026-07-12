import 'knowledge_node.dart';

class TreeProject {
  final String id;
  String name;
  final DateTime createdAt;
  List<KnowledgeNode> roots;

  TreeProject({
    required this.id,
    required this.name,
    DateTime? createdAt,
    List<KnowledgeNode>? roots,
  }) : createdAt = createdAt ?? DateTime.now(),
       roots = roots ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'roots': roots.map((r) => r.toJson()).toList(),
  };

  factory TreeProject.fromJson(Map<String, dynamic> json) => TreeProject(
    id: json['id'] as String,
    name: json['name'] as String? ?? 'Unnamed',
    createdAt: json['createdAt'] != null
        ? DateTime.parse(json['createdAt'] as String)
        : DateTime.now(),
    roots: (json['roots'] as List?)
        ?.map((e) => KnowledgeNode.fromJson(e as Map<String, dynamic>))
        .toList() ?? [],
  );
}
