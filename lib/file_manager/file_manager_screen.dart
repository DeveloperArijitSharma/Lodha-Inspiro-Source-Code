import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import 'file_ai_chat_screen.dart';
import 'file_editor_screen.dart';
import 'file_manager_service.dart';

class FileManagerScreen extends StatefulWidget {
  const FileManagerScreen({super.key});
  @override
  State<FileManagerScreen> createState() => _FileManagerScreenState();
}

enum _SortMode { name, type, size, newest, oldest }

class _FileManagerScreenState extends State<FileManagerScreen> {
  final _service = FileManagerService.instance;
  final _search = TextEditingController();
  List<Map<String, dynamic>> _files = [];
  List<Map<String, dynamic>> _folders = [];
  String? _folderId;
  String _folderTitle = 'Personal';
  _SortMode _sort = _SortMode.newest;
  bool _loading = true;
  bool _organizing = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _refresh();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (mounted) setState(() => _loading = true);
    try {
      final result = await Future.wait([
        _service.listFiles(folderId: _folderId),
        _service.listFolders(parentId: _folderId),
      ]);
      if (!mounted) return;
      setState(() {
        _files = result[0];
        _folders = result[1];
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
        _toast('Could not load this folder.', error: true);
      }
    }
  }

  List<Map<String, dynamic>> get _visibleFiles {
    final q = _search.text.trim().toLowerCase();
    final files = _files.where((file) {
      if (q.isEmpty) return true;
      return file['name'].toString().toLowerCase().contains(q) ||
          file['extension'].toString().toLowerCase().contains(q) ||
          file['category'].toString().toLowerCase().contains(q);
    }).toList();
    files.sort((a, b) {
      switch (_sort) {
        case _SortMode.name:
          return a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
        case _SortMode.type:
          return a['extension'].toString().compareTo(b['extension'].toString());
        case _SortMode.size:
          return ((b['size_bytes'] as num?) ?? 0).compareTo((a['size_bytes'] as num?) ?? 0);
        case _SortMode.newest:
          return b['created_at'].toString().compareTo(a['created_at'].toString());
        case _SortMode.oldest:
          return a['created_at'].toString().compareTo(b['created_at'].toString());
      }
    });
    return files;
  }

  Future<void> _createFolder() async {
    final controller = TextEditingController();
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('New folder'),
        content: Padding(padding: const EdgeInsets.only(top: 14), child: CupertinoTextField(controller: controller, autofocus: true, placeholder: 'Folder name')),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    try {
      await _service.createFolder(name, parentId: _folderId);
      await _refresh();
    } catch (e) {
      _toast('Could not create folder: $e', error: true);
    }
  }

  Future<void> _renameFolder(Map<String, dynamic> folder) async {
    final controller = TextEditingController(text: folder['name'].toString());
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Rename folder'),
        content: Padding(padding: const EdgeInsets.only(top: 14), child: CupertinoTextField(controller: controller, autofocus: true)),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await _service.renameFolder(folder, name);
    await _refresh();
  }

