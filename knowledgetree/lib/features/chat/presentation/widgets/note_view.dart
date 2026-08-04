import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_attachment.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_note.dart';

/// Renders a personal note (label + text + image thumbnails) as a distinct
/// tinted block. Used inside message bubbles and in the aggregated notes page.
class NoteView extends StatelessWidget {
  final ChatNote note;

  const NoteView({super.key, required this.note});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 10, bottom: 8),
      padding: const EdgeInsets.all(12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.45), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sticky_note_2_rounded, size: 14, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'Your note',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          if (note.text.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            SelectableText(
              note.text,
              style: TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.45),
            ),
          ],
          if (note.hasImages) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: note.images.map(_image).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _image(ChatAttachment attachment) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 120,
        height: 90,
        child: Image.memory(
          base64Decode(attachment.base64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => Container(
            color: AppColors.surface,
            alignment: Alignment.center,
            child: Icon(Icons.broken_image_outlined, color: AppColors.textTertiary, size: 20),
          ),
        ),
      ),
    );
  }
}
