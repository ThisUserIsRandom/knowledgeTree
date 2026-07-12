import 'dart:convert';

class ContentSanitizer {
  static String sanitize(String input) {
    if (input.isEmpty) return input;
    final buf = StringBuffer();
    final iter = RuneIterator(input);
    while (iter.moveNext()) {
      final cp = iter.current;
      if (_isAllowedCodepoint(cp)) {
        buf.writeCharCode(cp);
      }
    }
    return buf.toString();
  }

  static bool _isAllowedCodepoint(int cp) {
    if (cp == 0x09 || cp == 0x0A || cp == 0x0D) return true;
    if (cp < 0x20) return false;
    if (cp >= 0xD800 && cp <= 0xDFFF) return false;
    if (cp == 0xFEFF) return false;
    return true;
  }

  static String sseDataContent(String raw) {
    var result = raw.trim();
    if (result.startsWith('data: ')) result = result.substring(6);
    return sanitize(result);
  }

  static String repairTruncatedJson(String input) {
    if (input.isEmpty) return input;
    var fixed = input.trim();
    int openBraces = 0;
    int openBrackets = 0;
    bool inString = false;
    bool escaped = false;

    for (int i = 0; i < fixed.length; i++) {
      final ch = fixed[i];
      if (escaped) { escaped = false; continue; }
      if (ch == '\\' && inString) { escaped = true; continue; }
      if (ch == '"') { inString = !inString; continue; }
      if (inString) continue;
      if (ch == '{') openBraces++;
      if (ch == '}') openBraces--;
      if (ch == '[') openBrackets++;
      if (ch == ']') openBrackets--;
    }

    while (openBraces > 0) { fixed += '}'; openBraces--; }
    while (openBrackets > 0) { fixed += ']'; openBrackets--; }
    if (inString) fixed += '"';

    return fixed;
  }

  static String safeEncodeJson(Map<String, dynamic> input) {
    try {
      return jsonEncode(input);
    } catch (e) {
      final safe = _sanitizeMap(input);
      return jsonEncode(safe);
    }
  }

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> input) {
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      result[sanitize(key)] = _sanitizeValue(value);
    });
    return result;
  }

  static dynamic _sanitizeValue(dynamic value) {
    if (value is String) return sanitize(value);
    if (value is Map<String, dynamic>) return _sanitizeMap(value);
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }
}
