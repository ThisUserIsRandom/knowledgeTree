import 'chat_note.dart';

enum MessageRole { user, assistant, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime timestamp;

  /// Optional personal note attached to this message. Deliberately excluded
  /// from [toApiMap] so notes stay local and are never sent to the backend.
  final ChatNote? note;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    DateTime? timestamp,
    this.note,
  }) : timestamp = timestamp ?? DateTime.now();

  bool get hasNote => note != null && !note!.isEmpty;

  Map<String, String> toJson() => {
    'id': id,
    'role': role.name,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
  };

  /// Wire format for the backend. Notes are intentionally omitted.
  Map<String, String> toApiMap() => {
    'role': role.name == 'assistant' ? 'assistant' : 'user',
    'content': content,
  };

  /// Persistence/export format. Includes `note` so it survives storage and
  /// import/export round-trips.
  Map<String, dynamic> toStoreMap() => {
    'role': role.name == 'assistant' ? 'assistant' : 'user',
    'content': content,
    if (hasNote) 'note': note!.toJson(),
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
    note: json['note'] is Map
        ? ChatNote.fromJson(Map<String, dynamic>.from(json['note'] as Map))
        : null,
  );

  ChatMessage copyWith({String? content, ChatNote? note}) => ChatMessage(
    id: id,
    role: role,
    content: content ?? this.content,
    timestamp: timestamp,
    note: note ?? this.note,
  );
}