  Future<void> _deleteFolder(Map<String, dynamic> folder) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete folder?'),
        content: const Text('The folder and everything inside it will be removed.'),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.deleteFolder(folder);
      await _refresh();
    } catch (_) {
      _toast('Could not delete folder.', error: true);
    }
  }

  Future<void> _import() async {
    final choice = await showCupertinoModalPopup<String>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Add to File Manager'),
        message: const Text('The system picker can show Drive, OneDrive and other installed file providers.'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, 'files'), child: const Text('Files / Drive / OneDrive / Other apps')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, 'gallery'), child: const Text('Gallery / Images')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, 'folder'), child: const Text('New folder')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
      ),
    );
    try {
      if (choice == 'files') {
        await _service.importFromDevice(folderId: _folderId);
        await _refresh();
      } else if (choice == 'gallery') {
        await _service.importImagesFromGallery(folderId: _folderId);
        await _refresh();
      } else if (choice == 'folder') {
        await _createFolder();
      }
    } catch (e) {
      _toast('Import failed: $e', error: true);
    }
  }

  Future<void> _openFolder(Map<String, dynamic> folder) async {
    setState(() {
      _folderId = folder['id'].toString();
      _folderTitle = folder['name'].toString();
    });
    await _refresh();
  }

  Future<void> _goRoot() async {
    if (_folderId == null) return;
    setState(() {
      _folderId = null;
      _folderTitle = 'Personal';
    });
    await _refresh();
  }

  Future<void> _openFile(Map<String, dynamic> file) async {
    final ext = file['extension'].toString().toLowerCase();
    if (ext == 'txt' || ext == 'md') {
      final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => FileEditorScreen(file: file)));
      if (changed == true) await _refresh();
      return;
    }
    try {
      final bytes = await _service.download(file);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => FilePreviewScreen(file: file, bytes: bytes)));
    } catch (_) {
      _toast('Could not open this file.', error: true);
    }
  }

  Future<void> _moveFile(Map<String, dynamic> file) async {
    final folders = await _service.listFolders(parentId: _folderId);
    final target = await showCupertinoModalPopup<String?>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Move file'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, '__root__'), child: const Text('Personal root')),
          ...folders.map((folder) => CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, folder['id'].toString()), child: Text(folder['name'].toString()))),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
      ),
    );
    if (target == null) return;
    await _service.moveFile(file, folderId: target == '__root__' ? null : target);
    await _refresh();
  }

  Future<void> _renameFile(Map<String, dynamic> file) async {
    final controller = TextEditingController(text: file['name'].toString());
    final name = await showCupertinoDialog<String>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Rename file'),
        content: Padding(padding: const EdgeInsets.only(top: 14), child: CupertinoTextField(controller: controller, autofocus: true)),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext, controller.text), child: const Text('Rename')),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty || name.trim() == file['name']) return;
    await _service.rename(file, name);
    await _refresh();
  }

  Future<void> _deleteFile(Map<String, dynamic> file) async {
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: const Text('Delete file?'),
        content: Text(file['name'].toString()),
        actions: [
          CupertinoDialogAction(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          CupertinoDialogAction(isDestructiveAction: true, onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await _service.delete(file);
    await _refresh();
  }

  Future<void> _info(Map<String, dynamic> file) async {
    final date = DateTime.tryParse(file['created_at'].toString())?.toLocal();
    final imported = DateTime.tryParse(file['imported_at']?.toString() ?? '')?.toLocal();
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: Text(file['name'].toString()),
        message: Text('Name: ${file['name']}\nType: ${file['extension'].toString().toUpperCase()}\nSize: ${_size(file['size_bytes'])}\nDate: ${_date(date)}\nTime: ${_time(date)}\nImported: ${_date(imported)} ${_time(imported)}\nLocation: ${file['location_label'] ?? 'On this device'}\nSource: ${file['source_provider'] ?? 'Inspiro File Manager'}'),
        actions: [
          CupertinoActionSheetAction(onPressed: () { Navigator.pop(sheetContext); _openFile(file); }, child: const Text('Open')),
          if (file['ai_supported'] == true) CupertinoActionSheetAction(onPressed: () { Navigator.pop(sheetContext); Navigator.push(context, MaterialPageRoute(builder: (_) => FileAiChatScreen(file: file))); }, child: const Text('Ask Inspiro AI')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('Close')),
      ),
    );
  }

  Future<void> _organize() async {
    if (_organizing) return;
    setState(() => _organizing = true);
    try {
      await _service.analyzeAndOrganize();
      await _refresh();
    } catch (_) {
      _toast('Could not organize files.', error: true);
    } finally {
      if (mounted) setState(() => _organizing = false);
    }
  }

  Future<void> _sortSheet() async {
    final selected = await showCupertinoModalPopup<_SortMode>(
      context: context,
      builder: (sheetContext) => CupertinoActionSheet(
        title: const Text('Sort files'),
        actions: [
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, _SortMode.name), child: const Text('Name')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, _SortMode.type), child: const Text('Type')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, _SortMode.size), child: const Text('Size')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, _SortMode.newest), child: const Text('Date & time, newest first')),
          CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext, _SortMode.oldest), child: const Text('Date & time, oldest first')),
        ],
        cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
      ),
    );
    if (selected != null) setState(() => _sort = selected);
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating, backgroundColor: error ? Colors.redAccent : const Color(0xFF4B8DFF)));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF172033);
    return Scaffold(
      backgroundColor: dark ? const Color(0xFF080C14) : const Color(0xFFF2F6FB),
      body: Stack(children: [
        const _LiquidBackground(),
        SafeArea(child: RefreshIndicator(color: const Color(0xFF4B8DFF), onRefresh: _refresh, child: ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(18, 14, 18, 120), children: [
          _HeaderRow(),
          const SizedBox(height: 6),
          Builder(builder: (context) => _FolderHeader(title: _folderTitle, isRoot: _folderId == null, foreground: foreground, onBack: _goRoot, onFolder: _createFolder, onImport: _import, onOrganize: _organize)),
          const SizedBox(height: 16),
          _GlassSearch(controller: _search, dark: dark),
          const SizedBox(height: 8),
          Row(children: [Expanded(child: Text('${_folders.length} folders • ${_visibleFiles.length} files', style: TextStyle(color: foreground.withOpacity(.55), fontSize: 13))), CupertinoButton(padding: EdgeInsets.zero, onPressed: _sortSheet, child: Row(children: [Icon(CupertinoIcons.arrow_up_arrow_down, size: 16, color: foreground), const SizedBox(width: 5), Text(_sortLabel, style: TextStyle(color: foreground, fontWeight: FontWeight.w600))]))]),
          if (_loading) const Padding(padding: EdgeInsets.all(50), child: Center(child: CupertinoActivityIndicator(radius: 14))) else ...[
            if (_folders.isNotEmpty) ...[_SectionTitle('Folders', foreground), const SizedBox(height: 8), ..._folders.map((folder) => _FolderTile(folder: folder, dark: dark, foreground: foreground, onOpen: () => _openFolder(folder), onRename: () => _renameFolder(folder), onDelete: () => _deleteFolder(folder))), const SizedBox(height: 12)],
            if (_visibleFiles.isNotEmpty) ...[_SectionTitle('Files', foreground), const SizedBox(height: 8), ..._visibleFiles.map((file) => _FileTile(file: file, dark: dark, foreground: foreground, onOpen: () => _openFile(file), onInfo: () => _info(file), onMove: () => _moveFile(file), onRename: () => _renameFile(file), onDelete: () => _deleteFile(file)))],
            if (_folders.isEmpty && _visibleFiles.isEmpty) _EmptyFiles(dark: dark, onImport: _import, onFolder: _createFolder),
          ],
        ]))),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: _import, icon: const Icon(CupertinoIcons.add), label: const Text('Import')),
    );
  }

  String get _sortLabel => switch (_sort) { _SortMode.name => 'Name', _SortMode.type => 'Type', _SortMode.size => 'Size', _SortMode.newest => 'Newest', _SortMode.oldest => 'Oldest' };
  static String _size(dynamic value) { final bytes = (value as num?)?.toDouble() ?? 0; if (bytes < 1024) return '${bytes.toInt()} B'; if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB'; if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'; return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB'; }
  static String _date(DateTime? value) => value == null ? 'Unknown' : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
  static String _time(DateTime? value) => value == null ? 'Unknown' : '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

class _LiquidBackground extends StatelessWidget {
  const _LiquidBackground();
  @override
  Widget build(BuildContext context) => Stack(children: [Positioned(top: -120, right: -100, child: _orb(300, const Color(0xFF4B8DFF))), Positioned(top: 240, left: -150, child: _orb(320, const Color(0xFF9A7BFF))), Positioned(bottom: -180, right: -120, child: _orb(360, const Color(0xFF56D8C0))), Positioned.fill(child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60), child: Container(color: Colors.transparent)))]);
  Widget _orb(double size, Color color) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.16), boxShadow: [BoxShadow(color: color.withOpacity(.20), blurRadius: 80, spreadRadius: 20)]));
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();
  @override
  Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Text('Files', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : const Color(0xFF172033), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: .4)));
}

