import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_preferences.dart';
import 'file_editor_screen.dart';
import 'file_manager_service.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});

  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final service = FileManagerService.instance;
  final searchController = TextEditingController();
  List<Map<String, dynamic>> _files = [];
  bool _loading = true;
  bool _organizing = false;
  String _category = 'all';

  static const categories = <String, String>{
    'all': 'All Files',
    'school_work': 'School Work',
    'ai_work': 'AI Work',
    'notebook_notes': 'Notebook Notes',
    'personal': 'Personal',
    'documents': 'Documents',
    'images': 'Images',
  };

  @override
  void initState() {
    super.initState();
    _loadFiles();
    searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFiles() async {
    setState(() => _loading = true);
    try {
      final files = await service.listFiles();
      if (mounted) setState(() => _files = files);
    } catch (e) {
      if (mounted) _snack('Could not load files.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    try {
      await service.pickAndUpload();
      await _loadFiles();
      if (mounted) _snack('Files added to File Manager.');
    } catch (e) {
      if (mounted) _snack('Could not add files: $e', error: true);
    }
  }

  Future<void> _organize() async {
    if (_organizing) return;
    setState(() => _organizing = true);
    try {
      await service.analyzeAndOrganize();
      await _loadFiles();
      if (mounted) _snack('Files analyzed and organized into smart folders. ✨');
    } catch (e) {
      if (mounted) _snack('Could not organize files.', error: true);
    } finally {
      if (mounted) setState(() => _organizing = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: error ? Colors.redAccent : const Color(0xFF32C5FF)));
  }

  List<Map<String, dynamic>> get _visibleFiles {
    final query = searchController.text.trim().toLowerCase();
    return _files.where((file) {
      final matchesCategory = _category == 'all' || file['category'] == _category;
      final name = (file['name'] as String).toLowerCase();
      return matchesCategory && (query.isEmpty || name.contains(query));
    }).toList();
  }

  Color _textColor(bool dark) => dark ? Colors.white : const Color(0xFF1E1E1E);
  Color _mutedColor(bool dark) => dark ? Colors.white60 : Colors.black54;

  IconData _fileIcon(String extension) {
    switch (extension) {
      case 'pdf': return Icons.picture_as_pdf_rounded;
      case 'txt':
      case 'md': return Icons.article_rounded;
      case 'docx': return Icons.description_rounded;
      case 'xlsx': return Icons.table_chart_rounded;
      case 'pptx': return Icons.slideshow_rounded;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp': return Icons.image_rounded;
      default: return Icons.insert_drive_file_rounded;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'school_work': return Icons.school_rounded;
      case 'ai_work': return Icons.auto_awesome_rounded;
      case 'notebook_notes': return Icons.menu_book_rounded;
      case 'personal': return Icons.person_rounded;
      case 'images': return Icons.image_rounded;
      default: return Icons.folder_rounded;
    }
  }

  String _categorySubtitle(String category) {
    switch (category) {
      case 'school_work': return 'Homework, assignments, projects and school documents';
      case 'ai_work': return 'Files prepared for Inspiro AI';
      case 'notebook_notes': return 'Saved notebook notes and exports';
      case 'personal': return 'Your personal files';
      case 'documents': return 'PDF and office documents';
      case 'images': return 'Pictures and visual files';
      default: return 'Everything stored in Inspiro';
    }
  }

  Future<void> _rename(Map<String, dynamic> file) async {
    final controller = TextEditingController(text: file['name'] as String);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename file', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'File name')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Rename'))],
      ),
    );
    if (value == null || value.trim().isEmpty || value.trim() == file['name']) return;
    try {
      await service.rename(file, value);
      await _loadFiles();
      if (mounted) _snack('File renamed.');
    } catch (e) {
      if (mounted) _snack('Could not rename file: $e', error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete file?', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)),
        content: Text('Remove “${file['name']}” from File Manager?'),
        actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete'))],
      ),
    );
    if (confirmed != true) return;
    try {
      await service.delete(file);
      await _loadFiles();
      if (mounted) _snack('File deleted.');
    } catch (e) {
      if (mounted) _snack('Could not delete file.', error: true);
    }
  }

  Future<void> _open(Map<String, dynamic> file) async {
    final extension = file['extension'] as String;
    if (extension == 'txt' || extension == 'md') {
      final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FileEditorScreen(file: file)));
      if (changed == true) await _loadFiles();
      return;
    }
    final bytes = await service.download(file);
    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FilePreviewSheet(file: file, bytes: bytes, service: service),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = _textColor(dark);
    final bg = dark ? const Color(0xFF0D1118) : const Color(0xFFF3F7FA);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Stack(
          children: [
            ListView(
              padding: EdgeInsets.fromLTRB(18, 18, 18, size.height * .13),
              children: [
                Row(
                  children: [
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: text)),
                    const SizedBox(width: 4),
                    Expanded(child: Text('File Manager', style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))),
                    IconButton(onPressed: _organizing ? null : _organize, tooltip: 'Analyze & organize', icon: _organizing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.auto_awesome_rounded, color: const Color(0xFF32C5FF))),
                  ],
                ),
                const SizedBox(height: 6),
                Text('One place for school files, AI work, notebook notes and personal documents.', style: TextStyle(color: _mutedColor(dark), fontFamily: 'Google Sans Flex')),
                const SizedBox(height: 18),
                _GlassSearch(controller: searchController, dark: dark),
                const SizedBox(height: 14),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, index) {
                      final entry = categories.entries.elementAt(index);
                      final selected = _category == entry.key;
                      return ChoiceChip(
                        selected: selected,
                        label: Text(entry.value, style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.w600)),
                        avatar: Icon(_categoryIcon(entry.key), size: 17),
                        onSelected: (_) => setState(() => _category = entry.key),
                        selectedColor: const Color(0xFF32C5FF).withOpacity(.22),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                _SmartFolders(dark: dark, files: _files, selected: _category, onSelect: (value) => setState(() => _category = value)),
                const SizedBox(height: 20),
                if (_loading)
                  const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator()))
                else if (_visibleFiles.isEmpty)
                  _EmptyFiles(dark: dark, onAdd: _upload)
                else
                  ..._visibleFiles.map((file) => _FileTile(file: file, dark: dark, onOpen: () => _open(file), onRename: () => _rename(file), onDelete: () => _delete(file))),
              ],
            ),
            Positioned(left: 18, right: 18, bottom: 14, child: _GlassAddButton(dark: dark, onPressed: _upload)),
          ],
        ),
      ),
    );
  }
}

