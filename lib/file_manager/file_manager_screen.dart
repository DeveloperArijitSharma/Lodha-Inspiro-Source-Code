import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'file_ai_chat_screen.dart';
import 'file_editor_screen.dart';
import 'file_manager_service.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});
  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

class _FileManagerScreenState extends State<FileManagerScreen> {
  final _service = FileManagerService.instance;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _files = [];
  String _category = 'all';
  bool _loading = true;
  bool _organizing = false;

  static const _categories = <String, String>{
    'all': 'All Files', 'school_work': 'School Work', 'ai_work': 'AI Work',
    'notebook_notes': 'Notebook Notes', 'personal': 'Personal',
    'documents': 'Documents', 'images': 'Images',
  };

  @override
  void initState() { super.initState(); _search.addListener(() => setState(() {})); _refresh(); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try { final files = await _service.listFiles(); if (mounted) setState(() => _files = files); }
    catch (_) { if (mounted) _snack('Could not load File Manager.', error: true); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _addFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true, type: FileType.custom, allowedExtensions: FileManagerService.supportedExtensions.toList());
      if (result == null) return;
      final user = _service.currentUserId;
      if (user == null) throw StateError('Please sign in again.');
      for (final file in result.files) { final bytes = file.bytes; if (bytes != null && bytes.isNotEmpty) await _service.uploadBytes(user, file.name, bytes); }
      await _refresh(); if (mounted) _snack('Files added to File Manager.');
    } catch (e) { if (mounted) _snack('Could not add files: $e', error: true); }
  }

  Future<void> _organize() async {
    if (_organizing) return;
    setState(() => _organizing = true);
    try { await _service.analyzeAndOrganize(); await _refresh(); if (mounted) _snack('Files analyzed and organized. ✨'); }
    catch (_) { if (mounted) _snack('Could not organize files.', error: true); }
    finally { if (mounted) setState(() => _organizing = false); }
  }

  List<Map<String, dynamic>> get _visible {
    final q = _search.text.trim().toLowerCase();
    return _files.where((file) => (_category == 'all' || file['category'] == _category) && (q.isEmpty || file['name'].toString().toLowerCase().contains(q))).toList();
  }

  void _snack(String text, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: error ? Colors.redAccent : const Color(0xFF32C5FF), content: Text(text)));

  Future<void> _open(Map<String, dynamic> file) async {
    if (file['ai_supported'] == true) {
      final useAi = await showModalBottomSheet<bool>(context: context, backgroundColor: Colors.transparent, builder: (_) => _FileActionSheet(file: file));
      if (useAi == true && mounted) { await Navigator.push(context, MaterialPageRoute(builder: (_) => FileAiChatScreen(file: file))); return; }
    }
    final ext = file['extension'].toString();
    if (ext == 'txt' || ext == 'md') {
      final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FileEditorScreen(file: file)));
      if (changed == true) await _refresh();
      return;
    }
    try {
      final bytes = await _service.download(file);
      if (mounted) await showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _PreviewSheet(file: file, bytes: bytes));
    } catch (_) { if (mounted) _snack('Could not open this file.', error: true); }
  }

  Future<void> _rename(Map<String, dynamic> file) async {
    final controller = TextEditingController(text: file['name'].toString());
    final name = await showDialog<String>(context: context, builder: (_) => AlertDialog(title: const Text('Rename file', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)), content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'File name')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Rename'))]));
    if (name == null || name.trim().isEmpty || name.trim() == file['name']) return;
    try { await _service.rename(file, name); await _refresh(); if (mounted) _snack('File renamed.'); }
    catch (e) { if (mounted) _snack('Could not rename file: $e', error: true); }
  }

  Future<void> _delete(Map<String, dynamic> file) async {
    final yes = await showDialog<bool>(context: context, builder: (_) => AlertDialog(title: const Text('Delete file?', style: TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.bold)), content: Text('Remove “${file['name']}” from File Manager?'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(context, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete'))]));
    if (yes != true) return;
    try { await _service.delete(file); await _refresh(); if (mounted) _snack('File deleted.'); }
    catch (_) { if (mounted) _snack('Could not delete file.', error: true); }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = dark ? Colors.white : const Color(0xFF172033);
    final bg = dark ? const Color(0xFF0D1118) : const Color(0xFFF3F7FA);
    return Scaffold(backgroundColor: bg, body: SafeArea(child: Stack(children: [
      ListView(padding: const EdgeInsets.fromLTRB(18, 18, 18, 100), children: [
        Row(children: [IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.arrow_back_rounded, color: text)), const SizedBox(width: 3), Expanded(child: Text('File Manager', style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))), IconButton(onPressed: _organizing ? null : _organize, tooltip: 'Analyze & organize', icon: _organizing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome_rounded, color: Color(0xFF32C5FF)))]),
        Text('School files, AI work, notebook notes and personal files in one place.', style: TextStyle(color: dark ? Colors.white60 : Colors.black54, fontFamily: 'Google Sans Flex')),
        const SizedBox(height: 16), _SearchBox(controller: _search, dark: dark), const SizedBox(height: 12),
        SizedBox(height: 42, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: _categories.length, separatorBuilder: (_, __) => const SizedBox(width: 8), itemBuilder: (_, i) { final e = _categories.entries.elementAt(i); return ChoiceChip(selected: _category == e.key, label: Text(e.value, style: const TextStyle(fontFamily: 'Google Sans Flex', fontWeight: FontWeight.w600)), onSelected: (_) => setState(() => _category = e.key), selectedColor: const Color(0xFF32C5FF).withOpacity(.2)); })),
        const SizedBox(height: 18), _SmartFolders(files: _files, selected: _category, dark: dark, onSelect: (v) => setState(() => _category = v)), const SizedBox(height: 18),
        if (_loading) const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())) else if (_visible.isEmpty) _EmptyState(dark: dark, onAdd: _addFiles) else ..._visible.map((file) => _FileTile(file: file, dark: dark, onOpen: () => _open(file), onRename: () => _rename(file), onDelete: () => _delete(file))),
      ]),
      Positioned(left: 18, right: 18, bottom: 14, child: _AddButton(onPressed: _addFiles)),
    ])));
  }
}