class _FolderHeader extends StatelessWidget {
  final String title;
  final bool isRoot;
  final Color foreground;
  final VoidCallback onBack;
  final VoidCallback onFolder;
  final VoidCallback onImport;
  final VoidCallback onOrganize;
  const _FolderHeader({required this.title, required this.isRoot, required this.foreground, required this.onBack, required this.onFolder, required this.onImport, required this.onOrganize});
  @override
  Widget build(BuildContext context) => Row(children: [if (!isRoot) _GlassButton(icon: CupertinoIcons.chevron_left, onTap: onBack) else const SizedBox(width: 42), const SizedBox(width: 9), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('File Manager', style: TextStyle(color: foreground.withOpacity(.5), fontSize: 12)), Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontSize: 28, fontWeight: FontWeight.w800))])), _GlassButton(icon: CupertinoIcons.folder_badge_plus, onTap: onFolder), const SizedBox(width: 6), _GlassButton(icon: CupertinoIcons.cloud_download, onTap: onImport), const SizedBox(width: 6), _GlassButton(icon: CupertinoIcons.sparkles, onTap: onOrganize)]);
}

class _GlassButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) { final dark = Theme.of(context).brightness == Brightness.dark; return ClipRRect(borderRadius: BorderRadius.circular(17), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Material(color: dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.72), child: InkWell(onTap: onTap, child: Padding(padding: const EdgeInsets.all(11), child: Icon(icon, size: 19, color: dark ? Colors.white : const Color(0xFF1A2A43))))))); }
}