class _GlassSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool dark;
  const _GlassSearch({required this.controller, required this.dark});
  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(22),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
      child: Container(
        decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.07) : Colors.white.withOpacity(.75), borderRadius: BorderRadius.circular(22), border: Border.all(color: dark ? Colors.white12 : Colors.white)),
        child: TextField(controller: controller, style: const TextStyle(fontFamily: 'Google Sans Flex'), decoration: InputDecoration(prefixIcon: Icon(Icons.search_rounded, color: dark ? Colors.white60 : Colors.black45), hintText: 'Search files', border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 15))),
      ),
    ),
  );
}

class _SmartFolders extends StatelessWidget {
  final bool dark;
  final List<Map<String, dynamic>> files;
  final String selected;
  final ValueChanged<String> onSelect;
  const _SmartFolders({required this.dark, required this.files, required this.selected, required this.onSelect});
  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final file in files) counts[file['category'] as String] = (counts[file['category'] as String] ?? 0) + 1;
    const data = [
      ('school_work', 'School Work', Icons.school_rounded),
      ('ai_work', 'AI Work', Icons.auto_awesome_rounded),
      ('notebook_notes', 'Notebook Notes', Icons.menu_book_rounded),
      ('personal', 'Personal', Icons.person_rounded),
    ];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Smart folders', style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
      const SizedBox(height: 10),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.1),
        itemBuilder: (_, index) {
          final item = data[index];
          final active = selected == item.$1;
          return GestureDetector(
            onTap: () => onSelect(item.$1),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: active ? const Color(0xFF32C5FF).withOpacity(.16) : (dark ? Colors.white.withOpacity(.06) : Colors.white), borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? const Color(0xFF32C5FF).withOpacity(.45) : (dark ? Colors.white12 : Colors.white)), boxShadow: dark ? null : [BoxShadow(color: Colors.black.withOpacity(.03), blurRadius: 10)]),
              child: Row(children: [Icon(item.$3, color: const Color(0xFF32C5FF)), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(item.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), Text('${counts[item.$1] ?? 0} files', style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontSize: 11, fontFamily: 'Google Sans Flex'))]))]),
            ),
          );
        },
      ),
    ]);
  }
}

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final bool dark;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _FileTile({required this.file, required this.dark, required this.onOpen, required this.onRename, required this.onDelete});
  @override
  Widget build(BuildContext context) {
    final ext = file['extension'] as String;
    final ai = file['ai_supported'] == true;
    final category = file['category'] as String;
    final size = ((file['size_bytes'] as num?)?.toDouble() ?? 0) / 1024;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.055) : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: dark ? Colors.white12 : Colors.white), boxShadow: dark ? null : [BoxShadow(color: Colors.black.withOpacity(.025), blurRadius: 10)]),
      child: ListTile(
        onTap: onOpen,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF32C5FF).withOpacity(.14), borderRadius: BorderRadius.circular(15)), child: Icon(_icon(ext), color: const Color(0xFF32C5FF))),
        title: Text(file['name'] as String, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        subtitle: Text('${categoriesLabel(category)} • ${size < 1024 ? '${size.toStringAsFixed(0)} KB' : '${(size / 1024).toStringAsFixed(1)} MB'}${ai ? ' • AI ready' : ''}', style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontSize: 11, fontFamily: 'Google Sans Flex')),
        trailing: PopupMenuButton<String>(onSelected: (value) { if (value == 'rename') onRename(); if (value == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'delete', child: Text('Delete'))]),
      ),
    );
  }
  static IconData _icon(String ext) { switch (ext) { case 'pdf': return Icons.picture_as_pdf_rounded; case 'txt': case 'md': return Icons.article_rounded; case 'docx': return Icons.description_rounded; case 'xlsx': return Icons.table_chart_rounded; case 'pptx': return Icons.slideshow_rounded; case 'jpg': case 'jpeg': case 'png': case 'webp': return Icons.image_rounded; default: return Icons.insert_drive_file_rounded; } }
  static String categoriesLabel(String value) => {'school_work': 'School Work', 'ai_work': 'AI Work', 'notebook_notes': 'Notebook Notes', 'personal': 'Personal', 'documents': 'Documents', 'images': 'Images', 'other': 'Other'}[value] ?? 'Other';
}

