import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/connector/data/profile_provider.dart';
import 'package:knowledgetree/features/connector/domain/ai_profile.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({super.key});

  @override
  ConsumerState<ProfilesScreen> createState() => _ProfilesScreenState();
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  final _providers = ['OpenRouter', 'Ollama', 'Custom'];

  Future<void> _setActive(AiProfile p) async {
    await ref.read(profileProvider.notifier).setActive(p);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text('Active profile: ${p.name}')),
            ],
          ),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  Future<void> _delete(AiProfile p) async {
    await ref.read(profileProvider.notifier).deleteProfile(p);
  }

  void _showEditor({AiProfile? profile}) {
    final nameCtl = TextEditingController(text: profile?.name ?? '');
    final baseCtl = TextEditingController(text: profile?.baseUrl ?? '');
    final apiCtl = TextEditingController(text: profile?.apiUrl ?? '');
    final keyCtl = TextEditingController(text: profile?.apiKey ?? '');
    final modelCtl = TextEditingController(text: profile?.modelName ?? '');
    String provider = profile?.provider ?? 'OpenRouter';

    final isEditing = profile != null;
    bool keyVisible = false;

    void submit(StateSetter setSt) async {
      final name = nameCtl.text.trim();
      final p = AiProfile(
        id: profile?.id ?? AiProfile.newId(),
        name: name.isEmpty ? provider : name,
        provider: provider,
        baseUrl: baseCtl.text.trim(),
        apiUrl: apiCtl.text.trim(),
        apiKey: keyCtl.text.trim(),
        modelName: modelCtl.text.trim(),
      );
      await ref.read(profileProvider.notifier).saveProfile(p, makeActive: !isEditing);
      if (mounted) Navigator.of(context).pop();
    }

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Edit Profile' : 'Add Profile',
              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 19)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _field(nameCtl, 'Profile Name (e.g. My OpenRouter)'),
                const SizedBox(height: 14),
                Text('Provider', style: TextStyle(color: AppColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _providers.map((pr) {
                    final selected = pr == provider;
                    return ChoiceChip(
                      label: Text(pr),
                      selected: selected,
                      onSelected: (_) => setSt(() => provider = pr),
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      labelStyle: TextStyle(
                        color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: selected ? AppColors.primary : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),
                _field(baseCtl, 'Server URL (e.g. http://10.0.2.2:8000)'),
                const SizedBox(height: 14),
                _field(apiCtl, 'Provider API URL (optional, e.g. https://openrouter.ai/api/v1)'),
                const SizedBox(height: 14),
                StatefulBuilder(
                  builder: (c, setKey) => TextField(
                    controller: keyCtl,
                    obscureText: !keyVisible,
                    style: TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'API Key',
                      hintStyle: TextStyle(color: AppColors.textTertiary),
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: AppColors.border, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: AppColors.primary, width: 2),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: Icon(
                              keyVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: AppColors.textSecondary,
                              size: 20,
                            ),
                            tooltip: keyVisible ? 'Hide API Key' : 'Show API Key',
                            onPressed: () => setKey(() => keyVisible = !keyVisible),
                          ),
                          IconButton(
                            icon: Icon(Icons.copy_outlined, color: AppColors.textSecondary, size: 20),
                            tooltip: 'Copy API Key',
                            onPressed: () async {
                              if (keyCtl.text.trim().isEmpty) return;
                              await Clipboard.setData(ClipboardData(text: keyCtl.text.trim()));
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('API Key copied to clipboard'),
                                    backgroundColor: AppColors.success,
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _field(modelCtl, 'Model Name (e.g. tencent/hy3:free)'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
            ),
            FilledButton(
              onPressed: () => submit(setSt),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctl, String hint, {bool obscure = false}) {
    return TextField(
      controller: ctl,
      obscureText: obscure,
      style: TextStyle(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileProvider);
    final profiles = state.profiles;
    final activeId = state.activeId;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(Icons.arrow_back, color: AppColors.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: Text('Profiles',
            style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
      ),
      body: profiles.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 48, color: AppColors.textQuaternary),
                  const SizedBox(height: 12),
                  Text('No profiles yet', style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: profiles.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, i) {
                final p = profiles[i];
                final isActive = p.id == activeId;
                return Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceCard,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isActive ? AppColors.primary : AppColors.border,
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: isActive ? AppColors.cardShadow : null,
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: isActive ? AppColors.primaryGradient : null,
                        color: isActive ? null : AppColors.primaryContainer,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        isActive ? Icons.check_circle_rounded : Icons.person_outline,
                        color: isActive ? AppColors.textOnPrimary : AppColors.primary,
                        size: 23,
                      ),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(p.name,
                              style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.5)),
                        ),
                        if (isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.successContainer,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text('ACTIVE',
                                style: TextStyle(color: AppColors.successDark, fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                          ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.cloud_outlined, size: 13, color: AppColors.primary),
                            const SizedBox(width: 5),
                            Text(p.provider,
                                style: TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        if (p.modelName.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(p.modelName,
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 12.5)),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isActive)
                          TextButton(
                            onPressed: () => _setActive(p),
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            child: const Text('Use',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        IconButton(
                          icon: Icon(Icons.edit_outlined, color: AppColors.textSecondary, size: 20),
                          onPressed: () => _showEditor(profile: p),
                        ),
                        IconButton(
                          icon: Icon(Icons.delete_outline, color: AppColors.urgent, size: 20),
                          onPressed: () => _confirmDelete(p),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showEditor(),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Add Profile'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  void _confirmDelete(AiProfile p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Delete profile?', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: Text('Remove "${p.name}"? This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _delete(p);
            },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.urgent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