class _GlassSearch extends StatelessWidget {
  final TextEditingController controller;
  final bool dark;
  const _GlassSearch({required this.controller, required this.dark});
  @override
  Widget build(BuildContext context) => ClipRRect(borderRadius: BorderRadius.circular(24), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22), child: Container(decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.08) : Colors.white.withOpacity(.75), borderRadius: BorderRadius.circular(24), border: Border.all(color: dark ? Colors.white.withOpacity(.12) : Colors.white)), child: TextField(controller: controller, decoration: InputDecoration(prefixIcon: Icon(CupertinoIcons.search, color: dark ? Colors.white60 : Colors.black45), hintText: 'Search files and folders', border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)))));
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionTitle(this.title, this.color);
  @override
  Widget build(BuildContext context) => Text(title, style: TextStyle(color: color, fontSize: 17, fontWeight: FontWeight.w800));
}

class _FolderTile extends StatelessWidget {
  final Map<String, dynamic> folder;
  final bool dark;
  final Color foreground;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _FolderTile({required this.folder, required this.dark, required this.foreground, required this.onOpen, required this.onRename, required this.onDelete});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 9), child: ClipRRect(borderRadius: BorderRadius.circular(22), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Material(color: dark ? Colors.white.withOpacity(.065) : Colors.white.withOpacity(.78), child: InkWell(onTap: onOpen, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF4B8DFF).withOpacity(.14), borderRadius: BorderRadius.circular(16)), child: const Icon(CupertinoIcons.folder_fill, color: Color(0xFF4B8DFF))), const SizedBox(width: 13), Expanded(child: Text(folder['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontWeight: FontWeight.w700))), CupertinoButton(padding: EdgeInsets.zero, onPressed: () => showCupertinoModalPopup(context: context, builder: (_) => CupertinoActionSheet(actions: [CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); onRename(); }, child: const Text('Rename folder')), CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () { Navigator.pop(context); onDelete(); }, child: const Text('Delete folder'))], cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')))), child: const Icon(CupertinoIcons.ellipsis_vertical, color: Color(0xFF4B8DFF)))]))))));
}