class _SearchBox extends StatelessWidget {
  final TextEditingController controller;
  final bool dark;
  const _SearchBox({required this.controller, required this.dark});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
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
}

class _SmartFolders extends StatelessWidget {
  final List<Map<String, dynamic>> files; final String selected; final bool dark; final ValueChanged<String> onSelect;
  const _SmartFolders({required this.files, required this.selected, required this.dark, required this.onSelect});
  @override Widget build(BuildContext context) {
    final counts = <String, int>{}; for (final f in files) counts[f['category'] as String] = (counts[f['category'] as String] ?? 0) + 1;
    const items = [('school_work','School Work',Icons.school_rounded),('ai_work','AI Work',Icons.auto_awesome_rounded),('notebook_notes','Notebook Notes',Icons.menu_book_rounded),('personal','Personal',Icons.person_rounded)];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Smart folders', style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), const SizedBox(height: 10), GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: items.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 2.15), itemBuilder: (_, i) { final x = items[i]; final active = selected == x.$1; return GestureDetector(onTap: () => onSelect(x.$1), child: Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: active ? const Color(0xFF32C5FF).withOpacity(.15) : (dark ? Colors.white.withOpacity(.055) : Colors.white), borderRadius: BorderRadius.circular(20), border: Border.all(color: active ? const Color(0xFF32C5FF).withOpacity(.45) : (dark ? Colors.white12 : Colors.white))), child: Row(children: [Icon(x.$3, color: const Color(0xFF32C5FF)), const SizedBox(width: 9), Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.$2, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), Text('${counts[x.$1] ?? 0} files', style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontSize: 11))]))]))); });
  }
}

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file; final bool dark; final VoidCallback onOpen, onRename, onDelete;
  const _FileTile({required this.file, required this.dark, required this.onOpen, required this.onRename, required this.onDelete});
  @override Widget build(BuildContext context) {
    final ai = file['ai_supported'] == true; final ext = file['extension'].toString(); final size = (file['size_bytes'] as num? ?? 0) / 1024;
    return Container(margin: const EdgeInsets.only(bottom: 10), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.055) : Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: dark ? Colors.white12 : Colors.white)), child: ListTile(onTap: onOpen, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), leading: Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF32C5FF).withOpacity(.14), borderRadius: BorderRadius.circular(15)), child: Icon(_icon(ext), color: const Color(0xFF32C5FF))), title: Text(file['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), subtitle: Text('${_label(file['category'])} • ${size < 1024 ? '${size.toStringAsFixed(0)} KB' : '${(size / 1024).toStringAsFixed(1)} MB'}${ai ? ' • AI ready' : ''}', style: TextStyle(color: dark ? Colors.white54 : Colors.black45, fontSize: 11)), trailing: PopupMenuButton<String>(onSelected: (v) { if (v == 'rename') onRename(); if (v == 'delete') onDelete(); }, itemBuilder: (_) => const [PopupMenuItem(value: 'rename', child: Text('Rename')), PopupMenuItem(value: 'delete', child: Text('Delete'))])));
  }
  static IconData _icon(String e) { switch (e) { case 'pdf': return Icons.picture_as_pdf_rounded; case 'txt': case 'md': return Icons.article_rounded; case 'docx': return Icons.description_rounded; case 'xlsx': return Icons.table_chart_rounded; case 'pptx': return Icons.slideshow_rounded; case 'jpg': case 'jpeg': case 'png': case 'webp': return Icons.image_rounded; default: return Icons.insert_drive_file_rounded; } }
  static String _label(String v) => {'school_work':'School Work','ai_work':'AI Work','notebook_notes':'Notebook Notes','personal':'Personal','documents':'Documents','images':'Images','other':'Other'}[v] ?? 'Other';
}

