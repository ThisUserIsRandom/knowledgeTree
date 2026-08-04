import 'package:flutter/material.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_message.dart';

/// Jumpable index of the user's questions in this node's chat.
///
/// Rows are numbered in chat order; tapping one jumps the chat to that
/// message. Rebuilt straight from the live message list, so additions,
/// deletions and edits show up immediately.
class ChatIndexView extends StatelessWidget {
  final List<ChatMessage> messages;
  final ValueChanged<int> onSelect;

  /// Index (into [messages]) that is currently highlighted after a jump.
  final int? highlightedIndex;

  const ChatIndexView({
    super.key,
    required this.messages,
    required this.onSelect,
    this.highlightedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final questions = <int>[];
    for (var i = 0; i < messages.length; i++) {
      if (messages[i].role == MessageRole.user) questions.add(i);
    }

    if (questions.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.format_list_numbered_rtl, color: AppColors.textQuaternary, size: 56),
              const SizedBox(height: 12),
              Text('No questions yet',
                  style: TextStyle(color: AppColors.textTertiary, fontSize: 15)),
              const SizedBox(height: 6),
              Text('Your questions will appear here',
                  style: TextStyle(color: AppColors.textQuaternary, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: questions.length,
      itemBuilder: (context, row) {
        final index = questions[row];
        final m = messages[index];
        final highlighted = highlightedIndex == index;
        return Material(
          color: highlighted
              ? AppColors.primary.withValues(alpha: 0.12)
              : AppColors.surfaceCard,
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: () => onSelect(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: highlighted ? AppColors.primary : AppColors.border,
                  width: highlighted ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (highlighted ? AppColors.primary : AppColors.ai)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${row + 1}',
                      style: TextStyle(
                        color: highlighted ? AppColors.primary : AppColors.ai,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      m.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: AppColors.textPrimary, fontSize: 13.5, height: 1.3),
                    ),
                  ),
                  Icon(Icons.north_east, size: 16, color: AppColors.textTertiary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}