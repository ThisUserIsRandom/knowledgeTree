import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_message.dart';
import 'note_view.dart';

class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isStreaming;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;
  final VoidCallback? onEditNote;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
    this.onCopy,
    this.onDelete,
    this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final showActions = isUser ? true : !isStreaming;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) _avatar(isUser),
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: isUser ? AppColors.chatUserBubble : AppColors.chatAiBubble,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isUser ? Radius.zero : const Radius.circular(16),
                      bottomLeft: isUser ? const Radius.circular(16) : Radius.zero,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadow,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isUser)
                        SelectableText(
                          message.content,
                          style: TextStyle(
                              color: AppColors.chatUserText, fontSize: 14.5, height: 1.5),
                        )
                      else
                        SelectionArea(
                          child: MarkdownBody(
                            data: message.content + (isStreaming ? ' ▌' : ''),
                            styleSheet: MarkdownStyleSheet(
                              p: TextStyle(
                                  color: AppColors.chatAiText, fontSize: 14.5, height: 1.6),
                              code: TextStyle(
                                color: AppColors.primary,
                                backgroundColor: AppColors.surfaceElevated,
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                              codeblockDecoration: BoxDecoration(
                                color: AppColors.surfaceElevated,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.border, width: 1),
                              ),
                              blockquoteDecoration: BoxDecoration(
                                border:
                                    const Border(left: BorderSide(color: AppColors.ai, width: 3)),
                                color: AppColors.aiContainer,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              h1: TextStyle(
                                  color: AppColors.primary, fontSize: 20, fontWeight: FontWeight.bold),
                              h2: TextStyle(
                                  color: AppColors.primary, fontSize: 17, fontWeight: FontWeight.bold),
                              h3: TextStyle(
                                  color: AppColors.primary, fontSize: 15, fontWeight: FontWeight.bold),
                              strong: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold),
                              em: TextStyle(color: AppColors.textSecondary, fontStyle: FontStyle.italic),
                              a: TextStyle(color: AppColors.primary, decoration: TextDecoration.none),
                            ),
                          ),
                        ),
                      if (message.hasNote) _noteBlock(),
                    ],
                  ),
                ),
                if (showActions) _actionRow(),
              ],
            ),
          ),
          if (isUser) _avatar(isUser),
        ],
      ),
    );
  }

  Widget _actionRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onEditNote != null) ...[
            _actionButton(
              icon: Icons.sticky_note_2_rounded,
              tooltip: 'Add / edit note',
              onPressed: onEditNote,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
          ],
          if (onCopy != null) ...[
            _actionButton(
              icon: Icons.copy_rounded,
              tooltip: 'Copy',
              onPressed: onCopy,
            ),
            const SizedBox(width: 4),
          ],
          _actionButton(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Delete',
            onPressed: onDelete,
            color: AppColors.urgent,
          ),
        ],
      ),
    );
  }

  Widget _noteBlock() {
    return NoteView(note: message.note!);
  }

  Widget _actionButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
              color: (color ?? AppColors.textQuaternary).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: color ?? AppColors.textQuaternary),
          ),
        ),
      ),
    );
  }

  Widget _avatar(bool isUser) {
    return Container(
      width: 30,
      height: 30,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: isUser
            ? const LinearGradient(
                colors: [AppColors.primary, AppColors.ai],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.ai, AppColors.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: (isUser ? AppColors.primary : AppColors.ai).withValues(alpha: 0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        isUser ? Icons.person_rounded : Icons.auto_awesome_rounded,
        size: 16,
        color: Colors.white,
      ),
    );
  }
}