class _FileActionSheet extends StatelessWidget {
  final Map<String, dynamic> file;
  const _FileActionSheet({required this.file});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 30),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(4))),
        const SizedBox(height: 14),
        ListTile(leading: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF32C5FF)), title: const Text('Ask Inspiro AI', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')), subtitle: const Text('Use only this file as grounded AI context.'), onTap: () => Navigator.pop(context, true)),
        ListTile(leading: const Icon(Icons.visibility_rounded), title: const Text('Preview', style: TextStyle(fontFamily: 'Google Sans Flex')), onTap: () => Navigator.pop(context, false)),
      ]),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  final Map<String, dynamic> file; final Uint8List bytes;
  const _PreviewSheet({required this.file, required this.bytes});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = file['content_text']?.toString();
    final ext = file['extension'].toString();
    return Container(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .82), padding: const EdgeInsets.fromLTRB(20, 12, 20, 28), decoration: BoxDecoration(color: dark ? const Color(0xFF161A22) : Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: SafeArea(child: Column(children: [Container(width: 42, height: 4, decoration: BoxDecoration(color: dark ? Colors.white24 : Colors.black12, borderRadius: BorderRadius.circular(4))), const SizedBox(height: 15), Row(children: [Expanded(child: Text(file['name'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: dark ? Colors.white : Colors.black87, fontSize: 19, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex'))), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded))]), const SizedBox(height: 10), Expanded(child: text != null && text.isNotEmpty ? SingleChildScrollView(child: SelectableText(text, style: TextStyle(color: dark ? Colors.white70 : Colors.black87, height: 1.45, fontFamily: 'Google Sans Flex'))) : ['jpg','jpeg','png','webp'].contains(ext) ? SingleChildScrollView(child: Image.memory(bytes, fit: BoxFit.contain)) : Center(child: Text('Preview is not available for this file type yet.', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white54 : Colors.black54, fontFamily: 'Google Sans Flex'))))])));
  }
}

class _EmptyState extends StatelessWidget {
  final bool dark; final VoidCallback onAdd;
  const _EmptyState({required this.dark, required this.onAdd});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(30), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.05) : Colors.white, borderRadius: BorderRadius.circular(28)), child: Column(children: [Icon(Icons.folder_open_rounded, size: 56, color: dark ? Colors.white30 : Colors.black26), const SizedBox(height: 12), Text('No files here yet', style: TextStyle(color: dark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Google Sans Flex')), const SizedBox(height: 6), Text('Add a supported file and Inspiro can organize it for you.', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white54 : Colors.black54)), const SizedBox(height: 14), OutlinedButton.icon(onPressed: onAdd, icon: const Icon(Icons.upload_file_rounded), label: const Text('Add file'))]));
}

class _AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _AddButton({required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Material(
          color: const Color(0xFF32C5FF).withOpacity(.9),
          child: InkWell(
            onTap: onPressed,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.add_rounded, color: Colors.white),
                SizedBox(width: 8),
                Text('Add files from device', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
