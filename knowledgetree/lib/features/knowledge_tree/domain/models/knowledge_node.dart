import 'dart:convert';

class KnowledgeNode {
  final String id;
  String title;
  String summary;
  List<String> tags;
  List<KnowledgeNode> children;
  double? x;
  double? y;

  KnowledgeNode({
    required this.id,
    required this.title,
    this.summary = '',
    List<String>? tags,
    List<KnowledgeNode>? children,
    this.x,
    this.y,
  }) : tags = tags ?? [],
       children = children ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'summary': summary,
    'tags': tags,
    'x': x,
    'y': y,
    'children': children.map((c) => c.toJson()).toList(),
  };

  factory KnowledgeNode.fromJson(Map<String, dynamic> json) => KnowledgeNode(
    id: json['id'] as String,
    title: json['title'] as String? ?? '',
    summary: json['summary'] as String? ?? '',
    tags: (json['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
    x: (json['x'] as num?)?.toDouble(),
    y: (json['y'] as num?)?.toDouble(),
    children: (json['children'] as List?)?.map((e) => KnowledgeNode.fromJson(e as Map<String, dynamic>)).toList() ?? [],
  );

  KnowledgeNode copyWith({String? title, String? summary, List<String>? tags, List<KnowledgeNode>? children, double? x, double? y}) => KnowledgeNode(
    id: id,
    title: title ?? this.title,
    summary: summary ?? this.summary,
    tags: tags ?? this.tags,
    children: children ?? this.children,
    x: x ?? this.x,
    y: y ?? this.y,
  );

  @override
  String toString() => jsonEncode(toJson());
}