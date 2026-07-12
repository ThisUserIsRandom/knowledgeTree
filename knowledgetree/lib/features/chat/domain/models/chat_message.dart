enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, String> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  Map<String, String> toApiMap() => {
    'role': role.name == 'assistant' ? 'assistant' : 'user',
    'content': content,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as String? ?? '',
    role: MessageRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => MessageRole.user,
    ),
    content: json['content'] as String? ?? '',
    timestamp: json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'] as String) ?? DateTime.now()
        : DateTime.now(),
  );

  ChatMessage copyWith({String? content}) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    timestamp: timestamp,
  );
}
