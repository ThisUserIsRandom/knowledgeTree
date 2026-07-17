import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/providers/tree_project_provider.dart';
import 'package:knowledgetree/services/tree_transfer.dart';
import 'package:knowledgetree/features/knowledge_tree/domain/models/tree_project.dart';
import 'package:knowledgetree/features/knowledge_tree/domain/models/knowledge_node.dart';
import 'package:knowledgetree/features/knowledge_tree/presentation/screens/knowledge_tree_screen.dart';
import 'package:knowledgetree/features/connector/presentation/screens/connector_screen.dart';
import 'package:knowledgetree/features/connector/presentation/screens/profiles_screen.dart';

class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(treeProjectsProvider);
    final notifier = ref.read(treeProjectsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, ref),
            Expanded(
              child: projects.isEmpty
                  ? _buildEmptyState(context, notifier)
                  : _buildProjectList(context, ref, projects, notifier),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.account_tree, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Knowledge Tree AI',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      )),
              Text('Your knowledge base',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      )),
            ],
          ),
          const Spacer(),
          _iconButton(Icons.file_download_outlined, AppColors.textSecondary, () {
            _showImportDialog(context, ref.read(treeProjectsProvider.notifier));
          }),
          _iconButton(Icons.swap_horiz_rounded, AppColors.textSecondary, () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilesScreen()),
            );
          }),
          _iconButton(Icons.settings_outlined, AppColors.textSecondary, () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConnectorScreen()),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, TreeProjectsNotifier notifier) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primaryContainer,
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(Icons.account_tree_outlined, color: AppColors.primary, size: 40),
          ),
          const SizedBox(height: 20),
          Text('No knowledge trees yet',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  )),
          const SizedBox(height: 8),
          Text('Create one to get started',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textTertiary,
                  )),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _showCreateDialog(context, notifier),
            icon: const Icon(Icons.add, size: 20),
            label: const Text('Create Tree'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectList(BuildContext context, WidgetRef ref,
      List<TreeProject> projects, TreeProjectsNotifier notifier) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text('Your Trees',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      )),
              const Spacer(),
              Text('${projects.length} total',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textQuaternary,
                      )),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: projects.length + 1,
            itemBuilder: (context, index) {
              if (index == projects.length) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: OutlinedButton.icon(
                    onPressed: () => _showCreateDialog(context, notifier),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create New Tree'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.border, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                );
              }
              return _buildProjectCard(context, ref, projects[index], notifier);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(BuildContext context, WidgetRef ref,
      TreeProject project, TreeProjectsNotifier notifier) {
    final nodeCount = _countNodes(project.roots);
    final dateStr =
        '${project.createdAt.day}/${project.createdAt.month}/${project.createdAt.year}';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GestureDetector(
        onTap: () {
          ref.read(activeProjectIdProvider.notifier).state = project.id;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => KnowledgeTreeScreen(
                projectId: project.id,
                projectName: project.name,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surfaceCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.account_tree, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(project.name,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            )),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text('$nodeCount node${nodeCount == 1 ? '' : 's'}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textTertiary,
                                )),
                        const SizedBox(width: 12),
                        Text('Created $dateStr',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.textQuaternary,
                                )),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: AppColors.textTertiary, size: 20),
                color: AppColors.surfaceCard,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                onSelected: (value) {
                  if (value == 'rename') {
                    _showRenameDialog(context, notifier, project);
                  } else if (value == 'export') {
                    _exportProject(context, project);
                  } else if (value == 'delete') {
                    _showDeleteDialog(context, notifier, project);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'rename',
                    child: Text('Rename',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ),
                  PopupMenuItem(
                    value: 'export',
                    child: Text('Export',
                        style: TextStyle(color: AppColors.textPrimary, fontSize: 14)),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete',
                        style: TextStyle(color: AppColors.urgent, fontSize: 14)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _countNodes(List<KnowledgeNode> nodes) {
    int count = nodes.length;
    for (final n in nodes) {
      count += _countNodes(n.children);
    }
    return count;
  }

  void _showCreateDialog(BuildContext context, TreeProjectsNotifier notifier) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text('New Knowledge Tree',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tree name',
            hintStyle: TextStyle(color: AppColors.textTertiary),
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (_) {
            notifier.createProject(
                controller.text.trim().isEmpty ? 'New Tree' : controller.text.trim());
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () {
              notifier.createProject(
                  controller.text.trim().isEmpty ? 'New Tree' : controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showRenameDialog(BuildContext context, TreeProjectsNotifier notifier,
      TreeProject project) {
    final controller = TextEditingController(text: project.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text('Rename Tree',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(color: AppColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
          onSubmitted: (v) {
            notifier.renameProject(project.id, v.trim());
            Navigator.of(ctx).pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () {
              notifier.renameProject(project.id, controller.text.trim());
              Navigator.of(ctx).pop();
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, TreeProjectsNotifier notifier,
      TreeProject project) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text('Delete Tree',
            style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Delete "${project.name}" and all its nodes?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textTertiary)),
          ),
          FilledButton(
            onPressed: () {
              notifier.deleteProject(project.id);
              Navigator.of(ctx).pop();
            },
            style: FilledButton.styleFrom(backgroundColor: AppColors.urgent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportProject(BuildContext context, TreeProject project) async {
    try {
      final path = await TreeTransfer.exportProject(project);
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: AppColors.border, width: 1),
          ),
          title: Text('Tree Exported',
              style: TextStyle(
                  color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Saved "${project.name}" as a single JSON file at:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(height: 10),
              SelectableText(path,
                  style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      height: 1.4)),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _showImportDialog(
      BuildContext context, TreeProjectsNotifier notifier) async {
    try {
      final project = await TreeTransfer.importProject();
      if (!context.mounted) return;
      if (project == null) return; // user cancelled
      notifier.importProject(project);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported "${project.name}"')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  Widget _iconButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }
}
