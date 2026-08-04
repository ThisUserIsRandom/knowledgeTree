import 'package:flutter/material.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_message.dart';
import 'note_view.dart';

/// Aggregated view of every message in the node's chat that carries a note.
/// Each entry shows a short preview of the AI answer plus the full note.
class ChatNotesView extends StatelessWidget {
  final List<ChatMessage> messages;
  final ValueChanged<ChatMessage> onEdit;

  const ChatNotesView({super.key, required this.messages, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final withNotes = messages.where((m) => m.hasNote).toList();
    if (withNotes.isEmpty) {
      return _empty();
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: withNotes.length,
      itemBuilder: (context, i) {
        final m = withNotes[i];
        return _card(m);
      },
    );
  }

  Widget _empty() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sticky_note_2_outlined, color: AppColors.textQuaternary, size: 56),
            const SizedBox(height: 12),
            Text('No notes yet',
                style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
            const SizedBox(height: 6),
            Text('Add a note to any AI answer to see it here',
                style: TextStyle(color: AppColors.textQuaternary, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _card(ChatMessage m) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, color: AppColors.ai, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _preview(m.content),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                ),
              ),
              GestureDetector(
                onTap: () => onEdit(m),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.edit_outlined, color: AppColors.primary, size: 16),
                ),
              ),
            ],
          ),
          const Divider(height: 16, color: AppColors.border),
          NoteView(note: m.note!),
        ],
      ),
    );
  }

  static String _preview(String content) {
    final compact = content
        .replaceAll(RegExp(r'[#*`_>\n\-\[\](),.!?]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (compact.isEmpty) return 'AI answer';
    return compact.length > 120 ? '${compact.substring(0, 120)}…' : compact;
  }
}