class _FileTile extends StatelessWidget {
  final Map<String, dynamic> file;
  final bool dark;
  final Color foreground;
  final VoidCallback onOpen;
  final VoidCallback onInfo;
  final VoidCallback onMove;
  final VoidCallback onRename;
  final VoidCallback onDelete;
  const _FileTile({required this.file, required this.dark, required this.foreground, required this.onOpen, required this.onInfo, required this.onMove, required this.onRename, required this.onDelete});
  @override
  Widget build(BuildContext context) { final ext = file['extension'].toString().toLowerCase(); final ai = file['ai_supported'] == true; return Padding(padding: const EdgeInsets.only(bottom: 9), child: ClipRRect(borderRadius: BorderRadius.circular(23), child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: Material(color: dark ? Colors.white.withOpacity(.055) : Colors.white.withOpacity(.78), child: InkWell(onTap: onOpen, child: Padding(padding: const EdgeInsets.all(13), child: Row(children: [Container(width: 50, height: 50, decoration: BoxDecoration(color: _color(ext).withOpacity(.13), borderRadius: BorderRadius.circular(16)), child: Icon(_icon(ext), color: _color(ext), size: 25)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(file['name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: foreground, fontWeight: FontWeight.w700, fontSize: 14.5)), const SizedBox(height: 5), Text('${ext.toUpperCase()} • ${_size(file['size_bytes'])}${ai ? ' • AI ready' : ''}', style: TextStyle(color: foreground.withOpacity(.5), fontSize: 11.5))])), CupertinoButton(padding: const EdgeInsets.all(6), onPressed: onInfo, child: const Icon(CupertinoIcons.info_circle, color: Color(0xFF4B8DFF), size: 21)), CupertinoButton(padding: EdgeInsets.zero, onPressed: () => showCupertinoModalPopup(context: context, builder: (_) => CupertinoActionSheet(actions: [CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); onOpen(); }, child: const Text('Open')), CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); onMove(); }, child: const Text('Move to folder')), CupertinoActionSheetAction(onPressed: () { Navigator.pop(context); onRename(); }, child: const Text('Rename')), CupertinoActionSheetAction(isDestructiveAction: true, onPressed: () { Navigator.pop(context); onDelete(); }, child: const Text('Delete'))], cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(context), child: const Text('Cancel')))), child: const Icon(CupertinoIcons.ellipsis_vertical, color: Color(0xFF4B8DFF)))])))))); }
  static IconData _icon(String ext) { if (ext == 'pdf') return CupertinoIcons.doc_text_fill; if ({'jpg','jpeg','png','gif','webp'}.contains(ext)) return CupertinoIcons.photo; if ({'mp3','wav'}.contains(ext)) return CupertinoIcons.music_note; if ({'mp4','mov'}.contains(ext)) return CupertinoIcons.film; if (ext == 'txt' || ext == 'md') return CupertinoIcons.doc_plaintext; return CupertinoIcons.doc; }
  static Color _color(String ext) { if (ext == 'pdf') return const Color(0xFFFF5D73); if ({'jpg','jpeg','png','gif','webp'}.contains(ext)) return const Color(0xFF9A7BFF); if ({'xls','xlsx','csv'}.contains(ext)) return const Color(0xFF27B67A); return const Color(0xFF4B8DFF); }
  static String _size(dynamic value) { final bytes = (value as num?)?.toDouble() ?? 0; if (bytes < 1024) return '${bytes.toInt()} B'; if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB'; return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB'; }
}

class _EmptyFiles extends StatelessWidget {
  final bool dark;
  final VoidCallback onImport;
  final VoidCallback onFolder;
  const _EmptyFiles({required this.dark, required this.onImport, required this.onFolder});
  @override
  Widget build(BuildContext context) => Container(margin: const EdgeInsets.only(top: 30), padding: const EdgeInsets.all(28), decoration: BoxDecoration(color: dark ? Colors.white.withOpacity(.06) : Colors.white.withOpacity(.72), borderRadius: BorderRadius.circular(30), border: Border.all(color: dark ? Colors.white12 : Colors.white)), child: Column(children: [Icon(CupertinoIcons.folder, size: 54, color: dark ? Colors.white38 : const Color(0xFF9AA9BD)), const SizedBox(height: 14), const Text('Your space is ready.', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 7), Text('Create folders or import from Files, Gallery, Drive, OneDrive and other apps.', textAlign: TextAlign.center, style: TextStyle(color: dark ? Colors.white60 : Colors.black54, height: 1.4)), const SizedBox(height: 18), Row(children: [Expanded(child: CupertinoButton.filled(onPressed: onImport, child: const Text('Import'))), const SizedBox(width: 10), Expanded(child: CupertinoButton(onPressed: onFolder, child: const Text('New folder')))])]));
}

class FilePreviewScreen extends StatelessWidget {
  final Map<String, dynamic> file;
  final Uint8List bytes;
  const FilePreviewScreen({super.key, required this.file, required this.bytes});
  @override
  Widget build(BuildContext context) { final dark = Theme.of(context).brightness == Brightness.dark; return Scaffold(backgroundColor: dark ? const Color(0xFF090D14) : const Color(0xFFF4F7FB), appBar: AppBar(title: Text(file['name'].toString()), leading: IconButton(icon: const Icon(CupertinoIcons.xmark), onPressed: () => Navigator.pop(context))), body: SafeArea(child: _body(context))); }
  Widget _body(BuildContext context) { final ext = file['extension'].toString().toLowerCase(); if (ext == 'pdf') return SfPdfViewer.memory(bytes); if ({'jpg','jpeg','png','gif','webp'}.contains(ext)) return Center(child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain))); if (ext == 'txt' || ext == 'md') return SingleChildScrollView(padding: const EdgeInsets.all(22), child: SelectableText(String.fromCharCodes(bytes), style: const TextStyle(fontSize: 15, height: 1.55))); return Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(CupertinoIcons.doc, size: 68, color: Color(0xFF4B8DFF)), const SizedBox(height: 18), Text(file['name'].toString(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)), const SizedBox(height: 8), const Text('The original file is stored unchanged. This format can be opened or shared from the file actions.', textAlign: TextAlign.center)]))); }
}