class _EmptyFiles extends StatelessWidget {
  final bool dark;
  final VoidCallback onAdd;
  const _EmptyFiles({required this.dark, required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.05) : Colors.white, borderRadius: BorderRadius.circular(28)), child: Column(children: [Icon(Icons.folder_open_rounded, size: 58, color: dark ? Colors.white30 : Colors.black26), const SizedBox(height: 12), Text('No files here yet', style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Google Sans Flex')), const SizedBox(height: 6), Text('Add a supported file and Inspiro will organize it for you.', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex')), const SizedBox(height: 16), OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.upload_file_rounded), label: const Text('Add file'))]));
}

class _GlassAddButton extends StatelessWidget {
  final bool dark;
  final VoidCallback onPressed;
  const _GlassAddButton({required this.dark, required this.onPressed});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(28), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20), child: Container(decoration: BoxDecoration(color: const Color(0xFF32C5FF).withOpacity(.9), borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(.35))), child: Material(color: Colors.transparent, child: InkWell(onTap: onPressed, child: const Padding(padding: EdgeInsets.symmetric(vertical: 14), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.add_rounded, color: Colors.white), SizedBox(width: 8), Text('Add files from device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))]))))));
}

class _FilePreviewSheet extends StatelessWidget {
  final Map<String, dynamic> file;
  final Uint8List bytes;
  final FileManagerService service;
  const _FilePreviewSheet({required this.file, required this.bytes, required this.service});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ext = file['extension'] as String;
    final text = file['content_text'] as String?;
    return Container(decoration: BoxDecoration(color: dark ? const Color(0xFF161A22) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), padding: const EdgeInsets.fromLTRB(20, 12, 20, 30), child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [Container(width: 42, height: 4, decoration: BoxDecoration(color: dark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 16), Row(children: [Expanded(child: Text(file['name'] as String, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex', color: dark ? Colors.white : Colors.black87))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]), const SizedBox(height: 12), if (['jpg','jpeg','png','webp'].contains(ext)) ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.memory(bytes, fit: BoxFit.contain, height: 300)) else if (text != null && text.isNotEmpty) Flexible(child: SingleChildScrollView(child: SelectableText(text, style: TextStyle(fontFamily: 'Google Sans Flex', color: dark ? Colors.white70 : Colors.black87, height: 1.45)))) else Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.05) : const Color(0xFFF4F7FA), borderRadius: BorderRadius.circular(20)), child: Column(children: [Icon(Icons.insert_drive_file_rounded, size: 54, color: const Color(0xFF32C5FF)), const SizedBox(height: 10), Text('Preview is not available for this file type yet.', textAlign: TextAlign.center, style: TextStyle(fontFamily: 'Google Sans Flex', color: dark ? Colors.white70 : Colors.black54))]))]))));
  }
}
