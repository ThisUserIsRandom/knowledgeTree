import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../features/knowledge_tree/domain/models/tree_project.dart';
import '../features/knowledge_tree/domain/models/knowledge_node.dart';

class TreeStorage {
  static String? _baseDir;

  static Future<String> _getBaseDir() async {
    if (_baseDir != null) return _baseDir!;
    final appDir = await getApplicationDocumentsDirectory();
    _baseDir = '${appDir.path}/knowledge_tree';
    await Directory(_baseDir!).create(recursive: true);
    return _baseDir!;
  }

  static Future<List<TreeProject>> loadProjects() async {
    try {
      final base = await _getBaseDir();
      final file = File('$base/projects.json');
      if (!await file.exists()) {
        return _migrateOldFormat();
      }
      final raw = await file.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final list = (data['projects'] as List?) ?? [];
      return list.map((e) => TreeProject.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('TreeStorage.loadProjects error: $e');
      return [];
    }
  }

  static Future<List<TreeProject>> _migrateOldFormat() async {
    try {
      final base = await _getBaseDir();
      final oldFile = File('$base/nodes.json');
      if (!await oldFile.exists()) return [];
      final raw = await oldFile.readAsString();
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rawRoots = (data['roots'] as List?) ?? [];
      final roots = rawRoots
          .map((e) => KnowledgeNode.fromJson(e as Map<String, dynamic>))
          .toList();
      final project = TreeProject(
        id: 'proj_${DateTime.now().millisecondsSinceEpoch}',
        name: 'My Knowledge Tree',
        roots: roots,
      );
      await saveProjects([project]);
      await oldFile.delete();
      return [project];
    } catch (e) {
      debugPrint('TreeStorage._migrateOldFormat error: $e');
      return [];
    }
  }

  static Future<void> saveProjects(List<TreeProject> projects) async {
    try {
      final base = await _getBaseDir();
      await File('$base/projects.json').writeAsString(jsonEncode({
        'projects': projects.map((p) => p.toJson()).toList(),
      }));
    } catch (e) {
      debugPrint('TreeStorage.saveProjects error: $e');
    }
  }

}
