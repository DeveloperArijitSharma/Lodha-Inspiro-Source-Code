import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'notebook_detail_screen.dart';
import 'notebook_models.dart';
import 'notebook_repository.dart';

const _accentBlue = Color(0xFF4B8DFF);
const _accentPurple = Color(0xFF9A7BFF);
const _ink = Color(0xFF172033);

class NotebooksListScreen extends StatefulWidget {
  const NotebooksListScreen({super.key});

  @override
  State<NotebooksListScreen> createState() => _NotebooksListScreenState();
}

class _NotebooksListScreenState extends State<NotebooksListScreen> {
  final _repo = NotebookRepository();
  List<Notebook> _notebooks = [];
  bool _loading = true;
  bool _creating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final notebooks = await _repo.fetchNotebooks();
      if (!mounted) return;
      setState(() {
        _notebooks = notebooks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e is StateError ? e.message : 'Could not load notebooks. Pull to retry.';
      });
    }
  }

  Future<void> _createNotebook() async {
    if (_creating) return;
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white.withOpacity(.96),
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: const Text('New notebook', style: TextStyle(fontWeight: FontWeight.w700, fontFamily: 'Google Sans Flex', color: _ink)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            hintText: 'e.g. Photosynthesis',
            filled: true,
            fillColor: const Color(0xFFF3F6FB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          ),
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _accentBlue, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    final cleanTitle = title?.trim() ?? '';
    if (cleanTitle.isEmpty || !mounted) return;
    HapticFeedback.mediumImpact();
    setState(() => _creating = true);
    try {
      final notebook = await _repo.createNotebook(cleanTitle);
      if (!mounted) return;
      setState(() {
        _notebooks.insert(0, notebook);
        _creating = false;
      });
      _openNotebook(notebook);
    } catch (e) {
      if (!mounted) return;
      setState(() => _creating = false);
      _toast(e is StateError ? e.message : 'Failed to create notebook.');
    }
  }

  void _openNotebook(Notebook notebook) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => NotebookDetailScreen(notebook: notebook))).then((_) => _load());
  }

  Future<void> _deleteNotebook(Notebook notebook) async {
    HapticFeedback.heavyImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Delete notebook?', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
        content: Text('This removes "${notebook.title}" and its sources, chats and notes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), style: FilledButton.styleFrom(backgroundColor: Colors.redAccent), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteNotebook(notebook.id);
      if (mounted) setState(() => _notebooks.removeWhere((n) => n.id == notebook.id));
    } catch (_) {
      _toast('Could not delete notebook.');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message, style: const TextStyle(fontFamily: 'Google Sans Flex')), behavior: SnackBarBehavior.floating, backgroundColor: _ink));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: Stack(
        children: [
          Positioned(top: -90, right: -70, child: _glow(230, const Color(0xFFB9D8FF))),
          Positioned(top: 170, left: -110, child: _glow(240, const Color(0xFFD8C8FF))),
          SafeArea(
            child: RefreshIndicator(
              color: _accentBlue,
              onRefresh: _load,
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _accentBlue))
                  : _error != null
                      ? _buildError()
                      : _notebooks.isEmpty
                          ? _buildEmpty()
                          : _buildList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glow(double size, Color color) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.28), boxShadow: [BoxShadow(color: color.withOpacity(.35), blurRadius: 70, spreadRadius: 20)]),
      );

  Widget _buildHeader({String subtitle = 'Your study space'}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 10),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: Colors.white.withOpacity(.72), borderRadius: BorderRadius.circular(18), border: Border.all(color: Colors.white, width: 1.2)),
                child: const Icon(Icons.auto_awesome_rounded, color: _accentBlue),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Notebooks', style: TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w800, fontFamily: 'Google Sans Flex')),
              Text(subtitle, style: const TextStyle(color: Color(0xFF718096), fontSize: 13, fontFamily: 'Google Sans Flex')),
            ]),
          ),
          IconButton(
            onPressed: _creating ? null : _createNotebook,
            style: IconButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      itemCount: _notebooks.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _buildHeader();
        final notebook = _notebooks[index - 1];
        return Dismissible(
          key: ValueKey(notebook.id),
          direction: DismissDirection.endToStart,
          confirmDismiss: (_) async {
            await _deleteNotebook(notebook);
            return false;
          },
          background: Container(alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 26), child: const Icon(Icons.delete_rounded, color: Colors.redAccent)),
          child: _buildNotebookCard(notebook),
        );
      },
    );
  }

  Widget _buildNotebookCard(Notebook notebook) {
    final hasSummary = notebook.summary?.trim().isNotEmpty == true;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.white.withOpacity(.76),
            child: InkWell(
              onTap: () => _openNotebook(notebook),
              borderRadius: BorderRadius.circular(28),
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(28), border: Border.all(color: Colors.white.withOpacity(.95), width: 1.3)),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFFDCEAFF), Color(0xFFEDE4FF)]),
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: const Icon(Icons.menu_book_rounded, color: Color(0xFF6176C8), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(notebook.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w750, fontFamily: 'Google Sans Flex')),
                        const SizedBox(height: 5),
                        Text(hasSummary ? notebook.summary! : 'Ready for notes, PDFs and questions.', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFF718096), fontSize: 13, height: 1.35, fontFamily: 'Google Sans Flex')),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withOpacity(.75), shape: BoxShape.circle), child: const Icon(Icons.arrow_forward_ios_rounded, color: _accentBlue, size: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(22, 16, 22, 60), children: [
      _buildHeader(subtitle: 'A calm place for every subject'),
      const SizedBox(height: 90),
      Center(child: Container(width: 128, height: 128, decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFFBBD9FF), Color(0xFFDCCBFF)]), boxShadow: [BoxShadow(color: _accentBlue.withOpacity(.22), blurRadius: 45)]), child: const Icon(Icons.auto_awesome_rounded, size: 54, color: Colors.white))),
      const SizedBox(height: 28),
      const Text('Nothing here yet', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: 24, fontWeight: FontWeight.w800, fontFamily: 'Google Sans Flex')),
      const SizedBox(height: 8),
      const Text('Create a notebook for a subject, add your material, then ask Inspiro AI questions grounded in it.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF718096), height: 1.45, fontFamily: 'Google Sans Flex')),
      const SizedBox(height: 26),
      FilledButton.icon(onPressed: _creating ? null : _createNotebook, style: FilledButton.styleFrom(backgroundColor: _ink, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), icon: const Icon(Icons.add_rounded), label: Text(_creating ? 'Creating...' : 'Create notebook')),
    ]);
  }

  Widget _buildError() {
    return ListView(physics: const AlwaysScrollableScrollPhysics(), padding: const EdgeInsets.fromLTRB(24, 100, 24, 40), children: [
      _buildHeader(subtitle: 'Something needs a refresh'),
      const SizedBox(height: 70),
      const Icon(Icons.cloud_off_rounded, size: 58, color: _accentBlue),
      const SizedBox(height: 18),
      const Text('Notebook service unavailable', textAlign: TextAlign.center, style: TextStyle(color: _ink, fontSize: 21, fontWeight: FontWeight.bold, fontFamily: 'Google Sans Flex')),
      const SizedBox(height: 8),
      Text(_error ?? 'Please try again.', textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF718096), fontFamily: 'Google Sans Flex')),
      const SizedBox(height: 20),
      FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'), style: FilledButton.styleFrom(backgroundColor: _ink, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)))),
    ]);
  }
}
