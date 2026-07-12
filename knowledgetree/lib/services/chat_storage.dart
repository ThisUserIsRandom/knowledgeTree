import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'content_sanitizer.dart';

class ChatStorage {
  static String? _baseDir;

  static Future<String> _getBaseDir() async {
    if (_baseDir != null) return _baseDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = '${appDir.path}/chat_messages';
    await Directory(_baseDir!).create(recursive: true);
    return _baseDir!;
  }

  static String _filePath(String nodeId, String baseDir) {
    final safe = base64Url.encode(utf8.encode(nodeId));
    return '$baseDir/$safe.json';
  }

  static Future<List<Map<String, String>>> load(String nodeId) async {
    try {
      final base = await _getBaseDir();
      final file = File(_filePath(nodeId, base));
      if (!await file.exists()) return [];
      final raw = await file.readAsString();
      final sanitized = ContentSanitizer.sanitize(raw);
      final repaired = ContentSanitizer.repairTruncatedJson(sanitized);
      final list = jsonDecode(repaired) as List;
      return list.map((e) {
        final m = e as Map<String, dynamic>;
        return {
          'role': ContentSanitizer.sanitize(m['role']?.toString() ?? ''),
          'content': ContentSanitizer.sanitize(m['content']?.toString() ?? ''),
        };
      }).toList();
    } catch (e) {
      debugPrint('ChatStorage.load error for $nodeId: $e');
      return [];
    }
  }

  static Future<void> save(String nodeId, List<Map<String, String>> messages) async {
    try {
      final base = await _getBaseDir();
      final safe = messages.map((m) => {
        'role': ContentSanitizer.sanitize(m['role'] ?? ''),
        'content': ContentSanitizer.sanitize(m['content'] ?? ''),
      }).toList();
      final json = jsonEncode(safe);
      await File(_filePath(nodeId, base)).writeAsString(json);
    } catch (e) {
      debugPrint('ChatStorage.save error for $nodeId: $e');
    }
  }

  static Future<void> delete(String nodeId) async {
    try {
      final base = await _getBaseDir();
      final file = File(_filePath(nodeId, base));
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('ChatStorage.delete error for $nodeId: $e');
    }
  }
}
