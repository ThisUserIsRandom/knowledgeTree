/// A user-supplied image attached to a [ChatNote].
///
/// Images are stored inline as base64 so notes stay fully self-contained
/// (they round-trip through chat storage and the consolidated export/import
/// JSON without any external file references).
class ChatAttachment {
  final String filename;
  final String mimeType;
  final String base64;

  const ChatAttachment({
    required this.filename,
    required this.mimeType,
    required this.base64,
  });

  /// `data:<mimeType>;base64,<payload>` URI, the form used in exports.
  String get dataUri => 'data:$mimeType;base64,$base64';

  Map<String, dynamic> toJson() => {
        'filename': filename,
        'mimeType': mimeType,
        'base64': base64,
      };

  factory ChatAttachment.fromJson(Map<String, dynamic> json) => ChatAttachment(
        filename: json['filename'] as String? ?? '',
        mimeType: json['mimeType'] as String? ?? 'image/png',
        base64: json['base64'] as String? ?? '',
      );

  /// Parses a `data:` URI produced by [dataUri]; returns null if malformed.
  static ChatAttachment? fromDataUri(String uri) {
    const prefix = 'data:';
    if (!uri.startsWith(prefix)) return null;
    final rest = uri.substring(prefix.length);
    final comma = rest.indexOf(',');
    if (comma <= 0) return null;
    final meta = rest.substring(0, comma);
    final payload = rest.substring(comma + 1);
    final parts = meta.split(';');
    final mimeType = parts.isNotEmpty ? parts.first : 'image/png';
    return ChatAttachment(
      filename: 'image_${DateTime.now().millisecondsSinceEpoch}.${_ext(mimeType)}',
      mimeType: mimeType,
      base64: base64UrlToBase64(payload),
    );
  }

  static String _ext(String mime) {
    final map = {
      'image/png': 'png',
      'image/jpeg': 'jpg',
      'image/gif': 'gif',
      'image/webp': 'webp',
      'image/bmp': 'bmp',
    };
    return map[mime] ?? 'png';
  }

  /// `base64UrlToBase64` handles both padded and unpadded base64url forms
  /// (data URIs sometimes omit padding).
  static String base64UrlToBase64(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    while (s.length % 4 != 0) {
      s += '=';
    }
    return s;
  }
}
