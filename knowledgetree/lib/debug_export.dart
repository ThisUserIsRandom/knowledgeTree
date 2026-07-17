import 'package:flutter/material.dart';
import 'package:knowledgetree/services/tree_transfer.dart';
import 'package:knowledgetree/features/knowledge_tree/domain/models/tree_project.dart';

void main() {
  runApp(const _DebugExport());
}

class _DebugExport extends StatefulWidget {
  const _DebugExport();

  @override
  State<_DebugExport> createState() => _DebugExportState();
}

class _DebugExportState extends State<_DebugExport> {
  @override
  void initState() {
    super.initState();
    _run();
  }

  Future<void> _run() async {
    try {
      final project = TreeProject(
        id: 'p_test',
        name: 'Export Test Tree',
        createdAt: DateTime.now(),
        roots: [],
      );
      final path = await TreeTransfer.exportProject(project);
      debugPrint('EXPORT RESULT PATH: $path');
    } catch (e) {
      debugPrint('EXPORT ERROR: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('debug export'))),
    );
  }
}
