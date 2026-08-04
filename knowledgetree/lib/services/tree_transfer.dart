import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../features/knowledge_tree/domain/models/tree_project.dart';
import '../features/knowledge_tree/domain/models/knowledge_node.dart';
import 'chat_storage.dart';

/// Exports/imports a single [TreeProject] as a `.json` file.
///
/// * Export always lands in the user's **Downloads** folder:
///   - Desktop (Linux/macOS/Windows): written directly via `path_provider`'s
///     downloads directory (e.g. `~/Downloads`).
///   - Android: written into public Downloads through a small MediaStore
///     platform channel (see `MainActivity.kt`), which works with scoped
///     storage and needs no runtime permission on Android 10+.
/// * Import uses a native file picker via `file_picker` (AGP 9 compatible
///   prerelease `12.0.0-beta.7`).
class TreeTransfer {
  /// Current export schema version. Bumped when the payload shape changes so
  /// [importFromJson] can migrate older files.
  /// Version 2 added per-node chat history under each node's `chat` field.
  /// Version 3 added an optional per-message `note` ({text, images[]}) object
  /// for personal notes attached to AI answers. Version 2 files still import.
  static const int formatVersion = 3;

  static const MethodChannel _downloads =
      MethodChannel('knowledgetree/downloads');

  /// Serializes a project (including every node's chat history) into a
  /// pretty-printed, versioned JSON string.
  static Future<String> exportToJsonString(TreeProject project) async {
    final rootsJson = <Map<String, dynamic>>[];
    for (final root in project.roots) {
      rootsJson.add(await _nodeToExportJson(root));
    }
    final projectJson = {
      'id': project.id,
      'name': project.name,
      'createdAt': project.createdAt.toIso8601String(),
      'roots': rootsJson,
    };
    final payload = {
      'format': 'knowledgetree.tree',
      'version': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'project': projectJson,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  /// Recursively serializes a node together with its stored chat history.
  static Future<Map<String, dynamic>> _nodeToExportJson(KnowledgeNode node) async {
    final childrenJson = <Map<String, dynamic>>[];
    for (final child in node.children) {
      childrenJson.add(await _nodeToExportJson(child));
    }
    final chat = await ChatStorage.load(node.id);
    return {
      'id': node.id,
      'title': node.title,
      'summary': node.summary,
      'tags': node.tags,
      'x': node.x,
      'y': node.y,
      'chat': chat,
      'children': childrenJson,
    };
  }

  /// Writes [project] to a single `<TreeName>.json` file in Downloads and
  /// returns the path (or Downloads-relative location on Android).
  static Future<String> exportProject(TreeProject project) async {
    final jsonStr = await exportToJsonString(project);
    final fileName = '${_sanitizeFileName(project.name)}.json';

    if (!kIsWeb && Platform.isAndroid) {
      final saved = await _downloads.invokeMethod<String>('saveToDownloads', {
        'fileName': fileName,
        'content': jsonStr,
      });
      return saved ?? 'Downloads/$fileName';
    }

    // Desktop: write straight into the Downloads folder.
    Directory? dir = await getDownloadsDirectory();
    dir ??= await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(jsonStr, flush: true);
    return file.path;
  }

  /// Opens a native file picker so the user can choose a `.json` tree file from
  /// local storage. Returns the parsed project, or null if the user cancelled.
  static Future<TreeProject?> importProject() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (result == null || result.files.single.path == null) return null;
    return await importFromJson(
        await File(result.files.single.path!).readAsString());
  }

  /// Parses a JSON string (either a full export payload or a bare project
  /// object) into a [TreeProject]. When [regenerateIds] is true, fresh ids are
  /// assigned so the imported tree never collides with existing projects, and
  /// each node's embedded `chat` history is restored into [ChatStorage].
  static Future<TreeProject> importFromJson(String jsonStr,
      {bool regenerateIds = true}) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid tree file: expected a JSON object.');
    }

    Map<String, dynamic> projectJson;
    if (decoded.containsKey('project')) {
      final p = decoded['project'];
      if (p is! Map<String, dynamic>) {
        throw const FormatException('Invalid tree file: malformed "project".');
      }
      projectJson = p;
    } else if (decoded.containsKey('roots')) {
      // Bare project object.
      projectJson = decoded;
    } else {
      throw const FormatException('Invalid tree file: no project data found.');
    }

    final chatsToSave = <String, List<Map<String, dynamic>>>{};
    final roots = _buildNodes(
      (projectJson['roots'] as List?) ?? [],
      regenerateIds,
      chatsToSave,
    );

    // Persist each node's restored chat history under its (possibly new) id.
    for (final entry in chatsToSave.entries) {
      await ChatStorage.save(entry.key, entry.value);
    }

    final projectId = regenerateIds
        ? 'proj_${DateTime.now().millisecondsSinceEpoch}'
        : (projectJson['id'] as String? ??
            'proj_${DateTime.now().millisecondsSinceEpoch}');
    final createdAt = projectJson['createdAt'] != null
        ? DateTime.parse(projectJson['createdAt'] as String)
        : DateTime.now();

    return TreeProject(
      id: projectId,
      name: (projectJson['name'] as String?) ?? 'Unnamed',
      createdAt: createdAt,
      roots: roots,
    );
  }

  /// Recursively builds nodes, assigning fresh ids (when [regenerateIds]) and
  /// collecting each node's chat history keyed by its final id.
  static List<KnowledgeNode> _buildNodes(
    List<dynamic> nodesJson,
    bool regenerateIds,
    Map<String, List<Map<String, dynamic>>> chatsToSave,
  ) {
    return nodesJson.map((e) {
      final m = e as Map<String, dynamic>;
      final id = regenerateIds
          ? 'n_${DateTime.now().microsecondsSinceEpoch}_${_counter++}'
          : (m['id'] as String? ?? 'n_${_counter++}');

      final rawChat = m['chat'] as List?;
      final chat = rawChat
              ?.map((c) {
                final cm = c as Map<String, dynamic>;
                return {
                  'role': (cm['role'] as String?) ?? '',
                  'content': (cm['content'] as String?) ?? '',
                  if (cm['note'] is Map) 'note': cm['note'],
                };
              })
              .toList() ??
          <Map<String, dynamic>>[];
      chatsToSave[id] = chat;

      final children = _buildNodes(
        (m['children'] as List?) ?? [],
        regenerateIds,
        chatsToSave,
      );

      return KnowledgeNode(
        id: id,
        title: (m['title'] as String?) ?? '',
        summary: (m['summary'] as String?) ?? '',
        tags: (m['tags'] as List?)?.map((t) => t.toString()).toList() ?? [],
        x: (m['x'] as num?)?.toDouble(),
        y: (m['y'] as num?)?.toDouble(),
        children: children,
      );
    }).toList();
  }

  static int _counter = 0;

  static String _sanitizeFileName(String name) {
    final cleaned = name.replaceAll(RegExp(r'[^a-zA-Z0-9_\- ]'), '').trim();
    return cleaned.isEmpty ? 'tree' : cleaned.replaceAll(' ', '_');
  }
}
