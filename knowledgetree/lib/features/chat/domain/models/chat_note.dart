import 'chat_attachment.dart';

/// A personal note a user attaches to an AI-generated message.
///
/// Notes are local-only: they are rendered and persisted on device but are
/// deliberately excluded from the request body sent to the backend, so the
/// LLM never sees them as conversation context.
class ChatNote {
  final String text;
  final List<ChatAttachment> images;

  const ChatNote({
    this.text = '',
    this.images = const [],
  });

  bool get isEmpty => text.trim().isEmpty && images.isEmpty;
  bool get hasImages => images.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'text': text,
        'images': images.map((a) => a.toJson()).toList(),
      };

  factory ChatNote.fromJson(Map<String, dynamic> json) {
    final rawImages = json['images'] as List? ?? [];
    return ChatNote(
      text: json['text'] as String? ?? '',
      images: rawImages
          .whereType<Map>()
          .map((m) => ChatAttachment.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
    );
  }

  ChatNote copyWith({String? text, List<ChatAttachment>? images}) => ChatNote(
        text: text ?? this.text,
        images: images ?? this.images,
      );
}
