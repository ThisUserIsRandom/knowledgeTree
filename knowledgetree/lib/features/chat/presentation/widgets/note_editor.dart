import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:knowledgetree/core/theme/colors.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_attachment.dart';
import 'package:knowledgetree/features/chat/domain/models/chat_note.dart';

/// Result of the note editor.
class NoteEditorResult {
  final bool removed;
  final ChatNote? note;

  const NoteEditorResult({this.removed = false, this.note});

  static const removedResult = NoteEditorResult(removed: true);
}

/// Modal bottom sheet that composes/edits a personal note (text + images).
///
/// Opens via [showModalBottomSheet] with [NoteEditor]. Returns a
/// [NoteEditorResult]: null if cancelled, `removedResult` if the note was
/// removed, otherwise a [ChatNote] to save.
class NoteEditor extends StatefulWidget {
  final ChatNote? initialNote;

  const NoteEditor({super.key, this.initialNote});

  @override
  State<NoteEditor> createState() => _NoteEditorState();

  static Future<NoteEditorResult?> show(BuildContext context, {ChatNote? initial}) {
    return showModalBottomSheet<NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => NoteEditor(initialNote: initial),
    );
  }
}

class _NoteEditorState extends State<NoteEditor> {
  late final TextEditingController _textController;
  late List<ChatAttachment> _images;

  bool get _hasContent =>
      _textController.text.trim().isNotEmpty || _images.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialNote?.text ?? '');
    _images = List.of(widget.initialNote?.images ?? const []);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final result = await FilePicker.pickFiles(type: FileType.image);
    if (result == null || result.files.isEmpty) return;
    final f = result.files.first;
    Uint8List bytes;
    try {
      bytes = await f.readAsBytes();
    } catch (e) {
      return;
    }
    if (bytes.isEmpty) return;
    final ext = (f.extension ?? 'png').toLowerCase();
    setState(() {
      _images = [
        ..._images,
        ChatAttachment(
          filename: f.name,
          mimeType: _mimeFor(ext),
          base64: base64Encode(bytes),
        ),
      ];
    });
  }

  static String _mimeFor(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      case 'png':
      default:
        return 'image/png';
    }
  }

  void _save() {
    Navigator.of(context).pop(NoteEditorResult(
      note: ChatNote(
        text: _textController.text,
        images: _images,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
            child: Row(
              children: [
                Icon(Icons.sticky_note_2_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                Text('Your note',
                    style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppColors.textSecondary, size: 22),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: TextField(
              controller: _textController,
              minLines: 3,
              maxLines: 6,
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Add your own note...',
                hintStyle: TextStyle(color: AppColors.textTertiary),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                ),
              ),
            ),
          ),
          if (_images.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final img in _images)
                    _thumbnail(img, onRemove: () {
                      setState(() => _images = _images.where((e) => e != img).toList());
                    }),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickImage,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                  label: const Text('Add image'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: BorderSide(color: AppColors.primary.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (widget.initialNote != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(NoteEditorResult.removedResult),
                    child: Text('Remove note',
                        style: TextStyle(color: AppColors.urgent)),
                  ),
                FilledButton(
                  onPressed: _hasContent ? _save : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumbnail(ChatAttachment img, {required VoidCallback onRemove}) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.memory(
            base64Decode(img.base64),
            width: 88,
            height: 88,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 88,
              height: 88,
              color: AppColors.surface,
              alignment: Alignment.center,
              child: Icon(Icons.broken_image_outlined,
                  color: AppColors.textTertiary, size: 24),
            ),
          ),
        ),
        Positioned(
          top: 2,
          right: 2,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
