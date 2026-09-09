import 'package:flutter/material.dart';

import '../app_preferences.dart';
import 'file_manager_service.dart';

class FileEditorScreen extends StatefulWidget {
  final Map<String, dynamic> file;
  const FileEditorScreen({super.key, required this.file});

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> {
  late final TextEditingController _controller;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.file['content_text'] as String? ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await FileManagerService.instance.updateTextFile(widget.file, _controller.text);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File saved successfully.')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save file: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = const Color(0xFF32C5FF);
    final bg = isDark ? const Color(0xFF10131A) : const Color(0xFFF4F8FB);
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        title: Text(widget.file['name'] as String, style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded),
              label: const Text('Save', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
              style: FilledButton.styleFrom(backgroundColor: accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: isDark ? Colors.white12 : Colors.white),
              ),
              child: TextField(
                controller: _controller,
                expands: true,
                maxLines: null,
                minLines: null,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontFamily: 'Google Sans Flex', fontSize: 16, height: 1.5),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.all(20), hintText: 'Start writing...'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
